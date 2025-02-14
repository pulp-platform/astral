// Copyright 2023 ETH Zurich and University of Bologna.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0
//
// Yvan Tortorella <yvan.tortorella@unibo.it>
//

#include "car_memory_map.h"
#include "io.h"
#include "dif/clint.h"
#include "dif/uart.h"
#include "params.h"
#include "regs/cheshire.h"
#include "regs/system_timer.h"
#include "util.h"
#include "car_util.h"
#include "printf.h"

// In order to test the timer functionality, we reprogram the timer to do
// consecutively the same count, and compare the result. We set the number
// of runs to 4 so that the core can warm up the caches during the first two
// iterations, and use the last 2 to compare the results. An empyrical analysis
// shows that, in case of 500 rounds, the difference between two consecutive
// reads is around 2% with no cache warmup, and drops under 1% with a single
// cache warmup. In case of 250 rounds, with no cache warmup the difference is 4%.

#define Runs 4
#define Rounds 500

int main(void) {

    // Put SMP Hart to sleep

    volatile int time [Runs];

    for (int i = 0; i < Runs; i++) {
      // Reset system timer
      writed(1, CAR_SYSTEM_TIMER_BASE_ADDR + TIMER_RESET_LO_OFFSET);
      // Start system timer
      writed(1, CAR_SYSTEM_TIMER_BASE_ADDR + TIMER_START_LO_OFFSET);

      for (volatile int i = 0; i < Rounds; i++)
	  ;
      fencei();

      // Stop system timer
      writed(0, CAR_SYSTEM_TIMER_BASE_ADDR + TIMER_CFG_LO_OFFSET);
      // Get system timer count
      time[i] = readd(CAR_SYSTEM_TIMER_BASE_ADDR + TIMER_CNT_LO_OFFSET);
    }

    // Extract the minimum value read from the timer and compute the difference
    volatile int min, max;

    if (time[Runs-2] < time[Runs-1]) {
      min = time[Runs-2];
      max = time[Runs-1];
    } else {
      min = time[Runs-1];
      max = time[Runs-2];
    }

    float diff = 100*(max - min)/min;

    return (diff > 1.0);
}
