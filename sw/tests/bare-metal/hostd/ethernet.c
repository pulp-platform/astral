// Copyright 2024 ETH Zurich and University of Bologna.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0
//
// Chaoqun Liang <chaoqun.liang@unibo.it>
//

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
#include "padframe.h"
#include "fll.h"

static dif_rv_plic_t plic0;

#define IRQID 87 // index of ethernet irq in the irq vector input to the PLIC

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

#define RV_PLIC_PRIO87_REG_OFFSET    0x15c
#define RV_PLIC_IE0_2_REG_OFFSET     0x2008
#define RV_PLIC_IE0_2_E_87_BIT       23
#define RV_PLIC_IP_2_REG_OFFSET      0x1008

#define DUMMY_TIMER_CNT_GOLDEN_MAX 2

#define DATA_CHUNK 8

#define BYTE_SIZE 8

#define L2_TX_BASE 0x78000000
#define L2_RX_BASE 0x78001000

#define FLL_WAIT_CYCLES 10000

int main(void) {

  // Put SMP Hart to sleep
  if (hart_id() != 0) wfi();

  // Configuring padframe - mux
  write_padframe_mux(PADFRAME_CONFIG_MUXED_V_07_MUX_SEL, PADFRAME_MUXED_V_07_SEL_ETHERNET_RXCK);
  write_padframe_mux(PADFRAME_CONFIG_MUXED_V_08_MUX_SEL, PADFRAME_MUXED_V_08_SEL_ETHERNET_RXCTL);
  write_padframe_mux(PADFRAME_CONFIG_MUXED_V_09_MUX_SEL, PADFRAME_MUXED_V_09_SEL_ETHERNET_RXD_0);
  write_padframe_mux(PADFRAME_CONFIG_MUXED_V_10_MUX_SEL, PADFRAME_MUXED_V_10_SEL_ETHERNET_RXD_1);
  write_padframe_mux(PADFRAME_CONFIG_MUXED_V_11_MUX_SEL, PADFRAME_MUXED_V_11_SEL_ETHERNET_RXD_2);
  write_padframe_mux(PADFRAME_CONFIG_MUXED_V_12_MUX_SEL, PADFRAME_MUXED_V_12_SEL_ETHERNET_RXD_3);
  write_padframe_mux(PADFRAME_CONFIG_MUXED_V_13_MUX_SEL, PADFRAME_MUXED_V_13_SEL_ETHERNET_TXCK);
  write_padframe_mux(PADFRAME_CONFIG_MUXED_V_14_MUX_SEL, PADFRAME_MUXED_V_14_SEL_ETHERNET_TXCTL);
  write_padframe_mux(PADFRAME_CONFIG_MUXED_V_15_MUX_SEL, PADFRAME_MUXED_V_15_SEL_ETHERNET_TXD_0);
  write_padframe_mux(PADFRAME_CONFIG_MUXED_V_16_MUX_SEL, PADFRAME_MUXED_V_16_SEL_ETHERNET_TXD_1);
  write_padframe_mux(PADFRAME_CONFIG_MUXED_V_17_MUX_SEL, PADFRAME_MUXED_V_17_SEL_ETHERNET_TXD_2);
  write_padframe_mux(PADFRAME_CONFIG_MUXED_H_00_MUX_SEL, PADFRAME_MUXED_H_00_SEL_ETHERNET_TXD_3);
  write_padframe_mux(PADFRAME_CONFIG_MUXED_H_01_MUX_SEL, PADFRAME_MUXED_H_01_SEL_ETHERNET_MD);
  write_padframe_mux(PADFRAME_CONFIG_MUXED_H_02_MUX_SEL, PADFRAME_MUXED_H_02_SEL_ETHERNET_MDC);
  write_padframe_mux(PADFRAME_CONFIG_MUXED_H_03_MUX_SEL, PADFRAME_MUXED_H_03_SEL_ETHERNET_RST_N);
  // Configuring padframe - pullup
  write_padframe_pen(PADFRAME_CONFIG_MUXED_V_07_CFG, 0x1); write_padframe_psel(PADFRAME_CONFIG_MUXED_V_07_CFG, 0x1);
  write_padframe_pen(PADFRAME_CONFIG_MUXED_V_08_CFG, 0x1); write_padframe_psel(PADFRAME_CONFIG_MUXED_V_08_CFG, 0x1);
  write_padframe_pen(PADFRAME_CONFIG_MUXED_V_09_CFG, 0x1); write_padframe_psel(PADFRAME_CONFIG_MUXED_V_09_CFG, 0x1);
  write_padframe_pen(PADFRAME_CONFIG_MUXED_V_10_CFG, 0x1); write_padframe_psel(PADFRAME_CONFIG_MUXED_V_10_CFG, 0x1);
  write_padframe_pen(PADFRAME_CONFIG_MUXED_V_11_CFG, 0x1); write_padframe_psel(PADFRAME_CONFIG_MUXED_V_11_CFG, 0x1);
  write_padframe_pen(PADFRAME_CONFIG_MUXED_V_12_CFG, 0x1); write_padframe_psel(PADFRAME_CONFIG_MUXED_V_12_CFG, 0x1);
  write_padframe_pen(PADFRAME_CONFIG_MUXED_V_13_CFG, 0x1); write_padframe_psel(PADFRAME_CONFIG_MUXED_V_13_CFG, 0x1);
  write_padframe_pen(PADFRAME_CONFIG_MUXED_V_14_CFG, 0x1); write_padframe_psel(PADFRAME_CONFIG_MUXED_V_14_CFG, 0x1);
  write_padframe_pen(PADFRAME_CONFIG_MUXED_V_15_CFG, 0x1); write_padframe_psel(PADFRAME_CONFIG_MUXED_V_15_CFG, 0x1);
  write_padframe_pen(PADFRAME_CONFIG_MUXED_V_16_CFG, 0x1); write_padframe_psel(PADFRAME_CONFIG_MUXED_V_16_CFG, 0x1);
  write_padframe_pen(PADFRAME_CONFIG_MUXED_V_17_CFG, 0x1); write_padframe_psel(PADFRAME_CONFIG_MUXED_V_17_CFG, 0x1);
  write_padframe_pen(PADFRAME_CONFIG_MUXED_H_00_CFG, 0x1); write_padframe_psel(PADFRAME_CONFIG_MUXED_H_00_CFG, 0x1);
  write_padframe_pen(PADFRAME_CONFIG_MUXED_H_01_CFG, 0x1); write_padframe_psel(PADFRAME_CONFIG_MUXED_H_01_CFG, 0x1);
  write_padframe_pen(PADFRAME_CONFIG_MUXED_H_02_CFG, 0x1); write_padframe_psel(PADFRAME_CONFIG_MUXED_H_02_CFG, 0x1);
  write_padframe_pen(PADFRAME_CONFIG_MUXED_H_03_CFG, 0x1); write_padframe_psel(PADFRAME_CONFIG_MUXED_H_03_CFG, 0x1);

  // Configuring FLL
  fll_normal(FLL_PERIPH_ID);
  set_fll_clk_mul(0x3E7, FLL_PERIPH_ID);
  set_fll_clk_div(0x2, FLL_PERIPH_ID);

  // Wait for FLL clk out to stabilize
  for (int i = 0; i < FLL_WAIT_CYCLES; i++)
    asm volatile("addi x0, x0, 0" ::);

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
  *reg32(CAR_ETHERNET_BASE_ADDR, IDMA_DST_ADDR_OFFSET)  = 0x14000000;
  // Data length
  *reg32(CAR_ETHERNET_BASE_ADDR, IDMA_LENGTH_OFFSET)    = DATA_CHUNK*BYTE_SIZE;
  // Source Protocol
  *reg32(CAR_ETHERNET_BASE_ADDR, IDMA_SRC_PROTO_OFFSET) = 0x5;
  // Destination Protocol
  *reg32(CAR_ETHERNET_BASE_ADDR, IDMA_DST_PROTO_OFFSET) = 0x5;

  // Validate Request to DMA
  *reg32(CAR_ETHERNET_BASE_ADDR, IDMA_REQ_VALID_OFFSET) = 0x1;
  
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
  
  // Validate Request to DMA
  *reg32(CAR_ETHERNET_BASE_ADDR, IDMA_REQ_VALID_OFFSET) = 0x1;
  
  // wait until DMA moves all data
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
