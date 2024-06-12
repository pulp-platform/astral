// Copyright 2023 ETH Zurich and University of Bologna.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0
//
// Yvan Tortorella <yvan.tortorella@studio.unibo.it>
//
// DMA-based SpW test

#include "regs/soc_ctrl.h"
#include "dif/clint.h"
#include "params.h"
#include "car_util.h"
#include "printf.h"

#define SpWCodecRegOffs 0x000
#define SpWCodecReg0 SpWCodecRegOffs + 0x0
#define SpWCodecReg1 SpWCodecRegOffs + 0x4
#define SpWCodecReg2 SpWCodecRegOffs + 0x8

#define SpWDmaRegOffs 0x100
#define SpWDmaSrcAddr SpWDmaRegOffs + 0x0
#define SpWDmaDstAddr SpWDmaRegOffs + 0x4
#define SpWDmaTransfLen SpWDmaRegOffs +0x8
#define SpWDmaTransfId SpWDmaRegOffs +0x14

int main(void) {

    // Put SMP Hart to sleep
    if (hart_id() != 0) wfi();

    // Isolate the SpW
    writew(0x1, car_soc_ctrl + CARFIELD_SPW_ISOLATE_REG_OFFSET);

    // Enable SpW clock divider
    writew(0x1, car_soc_ctrl + CARFIELD_SPW_CLK_DIVIDER_ENABLE_REG_OFFSET);

    // Set clock division value and validate it
    writew(0x1, car_soc_ctrl + CARFIELD_SPW_CLK_DIVISION_VALUE_REG_OFFSET);
    writew(0x1, car_soc_ctrl + CARFIELD_SPW_CLK_DIVISION_VALID_REG_OFFSET);

    // Deisolate the SpW
    writew(0x0, car_soc_ctrl + CARFIELD_SPW_ISOLATE_REG_OFFSET);

    // Write in the SpW DMA config registers
    writew(0x78000000, car_dmaspw_cfg + SpWDmaSrcAddr); // Src address
    writew(0x80000000, car_dmaspw_cfg + SpWDmaDstAddr); // Dst Address
    writew(0x10, car_dmaspw_cfg + SpWDmaTransfLen); // Transfer len

    // Read the same registers and count errors
    uint32_t errors = 0;
    errors += (readw(car_dmaspw_cfg + SpWDmaSrcAddr) != 0x78000000);
    errors += (readw(car_dmaspw_cfg + SpWDmaDstAddr) != 0x80000000);
    errors += (readw(car_dmaspw_cfg + SpWDmaTransfLen) != 0x10);

    // Write in the SpW Codec registers
    writew(0xB10, car_dmaspw_cfg + SpWCodecReg1); // [11] : 1'b1        (En. timecode tick-out int.)
                                                  // [10] : 1'b0        (Link Disabled)
                                                  // [9]  : 1'b1        (Link Start)
                                                  // [8]  : 1'b1        (Link Autostart)
                                                  // [7:0]: 8'b00010000 (TX Clock Divider)
    // Read the same registers and count errors
    errors += (readw(car_dmaspw_cfg + SpWCodecReg1) != 0xB10);

    // Start a DMA transaction
    uint32_t dma_trans_id = readw(car_dmaspw_cfg + SpWDmaTransfId);

    return errors;
}
