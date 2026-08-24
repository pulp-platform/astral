// Copyright 2024 ETH Zurich and University of Bologna.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0
//
// OBPMark Benchmark #1.1 - Image Calibration and Correction
// Bare-metal SMP port for Astral/Carfield host domain (2x CVA6, RV64)
//
// Porting notes vs versione OpenMP originale (processing.c con #pragma omp):
//   - OpenMP non disponibile bare-metal (libgomp richiede pthread/OS)
//   - "#pragma omp parallel for" su asse x -> split manuale per hart_id()
//   - Sincronizzazione thread OpenMP (join implicito) -> barrier() custom
//   - Risveglio hart1: smp_resume() (libreria Cheshire, sw/lib/smp.c)
//     IMPORTANTE: smp_resume() fa RIPARTIRE hart1 dall'inizio di main(),
//     non lo "sveglia" semplicemente -> hart1 deve saltare l'init (if hart_id()==0)
//
// Memoria: identica alla versione sequenziale (stessi buffer statici, IMG_W=IMG_H=128)

#include "regs/cheshire.h"
#include "dif/clint.h"
#include "dif/uart.h"
#include "params.h"
#include "util.h"
#include "car_util.h"
#include "smp.h"
#include "printf.h"
#include <stdint.h>

// ============================================================
// Configurazione benchmark
// ============================================================
#define IMG_W           128
#define IMG_H           128
#define NUM_FRAMES        8
#define NUM_NEIGHBOURS    4
#define TOTAL_FRAMES    (NUM_FRAMES + NUM_NEIGHBOURS)
#define OFFSET_NEIGHBOURS 2

#define NUM_HARTS         2     // 2x CVA6 nel domain host (CheshireNumInternalHarts)

#define CVA6_CLK_PERIOD_NS  20ULL
#define CVA6_FREQ_HZ        50000000ULL

// ============================================================
// Strutture dati (identiche a obpmark_image.h originale)
// ============================================================
typedef struct { uint16_t *f; unsigned int w; unsigned int h; } frame16_t;
typedef struct { uint8_t  *f; unsigned int w; unsigned int h; } frame8_t;
typedef struct { uint32_t *f; unsigned int w; unsigned int h; } frame32_t;

#define PIXEL(frame, x, y) ((frame)->f[(y) * (frame)->w + (x)])

// ============================================================
// Backing storage statico (condiviso tra i 2 hart, cache-coherent)
// ============================================================
static uint16_t _frames_data [TOTAL_FRAMES][IMG_H * IMG_W];
static uint16_t _offsets_data [IMG_H * IMG_W];
static uint16_t _gains_data   [IMG_H * IMG_W];
static uint8_t  _badpix_data  [IMG_H * IMG_W];
static uint32_t _output_data  [(IMG_H/2) * (IMG_W/2)];
static uint32_t _binned_data  [(IMG_H/2) * (IMG_W/2)];

static frame16_t frames[TOTAL_FRAMES];
static frame16_t offsets_frame;
static frame16_t gains_frame;
static frame8_t  bad_pixels_frame;
static frame32_t output_frame;
static frame32_t binned_frame;

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

// ============================================================
// Generazione dati sintetici (identica alla versione sequenziale)
// Eseguita SOLO da hart 0, prima del fork (smp_resume)
// ============================================================
static unsigned int _rand_state;

static unsigned int bm_rand(void) {
    _rand_state = _rand_state * 1103515245u + 12345u;
    return (_rand_state >> 16u) & 0x7FFFu;
}

static void gen_rand_data(void) {
    unsigned int f, x, y;
    const unsigned int randmax = 65535u;
    _rand_state = 21121993u;

    for (f = 0; f < TOTAL_FRAMES; f++)
        for (x = 0; x < IMG_W; x++)
            for (y = 0; y < IMG_H; y++)
                PIXEL(&frames[f], x, y) = (uint16_t)(bm_rand() % randmax);

    for (x = 0; x < IMG_W; x++)
        for (y = 0; y < IMG_H; y++)
            PIXEL(&offsets_frame, x, y) = (uint16_t)(bm_rand() % randmax);

    for (x = 0; x < IMG_W; x++)
        for (y = 0; y < IMG_H; y++)
            PIXEL(&gains_frame, x, y) = (uint16_t)(bm_rand() % randmax);

    for (x = 0; x < IMG_W; x++)
        for (y = 0; y < IMG_H; y++)
            PIXEL(&bad_pixels_frame, x, y) = ((uint8_t)(bm_rand() % randmax)) & 0x01u;

    for (x = 0; x < IMG_W/2; x++)
        for (y = 0; y < IMG_H/2; y++)
            PIXEL(&output_frame, x, y) = 0u;
}

// ============================================================
// Sincronizzazione SPMD: barriera a 2 hart con contatore atomico
// (stesso meccanismo amoswap visto in smp_hello.c, logica diversa:
//  barriera invece di mutex)
// ============================================================
static volatile uint32_t barrier_count = 0;
static volatile uint32_t barrier_sense = 0;

