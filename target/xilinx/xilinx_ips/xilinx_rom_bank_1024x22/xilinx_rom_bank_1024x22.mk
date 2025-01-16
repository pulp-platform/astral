# Copyright 2024 ETH Zurich and University of Bologna.
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0

ROOT_xilinx_rom_bank_1024x22              := $(CAR_XIL_DIR)/xilinx_ips/xilinx_rom_bank_1024x22
ARTIFACTS_FILES_xilinx_rom_bank_1024x22   := xilinx_rom_bank_1024x22.mk tcl/run.tcl
ARTIFACTS_VARS_xilinx_rom_bank_1024x22    := xilinx_part XILINX_BOARD xilinx_board_long
XILINX_USE_ARTIFACTS_xilinx_rom_bank_1024x22 := 1
