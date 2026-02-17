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

/* ============================================================
 * Test configuration
 * ============================================================ */

/* Address increment between consecutive test locations */
#define INCREASE_ADDR        0x100000
// alternative values (debug / long tests)
// #define INCREASE_ADDR     0x2000
// #define INCREASE_ADDR     0x1000
// #define INCREASE_ADDR     0x400
// #define INCREASE_ADDR     0x100   // ~4h32m test

/* Seed configuration */
#define DEFAULT_SEED         0xCACA5A5ADEADBEEF

/* LFSR feedback polynomial (64-bit) */
#define FEEDBACK             0x6C0000397F000032

/* ============================================================
 * Hyperbus register map
 * ============================================================ */

#define HYPERBUS_REG_BASE            0x20008000

#define HYPERBUS_PHY_IN_USE_OFFSET   0x20
#define HYPERBUS_WHICH_PHY_OFFSET    0x24

#define HYPERBUS_CS0_BASE_OFFSET     0x30
#define HYPERBUS_CS0_END_OFFSET      0x34
#define HYPERBUS_CS1_BASE_OFFSET     0x38
#define HYPERBUS_CS1_END_OFFSET      0x3C

/* ============================================================
 * HyperRAM address map
 * ============================================================ */

#define CAR_HYPERRAM_BASE_ADDR       0x80000000
#define CAR_HYPERRAM_END_ADDR        0x82000000

#define CAR_HYPERRAM_0_BASE_ADDR     CAR_HYPERRAM_BASE_ADDR
#define CAR_HYPERRAM_0_END_ADDR      0x81000000

#define CAR_HYPERRAM_1_BASE_ADDR     CAR_HYPERRAM_0_END_ADDR
#define CAR_HYPERRAM_1_END_ADDR      CAR_HYPERRAM_END_ADDR

/* ============================================================
 * PHY configuration
 * ============================================================ */

#define PHY_MODE              1   /* 1 = dual PHY, 0 = single PHY */
#define WHICH_PHY             0   /* valid only if PHY_MODE == 0 */

uint64_t get_runtime_seed(void)
{
#ifdef FORCE_SEED
    /* seed forzato a compile-time */
    uint64_t s = (uint64_t)FORCE_SEED;

    /* mixing leggero (xorshift) per rompere pattern banali */
    s ^= (s << 13);
    s ^= (s >> 7);
    s ^= (s << 17);

    /* costruiamo un 64-bit: metà alta derivata da s, metà bassa da s ^ 0xDEADBEEF */
    uint64_t result = (s << 32) | (s ^ 0xDEADBEEF);

    printf("[DBG] FORCE_SEED=%llu mixed=%llu\n", (unsigned long long)FORCE_SEED, (unsigned long long)result);

    return result;
#else
    /* seed di default */
    uint64_t result = (uint64_t)DEFAULT_SEED;
    printf("[DBG] DEFAULT_SEED=%llu\n", (unsigned long long)result);
    return (uint64_t)DEFAULT_SEED;
#endif
}

// int probe_range_direct(volatile uintptr_t from, volatile uintptr_t to)
// {
//     /* Controlli preliminari */
//     if (to <= from)
//         return 2;

//     if (INCREASE_ADDR <= 0)
//         return 2;

//     uintptr_t addr = from;
//     uintptr_t incr = INCREASE_ADDR;
//     int i = 0;

//     while (addr < to) {
//         /* Calcolo del valore da scrivere (pattern semplice + indice) */
//         uint32_t expected = 0xCAFEDEAD + 0xAB + (uint32_t)i;

//         /* Scrivo e leggo */
//         writed(expected, addr);

//         printf("[DBG] wrote 0x%08x to 0x%lx\n", expected, (unsigned long)addr);

//         uint32_t actual = readd(addr);
//         printf("[DBG] read  0x%08x from 0x%lx\n", actual, (unsigned long)addr);

//         if (expected != actual) {
//             printf("[ERROR] mismatch at 0x%lx: expected=0x%08x actual=0x%08x\n", (unsigned long)addr, expected, actual);
//             return 1;
//         }

//         addr += incr;
//         i++;
//     }

//     return 0;
// }

