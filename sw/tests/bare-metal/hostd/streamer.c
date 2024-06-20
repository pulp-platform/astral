// Copyright 2023 ETH Zurich and University of Bologna.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0
//
// Yvan Tortorella <yvan.tortorella@unibo.it>
//
// Streamer access test.

#include "car_util.h"
#include "car_params.h"
#include "regs/soc_ctrl.h"
#include "printf.h"

#define PTME_ENABLE_ADDR (TCTM_STREAMER_CFG_PTME_BASE + 0x04)
#define PTME_VIRT_CHANNELA_CFG_ADDR (TCTM_STREAMER_CFG_PTME_BASE + 0x10)
#define PTME_VIRT_CHANNELB_CFG_ADDR (TCTM_STREAMER_CFG_PTME_BASE + 0x14)
#define TM_FRAME_ADDR (TCTM_STREAMER_CFG_PTME_BASE + 0x48)
#define PTME_ENCODING_CFG_ADDR (TCTM_STREAMER_CFG_PTME_BASE + 0x60)
#define PTME_CLK_PRESCALER_ADDR (TCTM_STREAMER_CFG_PTME_BASE + 0x68)
#define BIT_CLK_DIVISOR_ADDR (TCTM_STREAMER_CFG_PTME_BASE + 0x6C)
#define TME_INIT_ADDR (TCTM_STREAMER_CFG_PTME_BASE + 0x00)

#define PTME_ENABLE_VALUE 0x00010000
#define TM_FRAME_CFG_VALUE 0x3FFE0020
#define PTME_CLK_PRESCALE_VALUE 0x00000000
#define BIT_CLK_DIVISOR_VALUE 0x00000000
#define TME_INIT_VALUE 0x0000AAAA
#define PTME_ACTIVATE_VALUE 0x00000008
#define PTME_DEACTIVATE_VALUE 0x00000000
#define PTME_ENCODING_CFG_VALUE 0x2

#define PTME_ENABLE_RETURN_VALUE 0x00010001
#define PTME_VIRT_CHANNELA_CFG_VALUE 0x21
#define PTME_VIRT_CHANNELB_CFG_VALUE 0x31

int main(void) {

  if (hart_id() != 0) wfi();

  // Update clock divider value and re-enable streamer clock divider
  writew(10, car_soc_ctrl + CARFIELD_STREAMER_CLK_DIV_VALUE_REG_OFFSET);
  writew(0x1, car_soc_ctrl + CARFIELD_STREAMER_CLK_DIV_ENABLE_REG_OFFSET);

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

  // Start reading TC buffer
  for (int i = 0; i < 4; i++)
    readb(TCTM_STREAMER_APB_TC_BUFFER_BASE + i);

  // Write HPC LLC
  for (int i = 0; i < 4; i++)
    writeb(i, TCTM_STREAMER_APB_TX_BUFFER_BASE + i);

  // Configure telemetry frame
  writew(TM_FRAME_CFG_VALUE, TM_FRAME_ADDR);

  writew(PTME_ENCODING_CFG_VALUE, PTME_ENCODING_CFG_ADDR);

  writew(PTME_VIRT_CHANNELA_CFG_VALUE, PTME_VIRT_CHANNELA_CFG_ADDR);

  writew(PTME_VIRT_CHANNELB_CFG_VALUE, PTME_VIRT_CHANNELB_CFG_ADDR);

  // Set PTME clock pre-scaler
  writew(PTME_CLK_PRESCALE_VALUE, PTME_CLK_PRESCALER_ADDR);
  // Set bit clock divisor
  writew(BIT_CLK_DIVISOR_VALUE, BIT_CLK_DIVISOR_ADDR);
  // TME_INIT (?)
  writew(TME_INIT_VALUE, TME_INIT_ADDR);
  // Enable PTME
  writew(PTME_ENABLE_VALUE, PTME_ENABLE_ADDR);

  // Check the written registers for errors
  error += (readw(PTME_ENABLE_ADDR) != PTME_ENABLE_RETURN_VALUE);
  error += (readw(TM_FRAME_ADDR) != TM_FRAME_CFG_VALUE);
  error += (readw(PTME_CLK_PRESCALER_ADDR) != PTME_CLK_PRESCALE_VALUE);
  error += (readw(BIT_CLK_DIVISOR_ADDR) != BIT_CLK_DIVISOR_VALUE);
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

  while(1);
  // return error;
}
