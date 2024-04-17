// Copyright 2023 ETH Zurich and University of Bologna.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0
//
// Yvan Tortorella <yvan.tortorella@unibo.it>
//
// Streamer access test.

#include "car_util.h"
#include "printf.h"
#include "hmr.h"

int main(void) {

  // Hart 0 enters first
  if (hart_id() != 0) wfi();

  printf("0x%x\n", TCTM_STREAMER_APB_TM_PACKET_BASE);

  writew(0x1, TCTM_STREAMER_APB_TM_PACKET_BASE);
  writew(0x1, TCTM_STREAMER_CFG_MAP_ROUTER_BASE);

  printf("Done\n");

  return 0;
}
