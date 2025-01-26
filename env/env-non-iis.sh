# Copyright 2022 ETH Zurich and University of Bologna.
# Solderpad Hardware License, Version 0.51, see LICENSE for details.
# SPDX-License-Identifier: SHL-0.51
#

# Set environment variables to choose of which island we have to compile the sw
export PULPD_PRESENT=1
export SAFED_PRESENT=0
export SECURED_PRESENT=1
export SPATZD_PRESENT=0

if [ -z "${BENDER}" ]; then
    echo "Environment variable 'BENDER' is not set."
fi

if ! which "riscv64-unknown-elf-gcc" >/dev/null 2>&1; then
  echo "RISCV64 toolchain is NOT in the PATH."
fi

if ! which "riscv32-unknown-elf-gcc" >/dev/null 2>&1; then
  echo "RISCV32 toolchain is NOT in the PATH."
fi

if ! which "vivado" >/dev/null 2>&1; then
  echo "Vivado is NOT in the PATH."
fi

if ! which "vsim" >/dev/null 2>&1; then
  echo "QuestaSim is NOT in the PATH."
fi