uint64_t lfsr_iter_bit(uint64_t lfsr) {
    return (lfsr & 1) ? ((lfsr >> 1) ^ (uint64_t)FEEDBACK) : (lfsr >> 1);
}

uint64_t lfsr_iter_byte(uint64_t lfsr) {
    for (int i = 0; i < 8; ++i) {
        lfsr = lfsr_iter_bit(lfsr);
    }
    return lfsr;
}

uint64_t lfsr_iter_word(uint64_t lfsr) {
    for (int i = 0; i < 4; ++i) {
        lfsr = lfsr_iter_byte(lfsr);
    }
    return lfsr;
}

uint64_t lfsr_64bits(uint64_t lfsr) {
    for (int i = 0; i < 8; ++i) {
        lfsr = lfsr_iter_byte(lfsr);
    }
    return lfsr;
}

int probe_range_lfsr_wrwr(volatile uintptr_t from, volatile uintptr_t to)
{
    /* controlli preliminari */
    if (to <= from)
        return 2;

    if (INCREASE_ADDR <= 0)
        return 2;

    uintptr_t addr = from;
    const uintptr_t incr = INCREASE_ADDR;
    uint64_t lfsr = get_runtime_seed();

    printf("[WRWR] seed=0x%016lx\n", lfsr);

    int i = 0;

    while (addr < to) {
        /* calcola prossimo valore LFSR e scrivi 64-bit */
        lfsr = lfsr_64bits(lfsr);

        /* scrittura 64-bit: uso puntatore volatile a 64-bit; se preferisci */
        writed(lfsr, addr);

        /* assicurati che la scrittura sia effettivamente visibile */
        fence();

        /* leggi e verifica */
        uint64_t r = readd(addr);

        // printf("[WRWR] i=%d addr=0x%lx wrote=0x%016llx read=0x%016llx\n", i, (unsigned long)addr, (unsigned long long)lfsr, (unsigned long long)r);

        if (r != lfsr) {
            printf("[ERROR] mismatch at i=%d addr=0x%lx wrote=0x%016llx read=0x%016llx\n", i, (unsigned long)addr, (unsigned long long)lfsr, (unsigned long long)r);
            return 1;
        }

        addr += incr;
        ++i;
    }

    return 0;
}

int probe_range_lfsr_wwrr(volatile uintptr_t from, volatile uintptr_t to)
{
    /* Controlli di validità */
    if (to <= from)
        return 2;

    if (INCREASE_ADDR <= 0)
        return 2;

    uintptr_t addr = from;
    const uintptr_t incr = INCREASE_ADDR;

    uint64_t seed = get_runtime_seed();
    uint64_t lfsr = seed;

    printf("[WWRR] seed=0x%016lx\n", seed);

    /* ---------------- WRITE PHASE ---------------- */
    int i = 0;

    while (addr < to) {

        lfsr = lfsr_64bits(lfsr);

        if (i == 0) {
            // printf("[WWRR] FIRST WRITE: addr=0x%lx lfsr=0x%016lx\n", addr, lfsr);
        }

        writed(lfsr, addr);

        addr += incr;
        ++i;
    }

    /* Assicura che tutte le scritture siano visibili */
    fence();

    /* ---------------- READ PHASE ---------------- */
    addr = from;
    lfsr = seed;
    int j = 0;

    while (addr < to) {

        lfsr = lfsr_64bits(lfsr);

        if (j == 0) {
            // printf("[WWRR] FIRST READ:  addr=0x%lx exp=0x%016lx\n", addr, lfsr);
        }

        uint64_t r = readd(addr);

        if (r != lfsr) {
            printf("[WWRR][ERROR] i=%d j=%d addr=0x%lx exp=0x%016lx read=0x%016lx\n", i, j, addr, lfsr, r);
            return 1;
        }

        addr += incr;
        ++j;
    }

    return 0;
}


