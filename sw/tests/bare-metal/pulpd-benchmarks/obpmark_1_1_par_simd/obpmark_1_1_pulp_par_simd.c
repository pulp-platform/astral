/*
 * Copyright 2024 ETH Zurich and University of Bologna.
 * Licensed under the Apache License, Version 2.0, see LICENSE for details.
 * SPDX-License-Identifier: Apache-2.0
 *
 * OBPMark Benchmark #1.1 - Image Calibration and Correction
 * Parallel port for the PULP integer cluster of Astral (8 cores, RV32)
 *
 * SPMD: every core runs the same code on a distinct column range [xs, xe).
 * Synchronisation uses the cluster hardware barrier (synch_barrier()).
 * Data buffers live in .heapsram (TCDM) to keep them out of the ELF payload.
 * Input: 32x32 pixels, 8 frames, synthetic data (LCG seed 21121993).
 * Expected Output[0][0] = 125700 (matches sequential CVA6/PULP results).
 */

#include "pulp.h"
#include <stdint.h>
#include <stdio.h>

/* PULP 16-bit SIMD vector types (2x uint16 / int16 packed in one 32-bit word).
 * Native operators (+, -) on these map to pv.add.h / pv.sub.h instructions
 * when compiled with -march=rv32imcxgap9. */
typedef unsigned short v2u __attribute__((vector_size(4)));
typedef   signed short v2s __attribute__((vector_size(4)));

#define IMG_W           32
#define IMG_H           32
#define NUM_FRAMES        8
#define NUM_NEIGHBOURS    4
#define TOTAL_FRAMES    (NUM_FRAMES + NUM_NEIGHBOURS)
#define OFFSET_NEIGHBOURS 2

#define EXPECTED_OUTPUT_0_0  125700u

typedef struct { uint16_t *f; unsigned int w; unsigned int h; } frame16_t;
typedef struct { uint8_t  *f; unsigned int w; unsigned int h; } frame8_t;
typedef struct { uint32_t *f; unsigned int w; unsigned int h; } frame32_t;

#define PIXEL(frame, x, y) ((frame)->f[(y) * (frame)->w + (x)])

#define HEAPSRAM __attribute__((section(".heapsram")))

static HEAPSRAM uint16_t _frames_data [TOTAL_FRAMES][IMG_H * IMG_W];
static HEAPSRAM uint16_t _offsets_data [IMG_H * IMG_W];
static HEAPSRAM uint16_t _gains_data   [IMG_H * IMG_W];
static HEAPSRAM uint8_t  _badpix_data  [IMG_H * IMG_W];
static HEAPSRAM uint32_t _output_data  [(IMG_H/2) * (IMG_W/2)];
static HEAPSRAM uint32_t _binned_data  [(IMG_H/2) * (IMG_W/2)];

static HEAPSRAM frame16_t frames[TOTAL_FRAMES];
static HEAPSRAM frame16_t offsets_frame;
static HEAPSRAM frame16_t gains_frame;
static HEAPSRAM frame8_t  bad_pixels_frame;
static HEAPSRAM frame32_t output_frame;
static HEAPSRAM frame32_t binned_frame;

static HEAPSRAM unsigned int num_cores;

static void init_frames(void) {
    unsigned int i;
    for (i = 0; i < TOTAL_FRAMES; i++) {
        frames[i].f = _frames_data[i];
        frames[i].w = IMG_W;
        frames[i].h = IMG_H;
    }
    offsets_frame.f    = _offsets_data; offsets_frame.w    = IMG_W;   offsets_frame.h    = IMG_H;
    gains_frame.f      = _gains_data;   gains_frame.w      = IMG_W;   gains_frame.h      = IMG_H;
    bad_pixels_frame.f = _badpix_data;  bad_pixels_frame.w = IMG_W;   bad_pixels_frame.h = IMG_H;
    output_frame.f     = _output_data;  output_frame.w     = IMG_W/2; output_frame.h     = IMG_H/2;
    binned_frame.f     = _binned_data;  binned_frame.w     = IMG_W/2; binned_frame.h     = IMG_H/2;
}

