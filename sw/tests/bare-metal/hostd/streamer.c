// Copyright 2023 ETH Zurich and University of Bologna.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0
//
// Yvan Tortorella <yvan.tortorella@unibo.it>
//
// Streamer access test.

#include "car_util.h"
#include "printf.h"

#define PTME_ENABLE_ADDR (TCTM_STREAMER_CFG_PTME_BASE + 0x04)
#define TM_FRAME_ADDR (TCTM_STREAMER_CFG_PTME_BASE + 0x48)
#define PTME_CLK_PRESCALER_ADDR (TCTM_STREAMER_CFG_PTME_BASE + 0x68)
#define BIT_CLK_DIVISOR_ADDR (TCTM_STREAMER_CFG_PTME_BASE + 0x6C)
#define TME_INIT_ADDR (TCTM_STREAMER_CFG_PTME_BASE + 0x00)

#define PTME_ENABLE_VALUE 0x00010000
#define TM_FRAM_CFG_VALUE 0xFFFA0020
#define PTME_CLK_PRESCALE_VALUE 0x00000000
#define BIT_CLK_DIVISOR_VALUE 0x00000000
#define TME_INIT_VALUE 0x0000AAAA
#define PTME_ACTIVATE_VALUE 0x00000008
#define PTME_DEACTIVATE_VALUE 0x00000000

int main(void) {

  if (hart_id() != 0) wfi();

  uint32_t error = 0;

  const char packet[] = { 0x09, 0x4C, 0xD2, 0x35,
                          0x00, 0x1F, 0xAF, 0x01,
                          0x00, 0x00, 0xAF, 0x02,
                          0x00, 0x01, 0xAF, 0x03,
                          0x00, 0x02, 0xAF, 0x04,
                          0x00, 0x03, 0xAF, 0x05,
                          0x00, 0x04, 0xAF, 0x06,
                          0x00, 0x05, 0xAF, 0x07,
                          0x00, 0x06, 0xAF, 0x08,
                          0x00, 0x07 };

  // Enable PTME
  writew(PTME_ENABLE_VALUE, PTME_ENABLE_ADDR);
  error += (readw(PTME_ENABLE_ADDR) != PTME_ENABLE_VALUE);
  // Configure telemetry frame
  writew(TM_FRAM_CFG_VALUE, TM_FRAME_ADDR);
  error += (readw(PTME_ENABLE_ADDR) != TM_FRAM_CFG_VALUE);
  // Set PTME clock pre-scaler
  writew(PTME_CLK_PRESCALE_VALUE, PTME_CLK_PRESCALER_ADDR);
  error += (readw(PTME_CLK_PRESCALER_ADDR) != PTME_CLK_PRESCALE_VALUE);
  // Set bit clock divisor
  writew(BIT_CLK_DIVISOR_VALUE, BIT_CLK_DIVISOR_ADDR);
  error += (readw(BIT_CLK_DIVISOR_ADDR) != BIT_CLK_DIVISOR_VALUE);
  // TME_INIT (?)
  writew(TME_INIT_VALUE, TME_INIT_ADDR);
  error += (readw(TME_INIT_ADDR) != TME_INIT_VALUE);

  // Manifest interest in sending data (specifying only LSB is meaningful)
  writew(PTME_ACTIVATE_VALUE, TCTM_STREAMER_APB_PTME_CFG + 0x00);

  // Push data into the TM buffer
  for (int i = 0; i < sizeof(packet); i++)
    writew(packet[i], TCTM_STREAMER_APB_TM_PACKET_BASE + 0x04*i);

  // Disable ACTIVE signal to start the transmission
  writew(PTME_DEACTIVATE_VALUE, TCTM_STREAMER_APB_PTME_CFG);

  // TODO: Should we wait for an event or something here?
  if (error == 0) printf("Success!\n");
  else printf("Failed!\n");

  return error;
}
