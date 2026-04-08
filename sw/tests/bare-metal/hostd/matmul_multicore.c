// Copyright 2023 ETH Zurich and University of Bologna.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0
//
// Adapted by ChatGPT for type-generic matmul (i32/i64/f32/f64)

#include <stdint.h>

#include "car_memory_map.h"
#include "car_util.h"
#include "dif/clint.h"
#include "dif/uart.h"
#include "params.h"
#include "regs/cheshire.h"
#include "util.h"
#include "io.h"
#include "padframe.h"
#include "printf.h"
#include "fll.h"

// ------------------------------
// Available data types
// ------------------------------
#define I32 1
#define I64 2
#define F32 3
#define F64 4

#ifndef MATMUL_TYPE
#define MATMUL_TYPE I32
#endif

#if   (MATMUL_TYPE == I32)
  typedef int32_t dtype_t;
  #define DTYPE_NAME  "int32"
#elif (MATMUL_TYPE == I64)
  typedef int64_t dtype_t;
  #define DTYPE_NAME  "int64"
#elif (MATMUL_TYPE == F32)
  typedef float    dtype_t;
  #define DTYPE_NAME  "fp32"
#elif (MATMUL_TYPE == F64)
  typedef double   dtype_t;
  #define DTYPE_NAME  "fp64"
#else
  #error "Invalid type, use I32, I64, F32, F64."
#endif

#if (MATMUL_TYPE == F32)
  static inline float FMA(float a, float b, float c) {
    float d;
    __asm__ volatile ("fmadd.s %0, %1, %2, %3"
                      : "=f"(d) : "f"(a), "f"(b), "f"(c));
    return d;             // d  =     a   *   b   +   c
  }
#elif (MATMUL_TYPE == F64)
  static inline double FMA(double a, double b, double c) {
    double d;
    __asm__ volatile ("fmadd.d %0, %1, %2, %3"
                      : "=f"(d) : "f"(a), "f"(b), "f"(c));
    return d;
  }
#else
  // Integer case
  static inline dtype_t FMA(dtype_t a, dtype_t b, dtype_t c) { return (dtype_t)(c + a*b); }
#endif

#define NUM_HARTS 2 // Available harts

// Synch flags
#define L2SynchAddr 0x78000000
#define L2DoneCount (volatile int *)0x78000004

static inline void membar(void) {
  __asm__ volatile ("fence iorw, iorw" ::: "memory");
}

// ------------------------------
// PERF COUNTERS
// ------------------------------
#define McycleId   0
#define MinstretId 2

// Max matrix sizes
#define MAX_M 32
#define MAX_N 32
#define MAX_P 32

// User matrix sizes
#define M MAX_M
#define N MAX_N
#define P MAX_P

// Global buffer for A, B, C
static __attribute__((aligned(8))) uint8_t matrix_storage[
  (MAX_M * MAX_N + MAX_N * MAX_P + MAX_M * MAX_P) * sizeof(dtype_t)
];

// Generic matrix structure
typedef struct {
  uint32_t rows;
  uint32_t cols;
  dtype_t* data;
} Matrix;

// Quite self explicative...
static inline Matrix create_matrix(uint32_t rows, uint32_t cols, dtype_t* buffer) {
  Matrix mat;
  mat.rows = rows;
  mat.cols = cols;
  mat.data = buffer;
  return mat;
}

// Access matrix elements (load and store)
static inline dtype_t get(const Matrix* mat, uint32_t i, uint32_t j) {
  return mat->data[(size_t)i * mat->cols + j];
}
static inline void set(Matrix* mat, uint32_t i, uint32_t j, dtype_t value) {
  mat->data[(size_t)i * mat->cols + j] = value;
}

// Matrix initialization
static inline void fill_matrix_test(Matrix* mat, double base) {
  for (uint32_t i = 0; i < mat->rows; ++i) {
    for (uint32_t j = 0; j < mat->cols; ++j) {
      double v = base + (double)((size_t)i * mat->cols + j);
      set(mat, i, j, (dtype_t)v);
    }
  }
}

