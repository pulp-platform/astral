// Copyright 2024 ETH Zurich and University of Bologna.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0
//
// OBPMark Benchmark #1.1 - Image Calibration and Correction
// Bare-metal port for Astral/Carfield (CVA6, RV64)
//
// Porting notes vs versione Linux originale:
//   - Algorithm (processing.c) copiato identico
//   - malloc/free ? array statici globali (no heap su bare-metal)
//   - File I/O ? generazione sintetica con rand() seed 21121993 (come -r)
//   - clock() POSIX ? csrr mcycle (cycle counter hardware RISC-V)
//   - Argomenti CLI ? costanti hardcoded (no OS, no argv)
//   - Output in ms usando ClkPeriodRef = 20ns (50 MHz, da astral_fix.sv)
//
// Build targets (stesso .c, linker script diverso):
//   make sw/tests/bare-metal/hostd/obpmark_1_1.car.l2.elf    (Dynamic SPM ~512KB)
//   make sw/tests/bare-metal/hostd/obpmark_1_1.car.dram.elf  (HyperRAM, nessun limite)
//
// Memoria occupata con IMG_W=IMG_H=128:
//   12 frame uint16: 12 x 128 x 128 x 2 = 393 KB
//   offsets + gains: 2  x 128 x 128 x 2 =  64 KB
//   bad_pixels:          128 x 128 x 1  =  16 KB
//   output + binned: 2  x  64 x  64 x 4 =  32 KB
//   TOTALE                               = ~505 KB

#include "regs/cheshire.h"
#include "dif/clint.h"
#include "dif/uart.h"
#include "params.h"
#include "util.h"
#include "car_util.h"
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

// Clock CVA6 in simulazione Astral (da astral_fix.sv: ClkPeriodRef = 20ns)
#define CVA6_CLK_PERIOD_NS  20ULL
#define CVA6_FREQ_HZ        50000000ULL

// ============================================================
// Strutture dati (identiche a obpmark_image.h originale, 1D flat buffer)
// ============================================================
typedef struct { uint16_t *f; unsigned int w; unsigned int h; } frame16_t;
typedef struct { uint8_t  *f; unsigned int w; unsigned int h; } frame8_t;
typedef struct { uint32_t *f; unsigned int w; unsigned int h; } frame32_t;

#define PIXEL(frame, x, y) ((frame)->f[(y) * (frame)->w + (x)])

// ============================================================
// Backing storage statico (sostituisce malloc)
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

// ============================================================
// init_frames: collega puntatori ai buffer statici
// (sostituisce device_memory_init + copy_memory_to_device)
// ============================================================
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
// Generazione dati sintetici (identica a util_data_rand.c originale)
// Seed 21121993 = BENCHMARK_RAND_SEED
// LCG compatibile con glibc rand()
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
// KERNEL FUNCTIONS  copiate identiche da processing.c originale
// ============================================================

// [I] Bias offset correction
static void f_offset(frame16_t *frame, frame16_t *offsets) {
    unsigned int x, y;
    for (x = 0; x < frame->w; x++)
        for (y = 0; y < frame->h; y++)
            PIXEL(frame, x, y) -= PIXEL(offsets, x, y);
}

// Helper per [II]
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
static void f_mask_replace(frame16_t *frame, frame8_t *mask) {
    unsigned int x, y;
    for (x = 0; x < frame->w; x++)
        for (y = 0; y < frame->h; y++)
            if (PIXEL(mask, x, y) == 1u)
                PIXEL(frame, x, y) = (uint16_t)f_neighbour_masked_sum(
                    frame, mask, (int)x, (int)y);
}