int test_address_granularity(volatile uintptr_t base)
{
    /* 4 valori distinti da usare nei test */
    uint64_t values[4] = {
        0xAAAAAAAAAAAAAAAA,
        0xBBBBBBBBBBBBBBBB,
        0xCCCCCCCCCCCCCCCC,
        0xDDDDDDDDDDDDDDDD
    };

    /* scrittura e verifica del primo valore alla base */
    writed(values[0], base);
    fence();

    printf("BASE WRITE @0x%lx = 0x%lx\n", base, values[0]);

    /* loop di test su offset multipli di 8 byte */
    for (int i = 1; i < 4; i++) {
        uintptr_t addr = base + (i * 8);

        /* scrivi il valore i-esimo */
        writed(values[i], addr);
        fence();

        /* leggi il valore alla base */
        uint64_t r = readd(base);

        /* stampa risultato */
        printf("WRITE @+%2d (0x%lx) = 0x%lx  BASE_READ = 0x%lx\n", i * 8, addr, values[i], r);

        /* verifica overlap */
        if (r != values[0]) {
            printf("OVERLAP DETECTED starting at +%d\n", i * 8);
            return 1;
        }
    }

    printf("NO OVERLAP detected for 8B increments\n");
    return 0;
}


int configure_hyperbus_cs(void)
{
    uintptr_t base = HYPERBUS_REG_BASE;

    /*
     * Calcolo degli intervalli BASE/END per CS0 e CS1.
     */
    uint32_t cs0_base;
    uint32_t cs0_end;
    uint32_t cs1_base;
    uint32_t cs1_end;

    #if PHY_MODE == 1
        /* Se PHY_MODE == 1 => uso entrambi i PHY con map completa */
        cs0_base = 0x80000000;
        cs0_end  = 0x81000000;
        cs1_base = cs0_end;
        cs1_end  = 0x82000000;

    #elif PHY_MODE == 0

        #if WHICH_PHY == 0
            /* PHY 0 mappa la prima metà (CS0: 0x8000_0000 - 0x807F_FFFF)
             * e CS1 occupa la seconda metà fino a 0x8100_0000 */
            cs0_base = 0x80000000;
            cs0_end  = 0x80800000;
            cs1_base = cs0_end;
            cs1_end  = 0x81000000;
        #elif WHICH_PHY == 1
            /* PHY 1 mappa la seconda metà */
            cs0_base = 0x81000000;
            cs0_end  = 0x81800000;
            cs1_base = cs0_end;
            cs1_end  = 0x82000000;
        #else
            #error "Invalid WHICH_PHY: must be 0 or 1 when PHY_MODE == 0"
        #endif

    #else
        #error "Invalid PHY_MODE: must be 0 or 1"
    #endif

    /* Scrivo i registri PHY in uso / quale PHY (se richiesto dall'hw) */
    #if PHY_MODE == 1
        /* Entrambi i PHY attivi (valore hw = 1) */
        writew(0x1, base + HYPERBUS_PHY_IN_USE_OFFSET);
    #elif PHY_MODE == 0
        /* Uso singolo PHY = 0 */
        writew(0x0, base + HYPERBUS_PHY_IN_USE_OFFSET);

        #if WHICH_PHY == 0
            writew(0x0, base + HYPERBUS_WHICH_PHY_OFFSET);
        #elif WHICH_PHY == 1
            writew(0x1, base + HYPERBUS_WHICH_PHY_OFFSET);
        #endif
    #endif

    /* Assicura che le scritture siano effettive prima di leggere */
    fence();

    /* Leggo i registri PHY per conferma (opzionale, debug commentato) */
    uint32_t phy_in_use = readw(base + HYPERBUS_PHY_IN_USE_OFFSET);
    uint32_t which_phy  = readw(base + HYPERBUS_WHICH_PHY_OFFSET);

    // printf("[DBG] HYPERBUS CFG regs:\n");
    printf("[DBG] phys_in_use @0x%lx = 0x%08x\n", (unsigned long)(base + HYPERBUS_PHY_IN_USE_OFFSET), phy_in_use);      
    printf("[DBG] which_phy   @0x%lx = 0x%08x\n", (unsigned long)(base + HYPERBUS_WHICH_PHY_OFFSET), which_phy);

    /* Scrivo i registri CS (BASE/END) */
    writew(cs0_base, base + HYPERBUS_CS0_BASE_OFFSET);
    writew(cs0_end,  base + HYPERBUS_CS0_END_OFFSET);

    writew(cs1_base, base + HYPERBUS_CS1_BASE_OFFSET);
    writew(cs1_end,  base + HYPERBUS_CS1_END_OFFSET);

    /* Barriera per garantire che le scritture siano completate */
    fence();

    /* Leggo indietro i valori per verifica */
    uint32_t r0 = readw(base + HYPERBUS_CS0_BASE_OFFSET);
    uint32_t r1 = readw(base + HYPERBUS_CS0_END_OFFSET );
    uint32_t r2 = readw(base + HYPERBUS_CS1_BASE_OFFSET);
    uint32_t r3 = readw(base + HYPERBUS_CS1_END_OFFSET );

    // printf("[DBG] HYPERBUS CS regs scritti/verificati:\n");
    printf("[DBG] CS0 BASE @0x%lx wrote=0x%08x read=0x%08x\n", (unsigned long)(base + HYPERBUS_CS0_BASE_OFFSET), cs0_base, r0);
    printf("[DBG] CS0 END  @0x%lx wrote=0x%08x read=0x%08x\n", (unsigned long)(base + HYPERBUS_CS0_END_OFFSET),  cs0_end,  r1);
    printf("[DBG] CS1 BASE @0x%lx wrote=0x%08x read=0x%08x\n", (unsigned long)(base + HYPERBUS_CS1_BASE_OFFSET), cs1_base, r2);
    printf("[DBG] CS1 END  @0x%lx wrote=0x%08x read=0x%08x\n", (unsigned long)(base + HYPERBUS_CS1_END_OFFSET),  cs1_end,  r3);

    /* Se uno dei valori letti non corrisponde a quello scritto, segnala errore */
    if (r0 != cs0_base || r1 != cs0_end ||
        r2 != cs1_base || r3 != cs1_end) {
        printf("[ERROR] mismatch scrittura registri Hyperbus CS\n");
        return 1;
    }

    return 0; /* OK */
}