// Simple MatrixMul (C += A * B)
static inline void matmul(const Matrix* A, const Matrix* B, Matrix* C) {
  for (uint32_t i = 0; i < C->rows; ++i) {
    for (uint32_t j = 0; j < C->cols; ++j) {
      dtype_t sum = (dtype_t)0;
      for (uint32_t k = 0; k < A->cols; ++k) {
        sum = (dtype_t)(sum + (dtype_t)(get(A, i, k) * get(B, k, j)));
      }
      set(C, i, j, sum);
    }
  }
}

// FMA-based MatrixMul with loop unrolling
static inline void matmul_unrol(const Matrix* A, const Matrix* B, Matrix* C) {
  const uint32_t Msize = C->rows;
  const uint32_t Nsize = A->cols;   // = B->rows
  const uint32_t Psize = C->cols;

  const dtype_t * __restrict Ad = A->data;
  const dtype_t * __restrict Bd = B->data;
  dtype_t       * __restrict Cd = C->data;

  const uint32_t lda = A->cols;
  const uint32_t ldb = B->cols;
  const uint32_t ldc = C->cols;

  for (uint32_t i = 0; i < Msize; ++i) {
    const dtype_t* __restrict arow = Ad + (size_t)i * lda;

    uint32_t j = 0;
    for (; j + 3 < Psize; j += 4) {
      dtype_t c0 = (dtype_t)0, c1 = (dtype_t)0, c2 = (dtype_t)0, c3 = (dtype_t)0;

      uint32_t k = 0;
      for (; k + 3 < Nsize; k += 4) {
        const dtype_t a0 = arow[k+0];
        const dtype_t a1 = arow[k+1];
        const dtype_t a2 = arow[k+2];
        const dtype_t a3 = arow[k+3];

        const dtype_t* __restrict b0 = Bd + (size_t)(k+0) * ldb + j;
        const dtype_t* __restrict b1 = Bd + (size_t)(k+1) * ldb + j;
        const dtype_t* __restrict b2 = Bd + (size_t)(k+2) * ldb + j;
        const dtype_t* __restrict b3 = Bd + (size_t)(k+3) * ldb + j;

        // 4 accumulators × 4 contributions
        c0 = FMA(a0, b0[0], c0); c1 = FMA(a0, b0[1], c1); c2 = FMA(a0, b0[2], c2); c3 = FMA(a0, b0[3], c3);
        c0 = FMA(a1, b1[0], c0); c1 = FMA(a1, b1[1], c1); c2 = FMA(a1, b1[2], c2); c3 = FMA(a1, b1[3], c3);
        c0 = FMA(a2, b2[0], c0); c1 = FMA(a2, b2[1], c1); c2 = FMA(a2, b2[2], c2); c3 = FMA(a2, b2[3], c3);
        c0 = FMA(a3, b3[0], c0); c1 = FMA(a3, b3[1], c1); c2 = FMA(a3, b3[2], c2); c3 = FMA(a3, b3[3], c3);
      }

      // Leftover
      for (; k < Nsize; ++k) {
        const dtype_t a = arow[k];
        const dtype_t* __restrict b = Bd + (size_t)k * ldb + j;
        c0 = FMA(a, b[0], c0);
        c1 = FMA(a, b[1], c1);
        c2 = FMA(a, b[2], c2);
        c3 = FMA(a, b[3], c3);
      }

      dtype_t* __restrict crow = Cd + (size_t)i * ldc + j;
      crow[0] = c0; crow[1] = c1; crow[2] = c2; crow[3] = c3;
    }

    // Residual columns (<4)
    for (; j < Psize; ++j) {
      dtype_t sum = (dtype_t)0;
      uint32_t k = 0;

      for (; k + 3 < Nsize; k += 4) {
        const dtype_t a0 = arow[k+0];
        const dtype_t a1 = arow[k+1];
        const dtype_t a2 = arow[k+2];
        const dtype_t a3 = arow[k+3];

        sum = FMA(a0, Bd[(size_t)(k+0) * ldb + j], sum);
        sum = FMA(a1, Bd[(size_t)(k+1) * ldb + j], sum);
        sum = FMA(a2, Bd[(size_t)(k+2) * ldb + j], sum);
        sum = FMA(a3, Bd[(size_t)(k+3) * ldb + j], sum);
      }
      for (; k < Nsize; ++k) {
        sum = FMA(arow[k], Bd[(size_t)k * ldb + j], sum);
      }

      Cd[(size_t)i * ldc + j] = sum;
    }
  }
}

