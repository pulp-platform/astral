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

/* Per-kernel cycle accumulators (only core 0 writes them). Each kernel is
 * timed across all 8 frame iterations; the barrier before each measurement
 * ensures all cores have finished the previous stage, so the delta reflects
 * the true wall-clock cost of that stage (the slowest core sets the pace). */
static HEAPSRAM unsigned int cyc_offset;
static HEAPSRAM unsigned int cyc_mask;
static HEAPSRAM unsigned int cyc_scrub;
static HEAPSRAM unsigned int cyc_gain;
static HEAPSRAM unsigned int cyc_bin;
static HEAPSRAM unsigned int cyc_coadd;

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
            *(v2u *)&frow[x] = fv - ov;       /* pv.sub.h */
        }
        if (x < xe)
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

/* v3 (solution D): fully SIMD 4-frame mean using add2div2.
 * add2div2(x,y) computes (x+y)/2 per 16-bit lane WITHOUT intermediate
 * overflow (the hardware sums at full precision then halves). Chaining:
 *   mean = ((fm2+fm1)/2 + (fp1+fp2)/2) / 2 = (fm2+fm1+fp1+fp2)/4
 * Both pixels of the pair are computed in parallel. NOTE: the two intermediate
 * /2 truncate, so this mean can differ by a small rounding amount from the
 * exact sum/4 used by the scalar reference. Whether Output[0][0] stays 125700
 * must be verified empirically. The threshold compare stays per-lane scalar. */
