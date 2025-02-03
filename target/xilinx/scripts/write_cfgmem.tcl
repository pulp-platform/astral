# Copyright 2018 ETH Zurich and University of Bologna.
# Solderpad Hardware License, Version 0.51, see LICENSE for details.
# SPDX-License-Identifier: SHL-0.51
#
# Description: Generate a memory configuration file from a bitstream

set file $::env(FILE)
set offset $::env(OFFSET)
set mcs_file $::env(IMAGE)

# Create flash configuration file
if {$::env(XILINX_BOARD) eq "vcu118"} {
  write_cfgmem -force -format mcs -size 128 -interface SPIx4 \
  -loaddata "up $offset $file" \
  -checksum \
  -file target/xilinx/out/${mcs_file}_x4.mcs
} else {
  write_cfgmem -force -format mcs -size 128 -interface SPIx1 \
  -loaddata "up $offset $file" \
  -checksum \
  -file target/xilinx/out/$mcs_file.mcs
}
