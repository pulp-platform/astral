// Copyright 2024 ETH Zurich and University of Bologna.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0
//
#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include "util.h"
#include "io.h"
#include "printf.h"
#include "car_memory_map.h"

#define SRC_ADDR           0x14000000
#define DST_ADDR           0x14003000

#define IDMA_SRC_ADDR_OFFSET         0x000000d8
#define IDMA_DST_ADDR_OFFSET         0x000000d0
#define IDMA_LENGTH_OFFSET           0x000000e0
#define IDMA_NEXT_ID_OFFSET          0x00000044
#define IDMA_REPS_2                  0x000000f8
#define IDMA_CONF                    0x00000000

int main() {

    if (hart_id() != 0) wfi();

    printf("Testing iDMA\r\n");

    volatile int *ptr;
    int error = 0;

    // load data into src address
    for (int64_t i = 0; i < 32; i++)
      writed(i,SRC_ADDR + i*8);

    ptr = (int *)(IDMA_BASE + IDMA_SRC_ADDR_OFFSET);
    *ptr = SRC_ADDR;
    ptr = (int *)(IDMA_BASE + IDMA_DST_ADDR_OFFSET);
    *ptr = DST_ADDR;
    ptr = (int *)(IDMA_BASE + IDMA_LENGTH_OFFSET);
    *ptr = 0x00000100;
    ptr = (int *)(IDMA_BASE + IDMA_CONF);
    *ptr = 0x3 << 10;
    ptr = (int *)(IDMA_BASE + IDMA_REPS_2);
    *ptr = 0x00000001;
    ptr = (int *)(IDMA_BASE + IDMA_NEXT_ID_OFFSET);
    int id = *ptr;  // Read IDMA next ID

	  for (uint64_t i = 0; i < 32; i++)
	    if (readd(DST_ADDR+i*8) != i)
        error++;

    if(error!=0){
       printf("Test failed\r\n");
    } else {
       printf("Test succeed\r\n");
    }

    return error;
}
