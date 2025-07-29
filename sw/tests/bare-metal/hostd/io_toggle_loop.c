// Copyright 2023 ETH Zurich and University of Bologna.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0
//
// Yvan Tortorella <yvan.tortorella@chips.it>
//
// GPIO toggle loop for frequency test

#include "regs/cheshire.h"
#include "dif/clint.h"
#include "dif/uart.h"
#include "params.h"
#include "util.h"
#include "car_util.h"
#include "printf.h"
#include "fll.h"
#include "padframe.h"

#define FllMultiplierValue 0x0FA0
#define PassFlag 0xDEADFACE
#define GpioBaseAddr 0x03005000
#define GPIO_DIRECT_OUT_REG_OFFSET 0x14
#define GPIO_DIRECT_OE_REG_OFFSET 0x20
#define Enable 1
#define Repetitions 10
int main(void) {

    // Put SMP Hart to sleep
    if (hart_id() != 0) wfi();

    // Configure PAD_V00 alternate function to GPIO
    write_padframe_mux(PADFRAME_CONFIG_MUXED_V_00_MUX_SEL, PADFRAME_MUXED_V_00_SEL_GPIO_IO_V_0);
    write_padframe_pen(PADFRAME_CONFIG_MUXED_V_00_CFG, 0x1);
    write_padframe_psel(PADFRAME_CONFIG_MUXED_V_00_CFG, 0x1);

    // Enable GPIO direct out
    writew(Enable, GpioBaseAddr + GPIO_DIRECT_OE_REG_OFFSET);
    // Switch FLL to 250 MHz
    set_fll_dco_code(0x226, FLL_HOST_ID);
    // Toggle GPIO
    while (1) {
      for (int j = 0; j < Repetitions; j++) writew(0x1, GpioBaseAddr + GPIO_DIRECT_OUT_REG_OFFSET);
      for (int j = 0; j < Repetitions; j++) writew(0x0, GpioBaseAddr + GPIO_DIRECT_OUT_REG_OFFSET);
    }

    return 0;
}
