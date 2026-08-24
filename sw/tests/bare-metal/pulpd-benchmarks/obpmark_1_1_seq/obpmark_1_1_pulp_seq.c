/*
 * Copyright 2024 ETH Zurich and University of Bologna.
 * Licensed under the Apache License, Version 2.0, see LICENSE for details.
 * SPDX-License-Identifier: Apache-2.0
 *
 * OBPMark Benchmark #1.1 - Image Calibration and Correction
 * Sequential port for the PULP integer cluster of Astral (1 core, RV32)
 *
 * Only core 0 runs the benchmark; all other cores return immediately.
 * Pattern follows parMatrixMul8 from pulp_cluster regression tests.
 * Data buffers use .heapsram section (same as parMatrixMul8 g_mA/g_mB/g_mC)
 * which places them in TCDM without generating PT_LOAD payload  avoiding
 * the large TCDM write sequence that breaks the cluster boot mechanism.
 * Input: 32x32 pixels, 8 frames, synthetic data (LCG seed 21121993).
 * Expected Output[0][0] = 125700 (matches sequential CVA6 host result).
 */

#include "pulp.h"
#include <stdint.h>
#include <stdio.h>

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

/* Place data buffers in .heapsram (TCDM)  same pattern as parMatrixMul8.
 * This keeps them out of the ELF PT_LOAD payload, avoiding the large TCDM
 * write sequence in load_binary() that breaks the cluster boot mechanism. */
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

static void f_offset(frame16_t *frame, frame16_t *offsets) {
    unsigned int x, y;
    for (x = 0; x < frame->w; x++)
        for (y = 0; y < frame->h; y++)
            PIXEL(frame, x, y) -= PIXEL(offsets, x, y);
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

static void f_mask_replace(frame16_t *frame, frame8_t *mask) {
    unsigned int x, y;
    for (x = 0; x < frame->w; x++)
        for (y = 0; y < frame->h; y++)
            if (PIXEL(mask, x, y) == 1u)
                PIXEL(frame, x, y) = (uint16_t)f_neighbour_masked_sum(
                    frame, mask, (int)x, (int)y);
}

static void f_scrub(frame16_t *frame, frame16_t *fs, unsigned int frame_i) {
    unsigned int x, y;
    uint32_t sum, mean, thr;
    for (x = 0; x < frame->w; x++)
        for (y = 0; y < frame->h; y++) {
            sum  = PIXEL(&fs[frame_i-2], x, y) + PIXEL(&fs[frame_i-1], x, y)
                 + PIXEL(&fs[frame_i+1], x, y) + PIXEL(&fs[frame_i+2], x, y);
            mean = sum / 4u;
            thr  = 2u * mean;
            if (PIXEL(frame, x, y) > thr)
                PIXEL(frame, x, y) = (uint16_t)mean;
        }
}

static void f_gain(frame16_t *frame, frame16_t *gains) {
    unsigned int x, y;
    for (x = 0; x < frame->w; x++)
        for (y = 0; y < frame->h; y++)
            PIXEL(frame, x, y) = (uint16_t)(
                ((uint32_t)PIXEL(frame, x, y) *
                 (uint32_t)PIXEL(gains, x, y)) >> 16);
}

static void f_2x2_bin(frame16_t *frame, frame32_t *binned) {
    unsigned int x, y;
    for (x = 0; x < frame->w; x += 2)
        for (y = 0; y < frame->h; y += 2)
            PIXEL(binned, x/2, y/2) = PIXEL(frame,  x,   y  )
                                     + PIXEL(frame, x+1,  y  )
                                     + PIXEL(frame,  x,  y+1 )
                                     + PIXEL(frame, x+1, y+1 );
}

static void f_coadd(frame32_t *sum_frame, frame32_t *add_frame) {
    unsigned int x, y;
    for (x = 0; x < sum_frame->w; x++)
        for (y = 0; y < sum_frame->h; y++)
            PIXEL(sum_frame, x, y) += PIXEL(add_frame, x, y);
}

static void prepare_image_frame(frame16_t *frame) {
    f_offset(frame, &offsets_frame);
    f_mask_replace(frame, &bad_pixels_frame);
}

static void proc_image_frame(frame16_t *frame, unsigned int frame_i) {
    f_scrub(frame, frames, frame_i);
    f_gain(frame, &gains_frame);
    f_2x2_bin(frame, &binned_frame);
    f_coadd(&output_frame, &binned_frame);
}

void check_obpmark(testresult_t *result, void (*start)(), void (*stop)());

testcase_t testcases[] = {
    { .name = "obpmark_1_1_seq", .test = check_obpmark },
    {0, 0}
};

int main(void) {
    if (rt_cluster_id() != 0)
        return bench_cluster_forward(0);

    if (get_core_id() == 0)
        run_suite(testcases);

    synch_barrier();
    return 0;
}

void check_obpmark(testresult_t *result, void (*start)(), void (*stop)()) {
    if (get_core_id() != 0) return;

    init_frames();
    gen_rand_data();

    /* Configure and start the cycle performance counter explicitly
     * (bench_timer_start only calls perf_start() when PROFILE is defined).
     * riscv_v5 API: conf_events selects which events, setall zeroes the
     * counters, start(mask) activates counting. */
    cpu_perf_conf_events(1 << CSR_PCER_CYCLES);
    cpu_perf_setall(0);
    cpu_perf_start(0);

    start();

    unsigned int frame_i;
    for (frame_i = OFFSET_NEIGHBOURS;
         frame_i < TOTAL_FRAMES - OFFSET_NEIGHBOURS;
         frame_i++) {
        prepare_image_frame(&frames[frame_i + 2u]);
        proc_image_frame(&frames[frame_i], frame_i);
    }

    stop();

    cpu_perf_stop();
    unsigned int cycles = cpu_perf_get(CSR_PCER_CYCLES);

    /* Cluster runs at 50 MHz -> 20 ns per cycle */
    unsigned int pixels     = IMG_W * IMG_H * NUM_FRAMES;
    unsigned int time_us    = (unsigned int)(((unsigned long long)cycles * 20ULL) / 1000ULL);
    unsigned int tp_int     = (unsigned int)(((unsigned long long)pixels * 50ULL) / cycles);
    unsigned int tp_frac    = (unsigned int)((((unsigned long long)pixels * 50ULL) % cycles) * 100ULL / cycles);

    unsigned int out = (unsigned int)PIXEL(&output_frame, 0, 0);

    printf("OBPMark 1.1 - Image Calibration and Correction\n");
    printf("PULP cluster sequential (1 core, RV32) - Astral @ 50 MHz\n");
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