static inline uint32_t atomic_add_w(volatile uint32_t *addr, uint32_t val) {
    uint32_t old;
    asm volatile ("amoadd.w.aqrl %0, %2, (%1)"
                  : "=r"(old) : "r"(addr), "r"(val) : "memory");
    return old;
}

// Barriera sense-reversing: funziona per chiamate ripetute senza race
// tra un hart che corre via velocemente e l'altro che arriva in ritardo
static void barrier(void) {
    uint32_t local_sense = barrier_sense;
    uint32_t arrived = atomic_add_w(&barrier_count, 1) + 1u;
    if (arrived == NUM_HARTS) {
        barrier_count = 0;
        asm volatile ("fence" ::: "memory");
        barrier_sense = !local_sense;   // rilascia tutti gli hart in attesa
    } else {
        while (barrier_sense == local_sense) { /* spin */ }
    }
}

// ============================================================
// Divisione del lavoro tra hart (equivalente a #pragma omp parallel for)
// ============================================================
static inline void split_range(unsigned int total, unsigned int id,
                                unsigned int n, unsigned int *start,
                                unsigned int *end) {
    unsigned int chunk = total / n;
    *start = id * chunk;
    *end   = (id == n - 1u) ? total : (*start + chunk);
}

// ============================================================
// KERNEL FUNCTIONS  stesso algoritmo, ma operano su [x_start, x_end)
// invece che su tutta la larghezza (equivalente alla divisione che
// faceva "#pragma omp parallel for" sull'asse x)
// ============================================================

// [I] Bias offset correction
static void f_offset_range(frame16_t *frame, frame16_t *offsets,
                            unsigned int xs, unsigned int xe) {
    unsigned int x, y;
    for (x = xs; x < xe; x++)
        for (y = 0; y < frame->h; y++)
            PIXEL(frame, x, y) -= PIXEL(offsets, x, y);
}

static uint32_t f_neighbour_masked_sum(frame16_t *frame, frame8_t *mask,
                                        int x_mid, int y_mid) {
    int x, y;
    int x_start = -1, x_stop = 1, y_start = -1, y_stop = 1;
    unsigned int n_sum = 0;
    uint32_t sum = 0, mean;

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

    mean = (n_sum == 0u) ? 0u : sum / n_sum;
    return mean;
}

// [II] Bad pixel correction
// NOTA: legge pixel vicini (3x3) -> serve barrier() DOPO f_offset_range
// completo (entrambi gli hart) prima di chiamare questa, altrimenti un
// hart potrebbe leggere un pixel di confine non ancora corretto dall'altro.
static void f_mask_replace_range(frame16_t *frame, frame8_t *mask,
                                  unsigned int xs, unsigned int xe) {
    unsigned int x, y;
    for (x = xs; x < xe; x++)
        for (y = 0; y < frame->h; y++)
            if (PIXEL(mask, x, y) == 1u)
                PIXEL(frame, x, y) = (uint16_t)f_neighbour_masked_sum(
                    frame, mask, (int)x, (int)y);
}

// [III] Radiation scrubbing
static void f_scrub_range(frame16_t *frame, frame16_t *fs, unsigned int frame_i,
                           unsigned int xs, unsigned int xe) {
    unsigned int x, y;
    static unsigned int num_neighbour = 4u;
    uint32_t sum, mean, thr;

    for (x = xs; x < xe; x++)
        for (y = 0; y < frame->h; y++) {
            sum  = PIXEL(&fs[frame_i-2], x, y) + PIXEL(&fs[frame_i-1], x, y)
                 + PIXEL(&fs[frame_i+1], x, y) + PIXEL(&fs[frame_i+2], x, y);
            mean = sum / num_neighbour;
            thr  = 2u * mean;
            if (PIXEL(frame, x, y) > thr)
                PIXEL(frame, x, y) = (uint16_t)mean;
        }
}

// [IV] Gain correction
static void f_gain_range(frame16_t *frame, frame16_t *gains,
                          unsigned int xs, unsigned int xe) {
    unsigned int x, y;
    for (x = xs; x < xe; x++)
        for (y = 0; y < frame->h; y++)
            PIXEL(frame, x, y) = (uint16_t)(
                ((uint32_t)PIXEL(frame, x, y) *
                 (uint32_t)PIXEL(gains, x, y)) >> 16);
}

// [V] 2x2 Spatial binning (opera su indici half-resolution x2 in [xs,xe))
static void f_2x2_bin_range(frame16_t *frame, frame32_t *binned,
                             unsigned int xs2, unsigned int xe2) {
    unsigned int x2, y2;
    for (x2 = xs2; x2 < xe2; x2++) {
        unsigned int x = x2 * 2u;
        for (y2 = 0; y2 < binned->h; y2++) {
            unsigned int y = y2 * 2u;
            PIXEL(binned, x2, y2) = PIXEL(frame,  x,     y    )
                                  + PIXEL(frame, (x+1u), y    )
                                  + PIXEL(frame,  x,    (y+1u))
                                  + PIXEL(frame, (x+1u),(y+1u));
        }
    }
}

