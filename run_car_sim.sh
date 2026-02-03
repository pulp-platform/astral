#!/usr/bin/env bash

# Interrompe lo script se un comando fallisce
set -e

# Cartella di log
LOGDIR="logs"
mkdir -p "$LOGDIR"

# File di log con timestamp
LOGFILE="$LOGDIR/car_sim_$(date +%Y%m%d_%H%M%S).log"

# Redireziona stdout e stderr su file + terminale
exec > >(tee -a "$LOGFILE") 2>&1

echo "=== CAR simulation started at $(date) ==="
echo "Log file: $LOGFILE"
echo

#source env/env-chips.sh
make car-vsim-sim-clean
make car-all
make car-vsim-sim-build DEBUG=1
#make car-vsim-sim-build DEBUG=1 TBENCH=astral_wrap

# versione **vecchia** (originariamente usciva da vsim):
# make car-vsim-sim-run \
#   CHS_BINARY=./sw/tests/bare-metal/hostd/addressability_test.car.dram.elf \
#   DEBUG=1 \
#   CHS_PRELMODE=0

# versione **nuova** — usa DEBUG=live così non esce da vsim
make car-vsim-sim-run \
  CHS_BINARY=./sw/tests/bare-metal/hostd/addressability_test.car.dram.elf \
  DEBUG=live \
  CHS_PRELMODE=0

echo
echo "=== CAR simulation finished at $(date) ==="