static unsigned int _rand_state;

static unsigned int bm_rand(void) {
    _rand_state = _rand_state * 1103515245u + 12345u;
    return (_rand_state >> 16u) & 0x7FFFu;
}

static void gen_rand_data(void) {
    unsigned int f, x, y;
    _rand_state = 21121993u;
    for (f = 0; f < TOTAL_FRAMES; f++)
        for (x = 0; x < IMG_W; x++)
            for (y = 0; y < IMG_H; y++)
                PIXEL(&frames[f], x, y) = (uint16_t)(bm_rand() % 65535u);
    for (x = 0; x < IMG_W; x++)
        for (y = 0; y < IMG_H; y++)
            PIXEL(&offsets_frame, x, y) = (uint16_t)(bm_rand() % 65535u);
    for (x = 0; x < IMG_W; x++)
        for (y = 0; y < IMG_H; y++)
            PIXEL(&gains_frame, x, y) = (uint16_t)(bm_rand() % 65535u);
    for (x = 0; x < IMG_W; x++)
        for (y = 0; y < IMG_H; y++)
            PIXEL(&bad_pixels_frame, x, y) = ((uint8_t)(bm_rand() % 65535u)) & 0x01u;
    for (x = 0; x < IMG_W/2; x++)
        for (y = 0; y < IMG_H/2; y++)
            PIXEL(&output_frame, x, y) = 0u;
}

/* Static column partitioning, same policy as OpenMP schedule(static). */
static inline void split_range(unsigned int total, unsigned int id,
                                unsigned int n, unsigned int *start,
                                unsigned int *end) {
    unsigned int chunk = total / n;
    *start = id * chunk;
    *end   = (id == n - 1u) ? total : (*start + chunk);
}

/* SIMD-vectorized offset correction: processes 2 pixels per iteration.
 * Each column x starts at byte offset y*w*2; the inner loop walks y, and for
 * a fixed y two adjacent x values are contiguous in memory. We instead keep
 * the column-partitioned layout (x outer) but pair up rows: for a fixed x,
 * consecutive y values are w*2 bytes apart (NOT contiguous), so we cannot
 * pack along y. We therefore pack along x: process columns in pairs.
 * Alignment: row start y*w*2 is 4-byte aligned; x even => &frame[y*w+x] is
 * 4-byte aligned. The per-core column range [xs,xe) always starts even
 * (xs = id * (32/8) = id*4) and has even width, so all accesses are aligned. */
static void f_offset_range(frame16_t *frame, frame16_t *offsets,
                            unsigned int xs, unsigned int xe) {
    unsigned int x, y;
    unsigned int w = frame->w;
    for (y = 0; y < frame->h; y++) {
        uint16_t *frow = &frame->f[y * w];
        uint16_t *orow = &offsets->f[y * w];
        for (x = xs; x + 1u < xe; x += 2u) {
            v2u fv = *(v2u *)&frow[x];
            v2u ov = *(v2u *)&orow[x];
            *(v2u *)&frow[x] = fv - ov;       /* pv.sub.h: 2 pixels at once */
        }
        if (x < xe)                            /* odd tail (not hit with 4-wide) */
            frow[x] -= orow[x];
    }
}

static uint32_t f_neighbour_masked_sum(frame16_t *frame, frame8_t *mask,
                                        int x_mid, int y_mid) {
    int x, y, x_start = -1, x_stop = 1, y_start = -1, y_stop = 1;
    unsigned int n_sum = 0;
    uint32_t sum = 0;
    if (x_mid == 0)                        x_start = 0;
    else if (x_mid == (int)(frame->w - 1)) x_stop  = 0;
    if (y_mid == 0)                        y_start = 0;
    else if (y_mid == (int)(frame->h - 1)) y_stop  = 0;
    for (x = x_start; x < (x_stop + 1); x++)
        for (y = y_start; y < (y_stop + 1); y++)
            if (PIXEL(mask, (x_mid+x), (y_mid+y)) == 0) {
                sum += PIXEL(frame, (x_mid+x), (y_mid+y));
                n_sum++;
            }
    return (n_sum == 0u) ? 0u : sum / n_sum;
}

