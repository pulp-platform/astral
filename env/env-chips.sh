# Set environment variables to choose of which island we have to compile the sw
export PULPD_PRESENT=1
export SAFED_PRESENT=0
export SECURED_PRESENT=1
export SPATZD_PRESENT=0

# set up environment variables for rtl simulation
ROOTD=$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")/.." && pwd)
export QUESTA=
export BENDER=bender
export PYTHON=python3
export PATH=/opt/riscv/riscv64-15.1.0/bin:$PATH # RV64 GCC toolchain
export PULPD_RISCV=/opt/riscv/pulp-gcc-1.0.16/bin/riscv32-unknown-elf