int main(void) {

    /* Inizializza il dominio HW necessario (PULP island) */
    car_enable_domain(CAR_PULP_RST);
    car_init_uart();

    /* --- configurazione Hyperbus CS registers --- */
    if (configure_hyperbus_cs()) {
        printf("[ERROR] configure_hyperbus_cs failed\n");
        return 2;
    }

    uint32_t error = 0;
    uint32_t errors = 0;

    /* Determino l'intervallo di indirizzi HyperRAM da testare in base
       alla modalità PHY selezionata per evitare duplicazioni di codice. */
    uint64_t *test_base = NULL;
    uint64_t *test_end  = NULL;

    #if PHY_MODE == 1
        test_base = (uint64_t *)CAR_HYPERRAM_BASE_ADDR;
        test_end  = (uint64_t *)CAR_HYPERRAM_END_ADDR;

    #elif PHY_MODE == 0

        #if WHICH_PHY == 0
            test_base = (uint64_t *)CAR_HYPERRAM_0_BASE_ADDR;
            test_end  = (uint64_t *)CAR_HYPERRAM_0_END_ADDR;
        #elif WHICH_PHY == 1
            test_base = (uint64_t *)CAR_HYPERRAM_1_BASE_ADDR;
            test_end  = (uint64_t *)CAR_HYPERRAM_1_END_ADDR;
        #else
            #error "Invalid WHICH_PHY: must be 0 or 1 when PHY_MODE == 0"
        #endif

    #else
        #error "Invalid PHY_MODE: must be 0 or 1"
    #endif

    /* Eseguo il primo test: WRWR (write/read write/read pattern) */
    error = probe_range_lfsr_wrwr(test_base, test_end);
    if (error) {
        printf("[ERROR] L3: WRWR failed (errors=%u)\n", error);
        errors += error;
    }

    /* Eseguo il secondo test: WWRR (write/write read/read pattern) */
    error = probe_range_lfsr_wwrr(test_base, test_end);
    if (error) {
        printf("[ERROR] L3: WWRR failed (errors=%u)\n", error);
        errors += error;
    }

    /* Se arrivo qui non ci sono errori fatali rilevati */
    // printf("[INFO] tests completed, total errors = %u\n", errors);

    return errors;
}