// FMA-based multicore MatrixMul with loop unrolling
static inline void matmul_range(const Matrix* A, const Matrix* B, Matrix* C,
                                uint32_t row_begin, uint32_t row_end) {
  const uint32_t Nsize = A->cols;   // = B->rows
  const uint32_t Psize = C->cols;

  const dtype_t * __restrict Ad = A->data;
  const dtype_t * __restrict Bd = B->data;
  dtype_t       * __restrict Cd = C->data;

  const uint32_t lda = A->cols;
  const uint32_t ldb = B->cols;
  const uint32_t ldc = C->cols;

  for (uint32_t i = row_begin; i < row_end; ++i) {
    const dtype_t* __restrict arow = Ad + (size_t)i * lda;

    uint32_t j = 0;
    for (; j + 3 < Psize; j += 4) {
      dtype_t c0 = (dtype_t)0, c1 = (dtype_t)0, c2 = (dtype_t)0, c3 = (dtype_t)0;

      uint32_t k = 0;
      for (; k + 3 < Nsize; k += 4) {
        const dtype_t a0 = arow[k+0];
        const dtype_t a1 = arow[k+1];
        const dtype_t a2 = arow[k+2];
        const dtype_t a3 = arow[k+3];

        const dtype_t* __restrict b0 = Bd + (size_t)(k+0) * ldb + j;
        const dtype_t* __restrict b1 = Bd + (size_t)(k+1) * ldb + j;
        const dtype_t* __restrict b2 = Bd + (size_t)(k+2) * ldb + j;
        const dtype_t* __restrict b3 = Bd + (size_t)(k+3) * ldb + j;

        c0 = FMA(a0, b0[0], c0); c1 = FMA(a0, b0[1], c1); c2 = FMA(a0, b0[2], c2); c3 = FMA(a0, b0[3], c3);
        c0 = FMA(a1, b1[0], c0); c1 = FMA(a1, b1[1], c1); c2 = FMA(a1, b1[2], c2); c3 = FMA(a1, b1[3], c3);
        c0 = FMA(a2, b2[0], c0); c1 = FMA(a2, b2[1], c1); c2 = FMA(a2, b2[2], c2); c3 = FMA(a2, b2[3], c3);
        c0 = FMA(a3, b3[0], c0); c1 = FMA(a3, b3[1], c1); c2 = FMA(a3, b3[2], c2); c3 = FMA(a3, b3[3], c3);
      }
      for (; k < Nsize; ++k) {
        const dtype_t a = arow[k];
        const dtype_t* __restrict b = Bd + (size_t)k * ldb + j;
        c0 = FMA(a, b[0], c0);
        c1 = FMA(a, b[1], c1);
        c2 = FMA(a, b[2], c2);
        c3 = FMA(a, b[3], c3);
      }

      dtype_t* __restrict crow = Cd + (size_t)i * ldc + j;
      crow[0] = c0; crow[1] = c1; crow[2] = c2; crow[3] = c3;
    }

    // Residual columns
    for (; j < Psize; ++j) {
      dtype_t sum = (dtype_t)0;
      uint32_t k = 0;
      for (; k + 3 < Nsize; k += 4) {
        const dtype_t a0 = arow[k+0];
        const dtype_t a1 = arow[k+1];
        const dtype_t a2 = arow[k+2];
        const dtype_t a3 = arow[k+3];

        sum = FMA(a0, Bd[(size_t)(k+0) * ldb + j], sum);
        sum = FMA(a1, Bd[(size_t)(k+1) * ldb + j], sum);
        sum = FMA(a2, Bd[(size_t)(k+2) * ldb + j], sum);
        sum = FMA(a3, Bd[(size_t)(k+3) * ldb + j], sum);
      }
      for (; k < Nsize; ++k) {
        sum = FMA(arow[k], Bd[(size_t)k * ldb + j], sum);
      }
      Cd[(size_t)i * ldc + j] = sum;
    }
  }
}

