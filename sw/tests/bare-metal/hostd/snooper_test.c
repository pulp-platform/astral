// Copyright 2023 ETH Zurich and University of Bologna.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0
//
// Nicole Narr <narrn@student.ethz.ch>
// Christopher Reinwardt <creinwar@student.ethz.ch>
// Paul Scheffler <paulsc@iis.ee.ethz.ch>

#include "regs/cheshire.h"
#include "dif/clint.h"
#include "dif/uart.h"
#include "params.h"
#include "util.h"
#include "regs/snooper_regs.h"
#include "printf.h"
#include "car_util.h"

// #define INSTR

void set_register_bit(void *base_addr, uint32_t reg_offset, uint32_t bit_position) {
    uint32_t reg_value = *reg32(base_addr, reg_offset);
    reg_value |= (1 << bit_position);
    *reg32(base_addr, reg_offset) = reg_value;
    /* PRINT: indicate which bit was set */
    printf("[DBG] set_register_bit: reg_offset=0x%X bit=%u new_val=0x%08X\n",
           reg_offset, bit_position, *reg32(base_addr, reg_offset));
}

void dummy_code(void) {
    printf("[DBG] dummy_code: entry\n");
    *reg32(&__base_regs, CHESHIRE_SCRATCH_0_REG_OFFSET) = 0;
    *reg32(&__base_regs, CHESHIRE_SCRATCH_1_REG_OFFSET) = 1;
    *reg32(&__base_regs, CHESHIRE_SCRATCH_2_REG_OFFSET) = 2;
    *reg32(&__base_regs, CHESHIRE_SCRATCH_3_REG_OFFSET) = 3;

    printf("[DBG] dummy_code: about to loop, SCRATCH_3=%u\n",
           *reg32(&__base_regs, CHESHIRE_SCRATCH_3_REG_OFFSET));

    for (int i=0; i<(int) *reg32(&__base_regs, CHESHIRE_SCRATCH_3_REG_OFFSET); i++) {
        *reg32(&__base_regs, CHESHIRE_SCRATCH_0_REG_OFFSET) = 0;
        /* evita print in ogni iterazione per non rallentare; se vuoi abilitarli,
           decommenta la riga seguente */
        /* printf("[DBG] dummy_code: loop i=%d\n", i); */
    }
    printf("[DBG] dummy_code: exit\n");
}

