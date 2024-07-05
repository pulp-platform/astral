// Copyright 2023 ETH Zurich and University of Bologna.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0
//
// Chaoqun Liang <chaoqun.liang@unibo.it>
// //
// Copyright 2023 ETH Zurich and University of Bologna.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0
//
// Chaoqun Liang <chaoqun.liang@unibo.it>

#include "car_memory_map.h"
#include "io.h"
#include "sw/device/lib/dif/dif_rv_plic.h"
#include "regs/system_timer.h"
#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include "params.h"
#include "printf.h"
#include "util.h"

static dif_rv_plic_t plic0;

#define IRQID 83 // index of ethernet irq in the irq vector input to the PLIC

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

#define DUMMY_TIMER_CNT_GOLDEN_MAX 2

#define DATA_CHUNK 8

#define BYTE_SIZE 8

#define L2_TX_BASE 0x78000000
#define L2_RX_BASE 0x78001000

int main(void) {

  // Put SMP Hart to sleep
  if (hart_id() != 0) wfi();

  int prio = 0x1;
  bool t;
  unsigned global_irq_en   = 0x00001808;
  unsigned external_irq_en = 0x00000800;

  asm volatile("csrw  mstatus, %0\n" : : "r"(global_irq_en  ));     // Set global interrupt enable in CVA6 csr
  asm volatile("csrw  mie, %0\n"     : : "r"(external_irq_en));     // Set external interrupt enable in CVA6 csr

  // PLIC setup
  mmio_region_t plic_base_addr = mmio_region_from_addr(&__base_plic);
  t = dif_rv_plic_init(plic_base_addr, &plic0);

  t = dif_rv_plic_irq_set_priority(&plic0, IRQID, prio);
  t = dif_rv_plic_irq_set_enabled(&plic0, IRQID, 0, kDifToggleEnabled);

  volatile uint64_t data_to_write[DATA_CHUNK] = {
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
  for (int i = 0; i < DATA_CHUNK; ++i) {
        volatile uint64_t *tx_addr = (volatile uint64_t*)(L2_TX_BASE + i * sizeof(uint64_t));
        *tx_addr = data_to_write[i];
  }

  fencei();
  //// TX test
  // Low 32 bit MAC Address
  *reg32(CAR_ETHERNET_BASE_ADDR, MACLO_OFFSET)          = 0x98001032;
  // High 16 bit Mac Address
  *reg32(CAR_ETHERNET_BASE_ADDR, MACHI_OFFSET)          = 0x00002070;
  // DMA Source Address
  *reg32(CAR_ETHERNET_BASE_ADDR, IDMA_SRC_ADDR_OFFSET)  = L2_TX_BASE;
  // DMA Destination Address
  *reg32(CAR_ETHERNET_BASE_ADDR, IDMA_DST_ADDR_OFFSET)  = 0x0;
  // Data length
  *reg32(CAR_ETHERNET_BASE_ADDR, IDMA_LENGTH_OFFSET)    = DATA_CHUNK*BYTE_SIZE;
  // Source Protocol
  *reg32(CAR_ETHERNET_BASE_ADDR, IDMA_SRC_PROTO_OFFSET) = 0x0;
  // Destination Protocol
  *reg32(CAR_ETHERNET_BASE_ADDR, IDMA_DST_PROTO_OFFSET) = 0x5;

  // while (!(*reg32(CAR_ETHERNET_BASE_ADDR,IDMA_REQ_READY_OFFSET)));
  // Validate Request to DMA
  *reg32(CAR_ETHERNET_BASE_ADDR, IDMA_REQ_VALID_OFFSET) = 0x1;
  // Stop accepting new request
  //*reg32(CAR_ETHERNET_BASE_ADDR, IDMA_REQ_VALID_OFFSET) = 0x0;
  // for (volatile int i = 0; i < 10; i++)
  // ;
  //*reg32(CAR_ETHERNET_BASE_ADDR, IDMA_RSP_READY_OFFSET) = 0x1; //}

  wfi();  // rx irq

  // RX test
   // Low 32 bit MAC Address
  *reg32(CAR_ETHERNET_BASE_ADDR, MACLO_OFFSET)          = 0x98001032;
  // High 16 bit Mac Address
  *reg32(CAR_ETHERNET_BASE_ADDR, MACHI_OFFSET)          = 0x00002070;
  // DMA Source Address
  *reg32(CAR_ETHERNET_BASE_ADDR, IDMA_SRC_ADDR_OFFSET)  = 0x0;
  // DMA Destination Address
  *reg32(CAR_ETHERNET_BASE_ADDR, IDMA_DST_ADDR_OFFSET)  = L2_RX_BASE;
  // Data length
  *reg32(CAR_ETHERNET_BASE_ADDR, IDMA_LENGTH_OFFSET)    = DATA_CHUNK*BYTE_SIZE;
  // Source Protocol
  *reg32(CAR_ETHERNET_BASE_ADDR, IDMA_SRC_PROTO_OFFSET) = 0x5;
  // Destination Protocol
  *reg32(CAR_ETHERNET_BASE_ADDR, IDMA_DST_PROTO_OFFSET) = 0x0;

  // while (!(*reg32(CAR_ETHERNET_BASE_ADDR,IDMA_REQ_READY_OFFSET)));
  // Validate Request to DMA
  *reg32(CAR_ETHERNET_BASE_ADDR, IDMA_REQ_VALID_OFFSET) = 0x1;

  while (!(*reg32(CAR_ETHERNET_BASE_ADDR, IDMA_RSP_VALID_OFFSET)));

  uint32_t error = 0;

  for (int i = 0; i < DATA_CHUNK; ++i) {
    volatile uint64_t *rx_addr = (volatile uint64_t*)(L2_RX_BASE + i * sizeof(uint64_t));
    uint64_t data_read = *rx_addr;

    if (data_read != data_to_write[i]) error ++;
  }

  return error;
}

void trap_vector (void){
   int * claim_irq;
   dif_rv_plic_irq_claim(&plic0, 0, &claim_irq);
   dif_rv_plic_irq_complete(&plic0, 0, &claim_irq);
   return;
}
