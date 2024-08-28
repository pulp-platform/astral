// Copyright 2022 ETH Zurich and University of Bologna.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0
//
// Victor Isachi <victor.isachi@unibo.it>
//
// Padframe driver

#ifndef __PADFRAME_H
#define __PADFRAME_H

#include "io.h"
#include "car_memory_map.h"

inline void write_padframe_mux(uint8_t mux_sel_reg_offset, uint8_t mux_id){
  writew(mux_id, PADFRAME_BASE_ADDRESS + mux_sel_reg_offset);
}

void write_padframe_pen(uint8_t cfg_reg_offset, uint8_t pen){
  uint32_t config_reg = readw(PADFRAME_BASE_ADDRESS + cfg_reg_offset);
  config_reg = (config_reg & ~0x8 ) | ((pen & 0x1) << 3);
  writew(config_reg, PADFRAME_BASE_ADDRESS + cfg_reg_offset);
}

void write_padframe_psel(uint8_t cfg_reg_offset, uint8_t psel){
  uint32_t config_reg = readw(PADFRAME_BASE_ADDRESS + cfg_reg_offset);
  config_reg = (config_reg & ~0x10 ) | ((pen & 0x1) << 4);
  writew(config_reg, PADFRAME_BASE_ADDRESS + cfg_reg_offset);
}

#endif /*__PADFRAME_H*/