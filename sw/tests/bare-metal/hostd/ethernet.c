// Copyright 2023 ETH Zurich and University of Bologna.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0
//
// Chaoqun Liang <chaoqun.liang@unibo.it>
//
#include "car_memory_map.h"
#include "io.h"
#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include "printf.h"
#include "params.h"
#include "util.h"

#define MACLO_OFFSET                 0x0
#define MACHI_OFFSET                 0x4
#define IRQ_OFFSET                   0x10
#define IDMA_SRC_ADDR_OFFSET         0x14
#define IDMA_DST_ADDR_OFFSET         0x18
#define IDMA_LENGTH_OFFSET           0x1c
#define IDMA_SRC_PROTO_OFFSET        0x20
#define IDMA_DST_PROTO_OFFSET        0x24
#define IDMA_REQ_VALID_OFFSET        0x3c
#define IDMA_REQ_READY_OFFSET        0x40
#define IDMA_RSP_READY_OFFSET        0x44
#define IDMA_RSP_VALID_OFFSET        0x48

#define RV_PLIC_PRIO83_REG_OFFSET    0x14c
#define RV_PLIC_IE0_2_REG_OFFSET     0x2008
#define RV_PLIC_IE0_2_E_83_BIT       19
#define RV_PLIC_IP_2_REG_OFFSET      0x1008

//#define PRINTF_ON

int main(void) {

  // Put SMP Hart to sleep
  if (hart_id() != 0) wfi();

  // PLIC Setup
 *reg32(&__base_plic, RV_PLIC_PRIO83_REG_OFFSET) = 1;
 *reg32(&__base_plic, RV_PLIC_IE0_2_REG_OFFSET)  |= (1 << (RV_PLIC_IE0_2_E_83_BIT)); // Enable interrupt number ;

  volatile uint64_t data_to_write[8] = {
        0x1032207098001032,
        0x3210E20020709800,
        0x1716151413121110,
        0x2726252423222120,
        0x3736353433323130,
        0x4746454443424140,
        0x5756555453525150,
        0x6766656463626160
  };

  // load data into mem
  for (int i = 0; i < 8; ++i) {
        volatile uint64_t *tx_addr = (volatile uint64_t*)(&__base_dram + i * sizeof(uint64_t));
        *tx_addr = data_to_write[i];
  }

  // Low 32 bit MAC Address
  *reg32(CAR_ETHERNET_BASE_ADDR, MACLO_OFFSET)          = 0x98001032;
  // High 16 bit Mac Address
  *reg32(CAR_ETHERNET_BASE_ADDR, MACHI_OFFSET)          = 0x00002070;
  // DMA Source Address
  *reg32(CAR_ETHERNET_BASE_ADDR, IDMA_SRC_ADDR_OFFSET)  = &__base_dram;
  // DMA Destination Address
  *reg32(CAR_ETHERNET_BASE_ADDR, IDMA_DST_ADDR_OFFSET)  = 0x0;
  // Data length
  *reg32(CAR_ETHERNET_BASE_ADDR, IDMA_LENGTH_OFFSET)    = 0x40;
  // Source Protocol
  *reg32(CAR_ETHERNET_BASE_ADDR, IDMA_SRC_PROTO_OFFSET) = 0x0;
  // Destination Protocol
  *reg32(CAR_ETHERNET_BASE_ADDR, IDMA_DST_PROTO_OFFSET) = 0x5;
  // Validate Request to DMA
  *reg32(CAR_ETHERNET_BASE_ADDR, IDMA_REQ_VALID_OFFSET) = 0x1;
  // Stop accepting new request
  *reg32(CAR_ETHERNET_BASE_ADDR, IDMA_REQ_VALID_OFFSET) = 0x0;
  // Enable DMA to move data
  *reg32(CAR_ETHERNET_BASE_ADDR, IDMA_RSP_READY_OFFSET) = 0x1;
  // Interrupt polling
  while (!((*reg32(&__base_plic, RV_PLIC_IP_2_REG_OFFSET)) & (1 << RV_PLIC_IE0_2_E_83_BIT)));

  printf ("Ethernet test pass...\n\r");

  return 0;
}