static void f_mask_replace_range(frame16_t *frame, frame8_t *mask,
                                  unsigned int xs, unsigned int xe) {
    unsigned int x, y;
    for (x = xs; x < xe; x++)
        for (y = 0; y < frame->h; y++)
            if (PIXEL(mask, x, y) == 1u)
                PIXEL(frame, x, y) = (uint16_t)f_neighbour_masked_sum(
                    frame, mask, (int)x, (int)y);
}

static void f_scrub_range(frame16_t *frame, frame16_t *fs, unsigned int frame_i,
                           unsigned int xs, unsigned int xe) {
    unsigned int x, y;
    uint32_t sum, mean, thr;
    for (x = xs; x < xe; x++)
        for (y = 0; y < frame->h; y++) {
            sum  = PIXEL(&fs[frame_i-2], x, y) + PIXEL(&fs[frame_i-1], x, y)
                 + PIXEL(&fs[frame_i+1], x, y) + PIXEL(&fs[frame_i+2], x, y);
            mean = sum / 4u;
            thr  = 2u * mean;
            if (PIXEL(frame, x, y) > thr)
                PIXEL(frame, x, y) = (uint16_t)mean;
        }
}

static void f_gain_range(frame16_t *frame, frame16_t *gains,
                          unsigned int xs, unsigned int xe) {
    unsigned int x, y;
    for (x = xs; x < xe; x++)
        for (y = 0; y < frame->h; y++)
            PIXEL(frame, x, y) = (uint16_t)(
                ((uint32_t)PIXEL(frame, x, y) *
                 (uint32_t)PIXEL(gains, x, y)) >> 16);
}

/* SIMD-vectorized 2x2 binning.
 * The two pixels of a 2x2 block on the same row are contiguous: a single v2u
 * load fetches {p(x,y), p(x+1,y)}. Loading the two rows and adding them with
 * pv.add.h gives {p(x,y)+p(x,y+1), p(x+1,y)+p(x+1,y+1)} in one instruction;
 * a final scalar add of the two lanes yields the 4-pixel sum.
 * Alignment: x = x2*2 is always even, so &frame[y*w + x] is 4-byte aligned. */
static void f_2x2_bin_range(frame16_t *frame, frame32_t *binned,
                             unsigned int xs2, unsigned int xe2) {
    unsigned int x2, y2;
    unsigned int w = frame->w;
    for (x2 = xs2; x2 < xe2; x2++) {
        unsigned int x = x2 * 2u;
        for (y2 = 0; y2 < binned->h; y2++) {
            unsigned int y = y2 * 2u;
            v2u top = *(v2u *)&frame->f[y * w + x];       /* {p(x,y),   p(x+1,y)}   */
            v2u bot = *(v2u *)&frame->f[(y + 1u) * w + x];  /* {p(x,y+1), p(x+1,y+1)} */
            v2u s   = top + bot;                            /* pv.add.h: vertical sum */
            PIXEL(binned, x2, y2) = (uint32_t)s[0] + (uint32_t)s[1];
        }
    }
}

static void f_coadd_range(frame32_t *sum_frame, frame32_t *add_frame,
                           unsigned int xs2, unsigned int xe2) {
    unsigned int x, y;
    for (x = xs2; x < xe2; x++)
        for (y = 0; y < sum_frame->h; y++)
            PIXEL(sum_frame, x, y) += PIXEL(add_frame, x, y);
}

/* Read the core id from hardware inside each pipeline function rather than
 * trusting a passed-in parameter (same defensive approach as the CVA6 SMP
 * port, where LTO corrupted the argument for the secondary hart). */