// ------------------------------
// Performance counter helpers
// ------------------------------
static inline void perf_counter_enable(uint32_t perf_counter_id) {
  // CSR 0x320 è mcounterinhibit
  uint32_t value;
  uint32_t mask = ~(0x1u << perf_counter_id);
  _Bool inhibit;
  __asm__ volatile ("csrr %0, 0x320": "=r" (value));
  inhibit = ((value & mask) != 0);
  if (inhibit) __asm__ volatile ("csrw 0x320, %0":: "r" (value & mask));
}

static inline uint32_t read_mcycle_low() {
  uint32_t value = 0;
  __asm__ volatile ("csrr %0, 0xB00": "=r" (value));
  return value;
}
static inline uint32_t read_mcycle_high() {
  uint32_t value = 0;
  __asm__ volatile ("csrr %0, 0xB80": "=r" (value));
  return value;
}
static inline uint32_t read_minstret_low() {
  uint32_t value = 0;
  __asm__ volatile ("csrr %0, 0xB02": "=r" (value));
  return value;
}
static inline uint32_t read_minstret_high() {
  uint32_t value = 0;
  __asm__ volatile ("csrr %0, 0xB82": "=r" (value));
  return value;
}

int main(void) {
  const uint32_t hid = hart_id();

  dtype_t* ptr = (dtype_t*)matrix_storage;

  Matrix A = create_matrix(M, N, ptr);
  ptr += (size_t)M * N;

  Matrix B = create_matrix(N, P, ptr);
  ptr += (size_t)N * P;

  Matrix C = create_matrix(M, P, ptr);
  ptr += (size_t)M * P;

  const uint32_t rows_per = (M + NUM_HARTS - 1) / NUM_HARTS;
  const uint32_t row_begin = hid * rows_per;
  const uint32_t row_end   = (row_begin + rows_per > M) ? M : (row_begin + rows_per);

  uint32_t start = 0;
  uint32_t stop  = 0;

  if (hid == 0) {
    // Init shared data
    fill_matrix_test(&A, 1.0);
    fill_matrix_test(&B, 100.0);
    perf_counter_enable(McycleId);
    *(volatile uint32_t *)L2SynchAddr = 1;
    fencei();
    smp_resume();
  }

  while (*(volatile uint32_t *)L2SynchAddr == 0) { /* spin */ }
  fencei();

  int iter = 0;
  do {
    if (hid == 0) {
      *(volatile uint32_t *)L2DoneCount = 0;
      start = read_mcycle_low();
    }
    matmul_range(&A, &B, &C, row_begin, row_end);

    fencei();
    __sync_fetch_and_add(L2DoneCount, 1); // Communicate completion

    // Wait for other cores to complete
    while ((*(volatile uint32_t *)L2DoneCount) < NUM_HARTS) { /* spin */ }
    if (hid == 0) {
      stop = read_mcycle_low();
      iter++;
    }
  } while (iter < 2);

  if (hid == 0) {
    return stop - start;
  } else wfi();

}