// [III] Radiation scrubbing
static void f_scrub(frame16_t *frame, frame16_t *fs, unsigned int frame_i) {
    unsigned int x, y;
    static unsigned int num_neighbour = 4u;
    uint32_t sum, mean, thr;

    for (x = 0; x < frame->w; x++)
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
static void f_gain(frame16_t *frame, frame16_t *gains) {
    unsigned int x, y;
    for (x = 0; x < frame->w; x++)
        for (y = 0; y < frame->h; y++)
            PIXEL(frame, x, y) = (uint16_t)(
                ((uint32_t)PIXEL(frame, x, y) *
                 (uint32_t)PIXEL(gains, x, y)) >> 16);
}

// [V] 2x2 Spatial binning
static void f_2x2_bin(frame16_t *frame, frame32_t *binned) {
    unsigned int x, y, x2, y2;
    x2 = 0u;
    for (x = 0; x < frame->w; x += 2u) {
        y2 = 0u;
        for (y = 0; y < frame->h; y += 2u) {
            PIXEL(binned, x2, y2) = PIXEL(frame,  x,     y    )
                                  + PIXEL(frame, (x+1u), y    )
                                  + PIXEL(frame,  x,    (y+1u))
                                  + PIXEL(frame, (x+1u),(y+1u));
            ++y2;
        }
        ++x2;
    }
}

// [VI] Frame co-adding
static void f_coadd(frame32_t *sum_frame, frame32_t *add_frame) {
    unsigned int x, y;
    for (x = 0; x < sum_frame->w; x++)
        for (y = 0; y < sum_frame->h; y++)
            PIXEL(sum_frame, x, y) += PIXEL(add_frame, x, y);
}

// ============================================================
// Pipeline identica a process_benchmark() di device.c originale
// ============================================================
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

// ============================================================
// Cycle counter RISC-V (sostituisce clock() di obpmark_time.h)
// ============================================================
static inline uint64_t read_mcycle(void) {
    uint64_t cycles;
    asm volatile ("csrr %0, mcycle" : "=r"(cycles));
    return cycles;
}

// Conversione cicli ? tempo e throughput
// ClkPeriodRef = 20ns ? 50 MHz (da astral_fix.sv, modalita' senza TECH_SIM)
static void print_results(uint64_t cycles) {
    uint64_t time_ns     = cycles * CVA6_CLK_PERIOD_NS;
    uint64_t time_us     = time_ns / 1000ULL;
    uint64_t time_ms_int = time_us / 1000ULL;
    uint64_t time_ms_frac= time_us % 1000ULL;

    // throughput [Mpixel/s] = (W * H * N_frames * freq_Hz) / (cycles * 1e6)
    //                       = (W * H * N_frames * 50) / cycles
    uint64_t pixels = (uint64_t)IMG_W * (uint64_t)IMG_H * (uint64_t)NUM_FRAMES;
    uint64_t tp_int  = (pixels * 50ULL) / cycles;
    uint64_t tp_frac = ((pixels * 50ULL) % cycles) * 100ULL / cycles;

    printf("Benchmark metrics:\r\n");
    printf("  Elapsed cycles : %llu\r\n",          (unsigned long long)cycles);
    printf("  Elapsed time   : %llu.%03llu ms\r\n",(unsigned long long)time_ms_int,
                                                    (unsigned long long)time_ms_frac);
    printf("  Throughput     : %llu.%02llu Mpixel/s\r\n",
           (unsigned long long)tp_int, (unsigned long long)tp_frac);
}

// ============================================================
// Main
// ============================================================
int main(void) {
    if (hart_id() != 0) wfi();

    car_init_start();

    printf("OBPMark #1.1 - Image Calibration and Correction\r\n");
    printf("Bare-metal - Astral CVA6 RV64 @ 50 MHz\r\n");
    printf("Image: %dx%d px | Frames: %d\r\n", IMG_W, IMG_H, NUM_FRAMES);

    init_frames();
    gen_rand_data();

    // Loop identico a process_benchmark() in device.c
    uint64_t t_start = read_mcycle();

    unsigned int frame_i;
    for (frame_i = OFFSET_NEIGHBOURS;
         frame_i < TOTAL_FRAMES - OFFSET_NEIGHBOURS;
         frame_i++) {
        prepare_image_frame(&frames[frame_i + 2u]);
        proc_image_frame(&frames[frame_i], frame_i);
    }

    uint64_t t_end = read_mcycle();

    printf("Done.\r\n");
    print_results(t_end - t_start);
    printf("Output[0][0]: %u\r\n", (unsigned int)PIXEL(&output_frame, 0, 0));

    return 0;
}
