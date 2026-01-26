// Copyright 2023 ETH Zurich and University of Bologna.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0
//
// Alessandro Ottaviano <aottaviano@iis.ee.ethz.ch>
//

#include "car_memory_map.h"
#include "dif/clint.h"
#include "dif/uart.h"
#include "io.h"
#include "car_util.h"
#include "params.h"
#include "regs/cheshire.h"
#include "util.h"
#include "printf.h"

#define N_SAMPLES 64
#define INCREASE_ADDR 0x10000
//#define INCREASE_ADDR 0x2000
//#define INCREASE_ADDR 0x1000
//#define INCREASE_ADDR 0x400
//#define INCREASE_ADDR 0x100 // 4 ore e 32 minuti
#define DEFAULT_SEED 0xcaca5a5adeadbeef
#define FEEDBACK 0x6c0000397f000032


uint64_t get_runtime_seed(void){
    #ifdef FORCE_SEED
        /* Use the compile-time seed provided by the Makefile */
        //return (uint64_t)FORCE_SEED;
        uint64_t s = (uint64_t)FORCE_SEED;
        s ^= (s << 13);
        s ^= (s >> 7);
        s ^= (s << 17);
        return (s << 32) | (s ^ 0xdeadbeef);
    #else
        return DEFAULT_SEED;
    #endif
}

int diyprintf(char *str, int size) {
    // char str[] = "Hello World!\r\n";
    uint32_t rtc_freq = *reg32(&__base_regs, CHESHIRE_RTC_FREQ_REG_OFFSET);
    uint64_t reset_freq = clint_get_core_freq(rtc_freq, 2500);
    uart_init(&__base_uart, reset_freq, 115200);
    uart_write_str(&__base_uart, str, size);
    uart_write_flush(&__base_uart);
    return 0;
}

//uint64_t *lfsr_byte_feedback;

/* probe address range "samples" time, evenly spaced */
int probe_range_direct(volatile uintptr_t from, volatile uintptr_t to, int samples) {
    // check whether arguments passed make sense
    if ((samples < 0) || (to < from))
        return 2;

    uintptr_t addr = from;
    uintptr_t incr = INCREASE_ADDR;
    int i = 0;
    while (addr < to)
    {
        // write
        uint32_t expected = 0xcafedead + 0xab + i;
        writed(expected, addr);
        // read
        if (expected != readd(addr))
            return 1;
        // increment
        addr += incr;
        i++;
    }

    return 0;
}

uint64_t lfsr_iter_bit(uint64_t lfsr) {
    return (lfsr & 1) ? ((lfsr >> 1) ^ FEEDBACK) : (lfsr >> 1);
}

uint64_t lfsr_iter_byte(uint64_t lfsr) {
    uint64_t x = lfsr;
    for (int i = 0; i < 8; ++i) {
        x = lfsr_iter_bit(x);
    }
    return x;
}

uint64_t lfsr_iter_word(uint64_t lfsr) {
    // 4 * 8 bit => 32 bit iteration --> ma su 64-bit usiamo 4 bytes
    uint64_t x = lfsr_iter_byte(lfsr);
    x = lfsr_iter_byte(x);
    x = lfsr_iter_byte(x);
    x = lfsr_iter_byte(x);
    return x;
}

uint64_t lfsr_64bits(uint64_t lfsr) {
    uint64_t x = lfsr;
    for (int i = 0; i < 8; ++i) {
        x = lfsr_iter_byte(x);
    }
    return x;
}

int probe_range_lfsr_wrwr(volatile uintptr_t from, volatile uintptr_t to, int samples) {
    // check whether arguments passed make sense
    if ((samples < 0) || (to < from))
        return 2;

    uintptr_t addr = from;
    uintptr_t incr = INCREASE_ADDR;
    uint64_t lfsr = get_runtime_seed();
    printf("[WRWR] lfsr_seed=%lx\n", lfsr);
    int i = 0;
    while (addr < to)
    {
        // write
        lfsr = lfsr_64bits(lfsr);
        writed(lfsr, addr);
        fence();
        // read
        if (lfsr != readd(addr)){
            printf("i=%d, WRWR CASE ADDR = 0x%lx\n", i, addr);
            return 1;
        }
        // increment
        addr += incr;
        ++i;
    }


    return 0;
}

