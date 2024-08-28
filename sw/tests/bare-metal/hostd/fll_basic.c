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
#include "fll.h"

int main(void) {

    // Put SMP Hart to sleep
    if (hart_id() != 0) wfi();

    // Stand-alone mode

    set_fll_dco_code(0x1F5, FLL_HOST_ID);
    set_fll_clk_div(0x1, FLL_HOST_ID);

    set_fll_dco_code(0x1F5, FLL_PERIPH_ID);
    set_fll_clk_div(0x1, FLL_PERIPH_ID);

    set_fll_dco_code(0x1F5, FLL_ALT_ID);
    set_fll_clk_div(0x1, FLL_ALT_ID);

    set_fll_dco_code(0x1F5, FLL_SECD_ID);
    set_fll_clk_div(0x1, FLL_SECD_ID);

    set_fll_dco_code(0x1F5, FLL_RT_ID);
    set_fll_clk_div(0x1, FLL_RT_ID);

    // Normal mode

    set_fll_clk_div(0x2, FLL_HOST_ID);
    set_fll_clk_mul(0x63, FLL_HOST_ID);
    fll_normal(FLL_HOST_ID);

    set_fll_clk_div(0x2, FLL_PERIPH_ID);
    set_fll_clk_mul(0x63, FLL_PERIPH_ID);
    fll_normal(FLL_PERIPH_ID);

    set_fll_clk_div(0x2, FLL_ALT_ID);
    set_fll_clk_mul(0x63, FLL_ALT_ID);
    fll_normal(FLL_ALT_ID);

    set_fll_clk_div(0x2, FLL_SECD_ID);
    set_fll_clk_mul(0x63, FLL_SECD_ID);
    fll_normal(FLL_SECD_ID);

    set_fll_clk_div(0x2, FLL_RT_ID);
    set_fll_clk_mul(0x63, FLL_RT_ID);
    fll_normal(FLL_RT_ID);

    // Init the HW
    car_init_start();

    // NEED TO MANUALLY VERIFY THE CORECTNESS OF THE GENERATED CLOCKS

    return 0;
}
