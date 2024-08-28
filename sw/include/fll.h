// Copyright 2022 ETH Zurich and University of Bologna.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0
//
// Victor Isachi <victor.isachi@unibo.it>
//
// FLL driver

#ifndef __FLL_H
#define __FLL_H

#include "io.h"
#include "car_memory_map.h"

#define FLL_DCO_CODE_MASK (0x03FF0000)
#define FLL_CLK_DIV_MASK  (0x3C000000)
#define FLL_CLK_MUL_MASK  (0x0000FFFF)
#define FLL_MODE_MASK     (0x80000000)

#define FLL_DCO_CODE_OFFSET (16)
#define FLL_CLK_DIV_OFFSET  (26)
#define FLL_CLK_MUL_OFFSET  (0)
#define FLL_MODE_OFFSET     (31)

inline uint32_t set_bitfield(uint32_t val, uint32_t src_reg, uint32_t bitfield_mask, uint32_t bitfield_offset){
  return (src_reg & ~bitfield_mask) | ((val << bitfield_offset) & bitfield_mask);
}

inline uint32_t read_fll_reg(uint8_t fll_id, uint8_t reg_offset){
  return readw(FLL_BASE_ADDRESS(fll_id) + reg_offset);
}

inline void write_fll_reg(uint32_t val, uint8_t fll_id, uint8_t reg_offset){
  writew(val, FLL_BASE_ADDRESS(fll_id) + reg_offset);
}

void write_fll_bitfield(uint32_t val, uint8_t fll_id, uint8_t reg_offset, uint32_t bitfield_mask, uint8_t bitfield_offset){
  uint32_t fll_reg;
  fll_reg = read_fll_reg(fll_id, reg_offset);
  fll_reg = set_bitfield(val, fll_reg, bitfield_mask, bitfield_offset);
  write_fll_reg(fll_reg, fll_id, reg_offset);
}

void fll_stand_alone(uint8_t fll_id){
  write_fll_bitfield(0x0, fll_id, FLL_CONFIG_REG_I, FLL_MODE_MASK, FLL_MODE_OFFSET);
}

void fll_normal(uint8_t fll_id){
  write_fll_bitfield(0x1, fll_id, FLL_CONFIG_REG_I, FLL_MODE_MASK, FLL_MODE_OFFSET);
}

void set_fll_dco_code(uint32_t dco_code, uint8_t fll_id){
  write_fll_bitfield(dco_code, fll_id, FLL_CONFIG_REG_I, FLL_DCO_CODE_MASK, FLL_DCO_CODE_OFFSET);
}

void set_fll_clk_div(uint32_t clk_div, uint8_t fll_id){
  write_fll_bitfield(clk_div, fll_id, FLL_CONFIG_REG_I, FLL_CLK_DIV_MASK, FLL_CLK_DIV_OFFSET);
}

void set_fll_clk_mul(uint32_t clk_mul, uint8_t fll_id){
  write_fll_bitfield(clk_mul, fll_id, FLL_CONFIG_REG_I, FLL_CLK_MUL_MASK, FLL_CLK_MUL_OFFSET);
}

#endif /*__FLL_H*/