static void prepare_image_frame_par(frame16_t *frame) {
    unsigned int id = (unsigned int)get_core_id();
    unsigned int xs, xe;
    split_range(IMG_W, id, num_cores, &xs, &xe);

    f_offset_range(frame, &offsets_frame, xs, xe);
    synch_barrier();
    f_mask_replace_range(frame, &bad_pixels_frame, xs, xe);
    synch_barrier();
}

static void proc_image_frame_par(frame16_t *frame, unsigned int frame_i) {
    unsigned int id = (unsigned int)get_core_id();
    unsigned int xs, xe, xs2, xe2;
    split_range(IMG_W,   id, num_cores, &xs,  &xe);
    split_range(IMG_W/2, id, num_cores, &xs2, &xe2);

    f_scrub_range(frame, frames, frame_i, xs, xe);
    synch_barrier();
    f_gain_range(frame, &gains_frame, xs, xe);
    synch_barrier();
    f_2x2_bin_range(frame, &binned_frame, xs2, xe2);
    synch_barrier();
    f_coadd_range(&output_frame, &binned_frame, xs2, xe2);
    synch_barrier();
}

void check_obpmark(testresult_t *result, void (*start)(), void (*stop)());

testcase_t testcases[] = {
    { .name = "obpmark_1_1_par_simd", .test = check_obpmark },
    {0, 0}
};

int main(void) {
    if (rt_cluster_id() != 0)
        return bench_cluster_forward(0);

    num_cores = get_core_num();

    if (rt_core_id() < num_cores)
        run_suite(testcases);

    synch_barrier();
    return 0;
}

void check_obpmark(testresult_t *result, void (*start)(), void (*stop)()) {
    unsigned int core_id = (unsigned int)get_core_id();

    if (core_id == 0) {
        init_frames();
        gen_rand_data();
        cpu_perf_conf_events(1 << CSR_PCER_CYCLES);
        cpu_perf_setall(0);
        cpu_perf_start(0);
    }
    synch_barrier();

    start();

    unsigned int frame_i;
    for (frame_i = OFFSET_NEIGHBOURS;
         frame_i < TOTAL_FRAMES - OFFSET_NEIGHBOURS;
         frame_i++) {
        prepare_image_frame_par(&frames[frame_i + 2u]);
        proc_image_frame_par(&frames[frame_i], frame_i);
    }

    synch_barrier();
    stop();

    if (core_id != 0) return;

    cpu_perf_stop();
    unsigned int cycles = cpu_perf_get(CSR_PCER_CYCLES);

    unsigned int pixels  = IMG_W * IMG_H * NUM_FRAMES;
    unsigned int time_us = (unsigned int)(((unsigned long long)cycles * 20ULL) / 1000ULL);
    unsigned int tp_int  = (unsigned int)(((unsigned long long)pixels * 50ULL) / cycles);
    unsigned int tp_frac = (unsigned int)((((unsigned long long)pixels * 50ULL) % cycles) * 100ULL / cycles);

    unsigned int out = (unsigned int)PIXEL(&output_frame, 0, 0);

    printf("OBPMark 1.1 - Image Calibration and Correction\n");
    printf("PULP cluster parallel + SIMD16 (%u cores, RV32) - Astral @ 50 MHz\n", num_cores);
    printf("Image: %dx%d px | Frames: %d\n", IMG_W, IMG_H, NUM_FRAMES);
    printf("  Elapsed cycles : %u\n", cycles);
    printf("  Elapsed time   : %u us\n", time_us);
    printf("  Throughput     : %u.%02u Mpixel/s\n", tp_int, tp_frac);
    printf("  Output[0][0]   : %u\n", out);

    if (out == EXPECTED_OUTPUT_0_0) {
        result->errors = 0;
        printf("RESULT: PASS\n");
    } else {
        result->errors = 1;
        printf("RESULT: FAIL (expected %u)\n", EXPECTED_OUTPUT_0_0);
    }
}