static void f_scrub_range(frame16_t *frame, frame16_t *fs, unsigned int frame_i,
                           unsigned int xs, unsigned int xe) {
    unsigned int x, y;
    unsigned int w = frame->w;
    uint16_t *fm2 = fs[frame_i - 2u].f;
    uint16_t *fm1 = fs[frame_i - 1u].f;
    uint16_t *fp1 = fs[frame_i + 1u].f;
    uint16_t *fp2 = fs[frame_i + 2u].f;
    uint16_t *fcur = frame->f;

    for (y = 0; y < frame->h; y++) {
        unsigned int row = y * w;
        for (x = xs; x + 1u < xe; x += 2u) {
            unsigned int i = row + x;
            v2u a = *(v2u *)&fm2[i];
            v2u b = *(v2u *)&fm1[i];
            v2u c = *(v2u *)&fp1[i];
            v2u d = *(v2u *)&fp2[i];
            /* fully SIMD mean of the 4 frames, no overflow, both pixels at once */
            v2u ab   = __builtin_pulp_add2div2(a, b);   /* (a+b)/2 */
            v2u cd   = __builtin_pulp_add2div2(c, d);   /* (c+d)/2 */
            v2u mean = __builtin_pulp_add2div2(ab, cd); /* /2 again -> /4 total */
            v2u thr  = mean + mean;                     /* 2*mean, per lane (pv.add.h) */
            if (fcur[i]      > (unsigned int)thr[0]) fcur[i]      = mean[0];
            if (fcur[i + 1u] > (unsigned int)thr[1]) fcur[i + 1u] = mean[1];
        }
        if (x < xe) {
            unsigned int i = row + x;
            uint32_t sum = (uint32_t)fm2[i] + fm1[i] + fp1[i] + fp2[i];
            uint32_t mean = sum >> 2;
            if (fcur[i] > (mean << 1)) fcur[i] = (uint16_t)mean;
        }
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

static void f_2x2_bin_range(frame16_t *frame, frame32_t *binned,
                             unsigned int xs2, unsigned int xe2) {
    unsigned int x2, y2;
    unsigned int w = frame->w;
    for (x2 = xs2; x2 < xe2; x2++) {
        unsigned int x = x2 * 2u;
        for (y2 = 0; y2 < binned->h; y2++) {
            unsigned int y = y2 * 2u;
            v2u top = *(v2u *)&frame->f[y * w + x];
            v2u bot = *(v2u *)&frame->f[(y + 1u) * w + x];
            v2u s   = top + bot;                          /* pv.add.h */
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
/* Timing helper: only core 0 reads the counter. A barrier before reading
 * aligns all cores so the measured delta is the stage's full cost. */
static inline void bar_and_mark(unsigned int *acc, unsigned int *last) {
    synch_barrier();
    if (get_core_id() == 0) {
        unsigned int now = cpu_perf_get(CSR_PCER_CYCLES);
        *acc += now - *last;
        *last = now;
    }
}

static void prepare_image_frame_par(frame16_t *frame) {
    unsigned int id = (unsigned int)get_core_id();
    unsigned int xs, xe;
    split_range(IMG_W, id, num_cores, &xs, &xe);

    unsigned int last = 0;
    if (id == 0) last = cpu_perf_get(CSR_PCER_CYCLES);

    f_offset_range(frame, &offsets_frame, xs, xe);
    bar_and_mark(&cyc_offset, &last);
    f_mask_replace_range(frame, &bad_pixels_frame, xs, xe);
    bar_and_mark(&cyc_mask, &last);
}

static void proc_image_frame_par(frame16_t *frame, unsigned int frame_i) {
    unsigned int id = (unsigned int)get_core_id();
    unsigned int xs, xe, xs2, xe2;
    split_range(IMG_W,   id, num_cores, &xs,  &xe);
    split_range(IMG_W/2, id, num_cores, &xs2, &xe2);

    unsigned int last = 0;
    if (id == 0) last = cpu_perf_get(CSR_PCER_CYCLES);

    f_scrub_range(frame, frames, frame_i, xs, xe);
    bar_and_mark(&cyc_scrub, &last);
    f_gain_range(frame, &gains_frame, xs, xe);
    bar_and_mark(&cyc_gain, &last);
    f_2x2_bin_range(frame, &binned_frame, xs2, xe2);
    bar_and_mark(&cyc_bin, &last);
    f_coadd_range(&output_frame, &binned_frame, xs2, xe2);
    bar_and_mark(&cyc_coadd, &last);
}

void check_obpmark(testresult_t *result, void (*start)(), void (*stop)());

testcase_t testcases[] = {
    { .name = "obpmark_1_1_par_simd_v3_prof", .test = check_obpmark },
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
        cyc_offset = cyc_mask = cyc_scrub = 0;
        cyc_gain = cyc_bin = cyc_coadd = 0;
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
    printf("PULP cluster parallel + SIMD16 v3 (add2div2) + PROFILING (%u cores, RV32) - Astral @ 50 MHz\n", num_cores);
    printf("Image: %dx%d px | Frames: %d\n", IMG_W, IMG_H, NUM_FRAMES);
    printf("  Elapsed cycles : %u\n", cycles);
    printf("  Elapsed time   : %u us\n", time_us);
    printf("  Throughput     : %u.%02u Mpixel/s\n", tp_int, tp_frac);
    printf("  Output[0][0]   : %u\n", out);

    unsigned int kernel_tot = cyc_offset + cyc_mask + cyc_scrub
                            + cyc_gain + cyc_bin + cyc_coadd;
    printf("Per-kernel cycles (sum over 8 frames):\n");
    printf("  f_offset       : %8u  (%2u%%)\n", cyc_offset, kernel_tot ? cyc_offset*100u/kernel_tot : 0u);
    printf("  f_mask_replace : %8u  (%2u%%)\n", cyc_mask,   kernel_tot ? cyc_mask*100u/kernel_tot   : 0u);
    printf("  f_scrub        : %8u  (%2u%%)\n", cyc_scrub,  kernel_tot ? cyc_scrub*100u/kernel_tot  : 0u);
    printf("  f_gain         : %8u  (%2u%%)\n", cyc_gain,   kernel_tot ? cyc_gain*100u/kernel_tot   : 0u);
    printf("  f_2x2_bin      : %8u  (%2u%%)\n", cyc_bin,    kernel_tot ? cyc_bin*100u/kernel_tot    : 0u);
    printf("  f_coadd        : %8u  (%2u%%)\n", cyc_coadd,  kernel_tot ? cyc_coadd*100u/kernel_tot  : 0u);
    printf("  kernels total  : %8u  (barriers/overhead: %u)\n",
           kernel_tot, cycles > kernel_tot ? cycles - kernel_tot : 0u);

    if (out == EXPECTED_OUTPUT_0_0) {
        result->errors = 0;
        printf("RESULT: PASS\n");
    } else {
        result->errors = 1;
        printf("RESULT: FAIL (expected %u)\n", EXPECTED_OUTPUT_0_0);
    }
}