int probe_range_lfsr_wwrr(volatile uintptr_t from, volatile uintptr_t to, int samples) {
    // check whether arguments passed make sense
    if ((samples < 0) || (to < from))
        return 2;

    uint64_t seed = get_runtime_seed();
    uintptr_t addr = from;
    uintptr_t incr = INCREASE_ADDR; 
    // write
    uint64_t lfsr = seed;
    printf("[WWRR] seed=%lx\n", seed);
    int i = 0;
    while (addr < to)
    {
        lfsr = lfsr_64bits(lfsr);
        /*
        if (i == 0) {
            printf("[WWRR] FIRST WRITE: addr=0x%lx lfsr=0x%lx\n", addr, lfsr);
        }
        */
        
        /*
        if (addr >= 0x80C00000) {
            printf("[WWRR][WRITE] after 0x80C00000 i=%d addr=0x%lx lfsr=0x%lx\n",
                   i, addr, lfsr);
        }
        */
        // write
        writed(lfsr, addr);
        // increment
        addr += incr;
        ++i;
    }

    fence();

    // read
    addr = from;
    lfsr = seed;
    uint64_t lfsr_read = 0;
    int j = 0;
    
    while (addr < to)
    {
        lfsr = lfsr_64bits(lfsr);
        /*
        if (j == 0) {
            printf("[WWRR] FIRST READ:  addr=0x%lx lfsr_exp=0x%lx\n", addr, lfsr);
        }        
        */

        // read
        lfsr_read = readd(addr);
        if (lfsr != lfsr_read){
            printf("[WWRR] LFSR READ: lfsr_read=0x%lx\n", lfsr_read);
            printf("i=%d, j=%d, WWRR CASE ADDR = 0x%lx\n", i, j, addr);
            return 1;
        }
        // increment
        addr += incr;
        ++j;
    }
    
    /*
    int error_seen = 0;
    int post_error_reads = 0;
    #define EXTRA_READS 15
    uint64_t lfsr_values[64];
    while (addr < to)
    {
        lfsr = lfsr_64bits(lfsr, lfsr_byte_feedback);
        lfsr_read = readd(addr);

        if (error_seen) {
            printf("[WWRR][READ] j=%d addr=0x%lx exp=0x%lx read=0x%lx\n",
                   j, addr, lfsr, lfsr_read);
        }

        if (lfsr != lfsr_read && !error_seen) {
            printf("[WWRR] FIRST ERROR at addr=0x%lx\n", addr);
            error_seen = 1;
            post_error_reads = EXTRA_READS;
        }

        addr += incr;
        ++j;

        if (error_seen) {
            post_error_reads--;
            if (post_error_reads <= 0)
                return 1;
        }
    }      
    */

    return 0;
}

int test_address_granularity(volatile uintptr_t base)
{
    uint64_t v0 = 0xAAAAAAAAAAAAAAAA;
    uint64_t v1 = 0xBBBBBBBBBBBBBBBB;

    /* scrittura di riferimento */
    writed(v0, base);
    fence();

    /* scrittura volutamente sovrapposta (+4) */
    writed(v1, base + 4);
    fence();

    uint64_t r = readd(base);

    printf("wrote @0x%lx and @0x%lx  base_read=0x%lx\n",
           base, base + 4, r);

    if (r != v0) {
        printf("EXPECTED OVERLAP at +4 detected\n");
        return 1;   
    }

    printf("WARNING: no overlap at +4 (unexpected)\n");
    return 0;      
}





int main(void) {

    // Put SMP Hart to sleep
    // if (hart_id() != 0) wfi();

    // Init the HW
    // Safety Island
    // car_enable_domain(CAR_SAFETY_RST);

    // PULP Island
    car_enable_domain(CAR_PULP_RST);

    // Spatz Island
    // car_enable_domain(CAR_SPATZ_RST);

    uint32_t error = 0;
    uint32_t errors = 0;


    //errors = test_address_granularity(CAR_HYPERRAM_BASE_ADDR);


    // Probe an address range with pseudo-random values and read after each write
    // (wrwr)

    // HyperRAM
    
    error += probe_range_lfsr_wrwr((uint64_t *)CAR_HYPERRAM_BASE_ADDR, (uint64_t *)CAR_HYPERRAM_END_ADDR, N_SAMPLES);

    if (error) {
        printf("L3: WRWR failed.");
        errors += error;
        error = 0;
    } 

    // HyperRAM
    
    error += probe_range_lfsr_wwrr((uint64_t *)CAR_HYPERRAM_BASE_ADDR, (uint64_t *)CAR_HYPERRAM_END_ADDR, N_SAMPLES);

    if (error) {
        printf("L3: WWRR failed.");
        errors += error;
        error = 0;
    } 
    
    return errors;
}
