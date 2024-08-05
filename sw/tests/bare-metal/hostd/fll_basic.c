// Copyright 2023 ETH Zurich and University of Bologna.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0
//
// Victor Isachi <victor.isachi@unibo.it>
//
// Simple FLL test - no automatic checking

#include "regs/cheshire.h"
#include "dif/clint.h"
#include "dif/uart.h"
#include "params.h"
#include "util.h"
#include "car_util.h"
#include "printf.h"

#define FLL_HOST_ADDR     (0x21003000)
#define FLL_PERIPH_ADDR   (0x21003020)
#define FLL_ALT_ADDR      (0x21003040)
#define FLL_RT_ADDR       (0x21003060)

#define FLL_STATUS_REG_I  (0x00)
#define FLL_CONFIG_REG_I  (0x08)
#define FLL_CONFIG_REG_II (0x10)
#define FLL_INTEGR_REG    (0x18)

#define FLL_DCO_CODE_MASK (0x03FF0000)
#define FLL_CLK_DIV_MASK  (0x3C000000)
#define FLL_CLK_MUL_MASK  (0x0000FFFF)
#define FLL_MODE_MASK     (0x80000000)

#define FLL_DCO_CODE_OFFSET (16)
#define FLL_CLK_DIV_OFFSET  (26)
#define FLL_CLK_MUL_OFFSET  (0)
#define FLL_MODE_OFFSET     (31)

inline uint32_t write_bitfield(uint32_t src_reg, uint32_t bitfield_mask, uint32_t bitfield_offset, uint32_t val){
    return (src_reg & ~bitfield_mask) | (val << bitfield_offset);
}

int main(void) {

    // Put SMP Hart to sleep
    if (hart_id() != 0) wfi();

    uint32_t config_reg_host;
    uint32_t config_reg_periph;
    uint32_t config_reg_alt;
    uint32_t config_reg_rt;

    // Stand-alone mode

    config_reg_host = readw(FLL_HOST_ADDR + FLL_CONFIG_REG_I);
    config_reg_host = write_bitfield(config_reg_host, FLL_DCO_CODE_MASK, FLL_DCO_CODE_OFFSET, 0x1F5);
    config_reg_host = write_bitfield(config_reg_host, FLL_CLK_DIV_MASK, FLL_CLK_DIV_OFFSET, 0x1);
    writew(config_reg_host, FLL_HOST_ADDR + FLL_CONFIG_REG_I);

    config_reg_periph = readw(FLL_PERIPH_ADDR + FLL_CONFIG_REG_I);
    config_reg_periph = write_bitfield(config_reg_periph, FLL_DCO_CODE_MASK, FLL_DCO_CODE_OFFSET, 0x1F5);
    config_reg_periph = write_bitfield(config_reg_periph, FLL_CLK_DIV_MASK, FLL_CLK_DIV_OFFSET, 0x1);
    writew(config_reg_periph, FLL_PERIPH_ADDR + FLL_CONFIG_REG_I);

    config_reg_alt = readw(FLL_ALT_ADDR + FLL_CONFIG_REG_I);
    config_reg_alt = write_bitfield(config_reg_alt, FLL_DCO_CODE_MASK, FLL_DCO_CODE_OFFSET, 0x1F5);
    config_reg_alt = write_bitfield(config_reg_alt, FLL_CLK_DIV_MASK, FLL_CLK_DIV_OFFSET, 0x1);
    writew(config_reg_alt, FLL_ALT_ADDR + FLL_CONFIG_REG_I);

    config_reg_rt = readw(FLL_RT_ADDR + FLL_CONFIG_REG_I);
    config_reg_rt = write_bitfield(config_reg_rt, FLL_DCO_CODE_MASK, FLL_DCO_CODE_OFFSET, 0x1F5);
    config_reg_rt = write_bitfield(config_reg_rt, FLL_CLK_DIV_MASK, FLL_CLK_DIV_OFFSET, 0x1);
    writew(config_reg_rt, FLL_RT_ADDR + FLL_CONFIG_REG_I);

    // Normal mode

    config_reg_host = readw(FLL_HOST_ADDR + FLL_CONFIG_REG_I);
    config_reg_host = write_bitfield(config_reg_host, FLL_CLK_DIV_MASK, FLL_CLK_DIV_OFFSET, 0x2);
    config_reg_host = write_bitfield(config_reg_host, FLL_CLK_MUL_MASK, FLL_CLK_MUL_OFFSET, 0x63);
    config_reg_host = write_bitfield(config_reg_host, FLL_MODE_MASK, FLL_MODE_OFFSET, 0x1);
    writew(config_reg_host, FLL_HOST_ADDR + FLL_CONFIG_REG_I);

    config_reg_periph = readw(FLL_PERIPH_ADDR + FLL_CONFIG_REG_I);
    config_reg_periph = write_bitfield(config_reg_periph, FLL_CLK_DIV_MASK, FLL_CLK_DIV_OFFSET, 0x2);
    config_reg_periph = write_bitfield(config_reg_periph, FLL_CLK_MUL_MASK, FLL_CLK_MUL_OFFSET, 0x63);
    config_reg_periph = write_bitfield(config_reg_periph, FLL_MODE_MASK, FLL_MODE_OFFSET, 0x1);
    writew(config_reg_periph, FLL_PERIPH_ADDR + FLL_CONFIG_REG_I);

    config_reg_alt = readw(FLL_ALT_ADDR + FLL_CONFIG_REG_I);
    config_reg_alt = write_bitfield(config_reg_alt, FLL_CLK_DIV_MASK, FLL_CLK_DIV_OFFSET, 0x2);
    config_reg_alt = write_bitfield(config_reg_alt, FLL_CLK_MUL_MASK, FLL_CLK_MUL_OFFSET, 0x63);
    config_reg_alt = write_bitfield(config_reg_alt, FLL_MODE_MASK, FLL_MODE_OFFSET, 0x1);
    writew(config_reg_alt, FLL_ALT_ADDR + FLL_CONFIG_REG_I);

    config_reg_rt = readw(FLL_RT_ADDR + FLL_CONFIG_REG_I);
    config_reg_rt = write_bitfield(config_reg_rt, FLL_CLK_DIV_MASK, FLL_CLK_DIV_OFFSET, 0x2);
    config_reg_rt = write_bitfield(config_reg_rt, FLL_CLK_MUL_MASK, FLL_CLK_MUL_OFFSET, 0x63);
    config_reg_rt = write_bitfield(config_reg_rt, FLL_MODE_MASK, FLL_MODE_OFFSET, 0x1);
    writew(config_reg_rt, FLL_RT_ADDR + FLL_CONFIG_REG_I);

    // Init the HW
    car_init_start();

    // NEED TO MANUALLY VERIFY THE CORECTNESS OF THE GENERATED CLOCKS

    return 0;
}