// [VI] Frame co-adding (half-resolution, split per indici x2)
static void f_coadd_range(frame32_t *sum_frame, frame32_t *add_frame,
                           unsigned int xs2, unsigned int xe2) {
    unsigned int x, y;
    for (x = xs2; x < xe2; x++)
        for (y = 0; y < sum_frame->h; y++)
            PIXEL(sum_frame, x, y) += PIXEL(add_frame, x, y);
}

// ============================================================
// Pipeline SPMD: ogni hart calcola il proprio range, esegue il kernel
// sulla sua porzione, poi barrier() prima del kernel successivo
// ============================================================
static void prepare_image_frame_smp(frame16_t *frame, unsigned int hid) {
    unsigned int xs, xe, xs2, xe2;
    split_range(IMG_W, hid, NUM_HARTS, &xs, &xe);
    split_range(IMG_W/2, hid, NUM_HARTS, &xs2, &xe2);
    (void)xs2; (void)xe2;

    f_offset_range(frame, &offsets_frame, xs, xe);        // [I]
    barrier();
    f_mask_replace_range(frame, &bad_pixels_frame, xs, xe); // [II]
    barrier();
}

static void proc_image_frame_smp(frame16_t *frame, unsigned int frame_i,
                                  unsigned int hid) {
    unsigned int xs, xe, xs2, xe2;
    split_range(IMG_W, hid, NUM_HARTS, &xs, &xe);
    split_range(IMG_W/2, hid, NUM_HARTS, &xs2, &xe2);

    f_scrub_range(frame, frames, frame_i, xs, xe);         // [III]
    barrier();
    f_gain_range(frame, &gains_frame, xs, xe);             // [IV]
    barrier();
    f_2x2_bin_range(frame, &binned_frame, xs2, xe2);       // [V]
    barrier();
    f_coadd_range(&output_frame, &binned_frame, xs2, xe2); // [VI]
    barrier();
}

// ============================================================
// Cycle counter RISC-V
// ============================================================
static inline uint64_t read_mcycle(void) {
    uint64_t cycles;
    asm volatile ("csrr %0, mcycle" : "=r"(cycles));
    return cycles;
}

static void print_results(uint64_t cycles) {
    uint64_t time_ns      = cycles * CVA6_CLK_PERIOD_NS;
    uint64_t time_us      = time_ns / 1000ULL;
    uint64_t time_ms_int  = time_us / 1000ULL;
    uint64_t time_ms_frac = time_us % 1000ULL;

    uint64_t pixels = (uint64_t)IMG_W * (uint64_t)IMG_H * (uint64_t)NUM_FRAMES;
    uint64_t tp_int  = (pixels * 50ULL) / cycles;
    uint64_t tp_frac = ((pixels * 50ULL) % cycles) * 100ULL / cycles;

    printf("Benchmark metrics (2x CVA6 SMP):\r\n");
    printf("  Elapsed cycles : %llu\r\n",          (unsigned long long)cycles);
    printf("  Elapsed time   : %llu.%03llu ms\r\n",(unsigned long long)time_ms_int,
                                                    (unsigned long long)time_ms_frac);
    printf("  Throughput     : %llu.%02llu Mpixel/s\r\n",
           (unsigned long long)tp_int, (unsigned long long)tp_frac);
}

// ============================================================
// Main  SPMD: hart 0 inizializza e fa il fork, poi entrambi lavorano
// ============================================================
int main(void) {
    unsigned int hid = (unsigned int)hart_id();

    if (hid == 0) {
        car_init_start();

        printf("OBPMark #1.1 - Image Calibration and Correction\r\n");
        printf("Bare-metal SMP - Astral 2x CVA6 RV64 @ 50 MHz\r\n");
        printf("Image: %dx%d px | Frames: %d | Harts: %d\r\n",
               IMG_W, IMG_H, NUM_FRAMES, NUM_HARTS);

        init_frames();
        gen_rand_data();

        smp_resume();   // hart 1 RIPARTE da qui, entra in main() in parallelo
    }

    // -------------------------------------------------------
    // Da qui in poi: ENTRAMBI gli hart eseguono questo codice.
    // hart 1 (hid != 0) salta l'if sopra e arriva qui direttamente,
    // senza rifare init (che ha già fatto hart 0).
    // -------------------------------------------------------
    barrier();  // assicura che hart1 sia arrivato prima di iniziare il timer

    uint64_t t_start = (hid == 0) ? read_mcycle() : 0;

    unsigned int frame_i;
    for (frame_i = OFFSET_NEIGHBOURS;
         frame_i < TOTAL_FRAMES - OFFSET_NEIGHBOURS;
         frame_i++) {
        prepare_image_frame_smp(&frames[frame_i + 2u], hid);
        proc_image_frame_smp(&frames[frame_i], frame_i, hid);
    }

    barrier();  // assicura che entrambi gli hart abbiano finito

    if (hid == 0) {
        uint64_t t_end = read_mcycle();
        printf("Done.\r\n");
        print_results(t_end - t_start);
        printf("Output[0][0]: %u\r\n", (unsigned int)PIXEL(&output_frame, 0, 0));
    }

    return 0;
}
