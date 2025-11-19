// Copyright 2023 ETH Zurich and University of Bologna.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0
//
// Nicole Narr <narrn@student.ethz.ch>
// Christopher Reinwardt <creinwar@student.ethz.ch>
//
// Simple payload to test bootmodes

#include "car_util.h"
#include "printf.h"

int main(void) {

    // Put SMP Hart to sleep
    // if (hart_id() != 0) wfi();

    // Init the HW (this also includes UART)
    car_init_start();

    printf("Hi!\n");

    return 0;
}