int main(void) {

    car_init_uart();
    printf("Start:\n");
    extern char dummy_code_start, dummy_code_end;

    // Configure LSBs and MSBs of START_ADDRESS for RANGE_0, first and only logging region
    *reg32(&__base_snprcfg, CFG_REGS_RANGE_0_BASE_H_REG_OFFSET) = 0x00000000;
    *reg32(&__base_snprcfg, CFG_REGS_RANGE_0_BASE_L_REG_OFFSET) = (uint32_t)&dummy_code_start;

    // Configure LSBs and MSBs of END_ADDRESS for RANGE_0, first and only logging region
    *reg32(&__base_snprcfg, CFG_REGS_RANGE_0_LAST_H_REG_OFFSET) = 0x00000000;
    *reg32(&__base_snprcfg, CFG_REGS_RANGE_0_LAST_L_REG_OFFSET) = (uint32_t)&dummy_code_end;

    /* PRINT: show configured addresses */
    printf("[DBG] Configured RANGE_0: start=%p end=%p\n",
           (void *)&dummy_code_start, (void *)&dummy_code_end);

    // Configure Snooper to log only instrucitions executed in M mode
    set_register_bit(&__base_snprcfg, CFG_REGS_CTRL_REG_OFFSET,CFG_REGS_CTRL_M_MODE_BIT);

    // Set this bit to snoop from core 1 instead of core 0
    set_register_bit(&__base_snprcfg, CFG_REGS_CTRL_REG_OFFSET,CFG_REGS_CTRL_CORE_SELECT_BIT);

    // Configure Snooper Logging mode: Instr or Addr (default)
    // Instr mode to log all instructions opcodes
    // Addr mode to log PC src, PC dst and ctr_type of branches and jumps
    #ifdef INSTR
    set_register_bit(&__base_snprcfg, CFG_REGS_CTRL_REG_OFFSET,CFG_REGS_CTRL_TRACE_MODE_OFFSET);
    #endif

    //--------------------------------------TRIGGER INTERRUPT----------------------------------------//
    // This interrupt triggers when the snooper reads a committing instruction with PC=TRIGGER_PC0
    // The trigger interrupt resets the snooper ctrl register, this stops the snooper operation
    // allowing to read the execution trace without the risk of new instructions 
    // overwriting the instructions already stored in the buffer

    // Configure LSBs and MSBs of TRIGGER_PC0
    *reg32(&__base_snprcfg, CFG_REGS_TRIG_PC0_H_REG_OFFSET) = 0x00000000;
    *reg32(&__base_snprcfg, CFG_REGS_TRIG_PC0_L_REG_OFFSET) = (uint32_t)&dummy_code_end;
    // Enable trigger interrupt for PC0
    set_register_bit(&__base_snprcfg, CFG_REGS_CTRL_REG_OFFSET,CFG_REGS_CTRL_TRIG_PC_0_BIT);

    printf("[DBG] TRIG_PC0 set to %p (H=0x%08X L=0x%08X)\n", (void*)dummy_code_end, *reg32(&__base_snprcfg, CFG_REGS_TRIG_PC0_H_REG_OFFSET), *reg32(&__base_snprcfg, CFG_REGS_TRIG_PC0_L_REG_OFFSET));

    //-------------------------------------WATERMARK INTERRUPT---------------------------------------//
    // Watermark interrupt can only be used in instruction mode
    // This interrupt triggers when the numbers of instructions stored in the buffer minus
    // the number of instructions previously read through AXI is higher than the watermark lvl
    // The interrupt is high as long as this condition is met and does not stop the snooper operation

    #ifdef INSTR
    // Set watermark level to 10 instructions
    *reg32(&__base_snprcfg, CFG_REGS_WATERMARK_LEVEL_REG_OFFSET) = 0x0000000a; 
    // Enable watermark interrupt
    set_register_bit(&__base_snprcfg, CFG_REGS_CTRL_REG_OFFSET,CFG_REGS_CTRL_WATERMARK_EN_BIT);
    #endif

    

    // Enable RANGE_0 from CTRL register, this will enable the snooper to log the RANGE_0
    set_register_bit(&__base_snprcfg, CFG_REGS_CTRL_REG_OFFSET,CFG_REGS_CTRL_PC_RANGE_0_BIT);

    /* PRINT: current CTRL register value after all set_register_bit calls */
    printf("[DBG] CTRL reg after setup = 0x%08X\n", *reg32(&__base_snprcfg, CFG_REGS_CTRL_REG_OFFSET));

    fence();

    asm volatile ("dummy_code_start:");

    dummy_code();

    asm volatile ("dummy_code_end:");

    // Poll CTRL until RANGE_0 bit is cleared by the trigger (snooper stopped)
    // printf("[DBG] Waiting for snooper to stop (polling CTRL)...\n");
    // while (*reg32(&__base_snprcfg, CFG_REGS_CTRL_REG_OFFSET) & (1 << CFG_REGS_CTRL_PC_RANGE_0_BIT)) {
    //     // optional: small delay or NOP to avoid hammering the register bus
    //     // asm volatile("nop");
    // }
    // printf("[DBG] Snooper stopped by TRIG_PC0 (CTRL cleared)\n");


    int base, last;

    base = *reg32(&__base_snprcfg, CFG_REGS_BASE_REG_OFFSET);
    last = *reg32(&__base_snprcfg, CFG_REGS_LAST_REG_OFFSET);

    /* PRINT: show base/last that will be iterated */
    printf("[DBG] Snooper buffer base=0x%X last=0x%X\n", base, last);

    #ifndef INSTR
    for(int i=base;i<=last;i=i+20) { // Address mode
        *reg32(&__base_regs, CHESHIRE_SCRATCH_4_REG_OFFSET) = *reg32(&__base_snpr, i + 0x00); // read lsb 32bit of src PC
        *reg32(&__base_regs, CHESHIRE_SCRATCH_4_REG_OFFSET) = *reg32(&__base_snpr, i + 0x08); // read lsb 32bit of dst PC
        *reg32(&__base_regs, CHESHIRE_SCRATCH_4_REG_OFFSET) = *reg32(&__base_snpr, i + 0x10); // read ctr_type 32bit
        printf("Addr:%X PC_SRC:%X PC_DST:%X CTR_TYPE:%X\r\n", (uintptr_t)((uint8_t *)&__base_snpr + i), 
                                                                        *reg32(&__base_snpr, i + 0x00), 
                                                                        *reg32(&__base_snpr, i + 0x08), 
                                                                        *reg32(&__base_snpr, i + 0x10));
    }
    #else
    for(int i=base;i<=last;i=i+4) { // Instruction mode
        *reg32(&__base_regs, CHESHIRE_SCRATCH_4_REG_OFFSET) = *reg32(&__base_snpr, i); // read instr opcode 32bit
        printf("Addr:%X INSTR:%X\r\n", (uintptr_t)((uint8_t *)&__base_snpr + i), *reg32(&__base_snpr, i));
    }
    #endif
	
    printf("[DBG] done reading snooper buffer\n");

    return 0;
}
