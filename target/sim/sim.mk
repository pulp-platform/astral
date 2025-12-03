# Copyright 2024 ETH Zurich and University of Bologna.
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0
#
# Alessandro Ottaviano <aottaviano@iis.ee.ethz.ch>

## @section Carfield platform simulation

QUESTA ?= questa-2023.4
TBENCH ?= tb_astral

## Get HyperRAM verification IP (VIP) for simulation
$(CAR_TGT_DIR)/sim/src/hyp_vip:
	rm -rf $@
	cp -r /scratch/share/hyp_vip $@

CAR_SIM_ALL += $(CHS_ROOT)/target/sim/models/s25fs512s.v
CAR_SIM_ALL += $(CHS_ROOT)/target/sim/models/24FC1025.v
CAR_SIM_ALL += $(CAR_TGT_DIR)/sim/src/hyp_vip

# Defines for hyperram model preload at time 0
HYP_USER_PRELOAD      ?= 0
HYP0_PRELOAD_MEM_FILE ?= ""
HYP1_PRELOAD_MEM_FILE ?= ""

RUNTIME_DEFINES := +define+HYP_USER_PRELOAD="$(HYP_USER_PRELOAD)"
RUNTIME_DEFINES += +define+HYP0_PRELOAD_MEM_FILE=\"$(HYP0_PRELOAD_MEM_FILE)\"
RUNTIME_DEFINES += +define+HYP1_PRELOAD_MEM_FILE=\"$(HYP1_PRELOAD_MEM_FILE)\"
RUNTIME_DEFINES += -timescale \"1 ns / 1 ps\"

#############
# Questasim #
#############

## @section Questasim simulator target

QUESTA_FLAGS += -suppress 3999 -suppress 12088 +UVM_NO_RELNOTES

ifdef DEBUG
	VOPT_FLAGS := -debug +designfile $(QUESTA_FLAGS)
ifeq ($(DEBUG),live)
	VSIM_FLAGS := -qwavedb=+signal+memory $(QUESTA_FLAGS)
	RUN_AND_EXIT := run -all
else
	VSIM_FLAGS := -qwavedb=+signal+memory $(QUESTA_FLAGS) -c
	RUN_AND_EXIT := run -all; exit;
	POST_SIM := qsim $(CAR_TGT_DIR)/sim/vsim/qwave.db $(CAR_TGT_DIR)/sim/vsim/design.bin
endif
else
	VOPT_FLAGS := $(QUESTA_FLAGS)
	VSIM_FLAGS := $(QUESTA_FLAGS) -c
	RUN_AND_EXIT := run -all; exit;
endif

.PHONY: $(CAR_VSIM_DIR)/compile.carfield_soc.tcl
$(CAR_VSIM_DIR)/compile.carfield_soc.tcl:
	mkdir -p $(CAR_VSIM_DIR)
	$(BENDER) script vsim $(common_targs) $(sim_targs) $(sim_defs) $(common_defs) $(safed_defs) --vlog-arg="$(RUNTIME_DEFINES)" --compilation-mode separate > $@
	echo 'vlog "$(CHS_ROOT)/target/sim/src/elfloader.cpp" -ccflags "-std=c++11"' >> $@
	echo 'qopt $(VOPT_FLAGS) $(TBENCH) -o $(TBENCH)_opt' >> $@

CAR_VSIM_ALL += $(CAR_SIM_ALL)
CAR_VSIM_ALL += $(CAR_VSIM_DIR)/compile.carfield_soc.tcl

## Generate all required VIPs (SPI flash, I2c EEPROm, HyperRAM, etc) and compilation scripts for Questasim
.PHONY: car-vsim-sim-init
car-vsim-sim-init: $(CAR_VSIM_ALL)

## Compile Carfield HW using Questasim. Run `make car-sim-init` from the root directory to prepare
## the simulation environment before running this command.
.PHONY: car-vsim-sim-build
car-vsim-sim-build: $(CAR_VSIM_DIR)/compile.carfield_soc.tcl
	cd $(CAR_VSIM_DIR); $(QUESTA) qsim -c -do "quit -code [source $<]"

.PHONY: car-vsim-sim-clean
## Remove all Questasim simulation build artifacts
car-vsim-sim-clean:
	rm -rf $(CAR_VSIM_DIR)/uart $(CAR_VSIM_DIR)/FETCH* $(CAR_VSIM_DIR)/logs $(CAR_VSIM_DIR)/*.ini $(CAR_VSIM_DIR)/trace* $(CAR_VSIM_DIR)/*.wlf $(CAR_VSIM_DIR)/transcript $(CAR_VSIM_DIR)/work $(CAR_VSIM_DIR)/*lib $(CAR_VSIM_DIR)/*Lib $(CAR_VSIM_DIR)/*.vstf $(CAR_VSIM_DIR)/*.log $(CAR_VSIM_DIR)/*.txt $(CAR_TGT_DIR)/sim/vsim/qwave.db $(CAR_TGT_DIR)/sim/vsim/design.bin

.PHONY: car-vsim-sim-run
## Run simulation of the carfield RTL.
## @param HYP_USER_PRELOAD=0 Whether to preload code in the HyperRAM model.
## @param CHS_BOOTMODE=0 The bootmode of host domain <0 JTAG|1 Serial Link>
## @param CHS_PRELMODE=1 If 1, use the serial link for host domain memory preloading, otherwise JTAG.
## @param CHS_BINARY=<path_to_elf> ELF to be executed on host domain
## @param CHS_IMAGE=<path_to_memh> Raw image (ROMs) or GPT disk image to be executed on Cheshire (when CHS_BOOTMODE >= 1)
## @param SECD_BINARY=<path_to_elf> ELF to be executed on the host domain
## @param SECD_IMAGE=<path_to_memh> Raw image (ROMs) or GPT disk image to be executed on Cheshire (when CHS_BOOTMODE >= 1)
## @param SECD_BOOTMODE=0 The bootmode of secure domain <0 JTAG|1 Serial Link>
## @param SAFED_BINARY=<path_to_elf> ELF to be executed on safe domain
## @param SAFED_BOOTMODE=0 The bootmode of safe domain <0 JTAG|1 Serial Link>
## @param PULPD_BINARY=<path_to_elf> ELF to be executed on integer PMCA
## @param PULPD_BOOTMODE=0 The bootmode of safe domain <0 JTAG|1 Serial Link>
## @param SPATZD_BINARY==<path_to_elf> ELF to be executed on integer PMCA
## @param SPATZD_BOOTMODE=0 The bootmode of safe domain <0 JTAG|1 Serial Link>
## @param TESTBENCH=tb_astral_opt The optimised toplevel testbench to use. Defaults to 'tb_astral_opt'.
## @param VSIM_FLAGS The flags for the vsim invocation

pargs+=+HYP_USER_PRELOAD=$(HYP_USER_PRELOAD)
pargs+=+BYPASS_PLL=$(BYPASS_PLL)
pargs+=+SECURE_BOOT=$(SECURE_BOOT)
pargs+=+CHS_BOOTMODE=$(CHS_BOOTMODE)
pargs+=+CHS_PRELMODE=$(CHS_PRELMODE)
pargs+=+CHS_BINARY=$(CHS_BINARY_ABS)
pargs+=+CHS_IMAGE=$(CHS_IMAGE_ABS)
pargs+=+SECD_BINARY=$(SECD_BINARY_ABS)
pargs+=+SECD_BOOTMODE=$(SECD_BOOTMODE)
pargs+=+SECD_IMAGE=$(SECD_IMAGE_ABS)
pargs+=+SAFED_BINARY=$(SAFED_BINARY_ABS)
pargs+=+SAFED_BOOTMODE=$(SAFED_BOOTMODE)
pargs+=+PULPD_BINARY=$(PULPD_BINARY_ABS)
pargs+=+PULPD_BOOTMODE=$(PULPD_BOOTMODE)
pargs+=+SPATZD_BINARY=$(SPATZD_BINARY_ABS)
pargs+=+SPATZD_BOOTMODE=$(SPATZD_BOOTMODE)

car-vsim-sim-run:
ifneq ($(CHS_BINARY),)
	$(eval CHS_BINARY_ABS := $(realpath $(CHS_BINARY)))
endif
ifneq ($(CHS_IMAGE),)
	$(eval CHS_IMAGE_ABS := $(realpath $(CHS_IMAGE)))
endif
ifneq ($(SECD_BINARY),)
	$(eval SECD_BINARY_ABS := $(realpath $(SECD_BINARY)))
endif
ifneq ($(SECD_IMAGE),)
	$(eval SECD_IMAGE_ABS := $(realpath $(SECD_IMAGE)))
endif
ifneq ($(SAFED_BINARY),)
	$(eval SAFED_BINARY_ABS := $(realpath $(SAFED_BINARY)))
endif
ifneq ($(PULPD_BINARY),)
	$(eval PULPD_BINARY_ABS := $(realpath $(PULPD_BINARY)))
endif
ifneq ($(SPATZD_BINARY),)
	$(eval SPATZD_BINARY_ABS := $(realpath $(SPATZD_BINARY)))
endif
	cd $(CAR_VSIM_DIR); \
  qsim $(pargs) +designfile +permissive $(VSIM_FLAGS) +notimingchecks +nospecify -t 1ps $(TBENCH)_opt -do "$(RUN_AND_EXIT)"; \
	$(POST_SIM)

#######
# VCS #
#######
## @section VCS simulator target

CAR_VCS_ALL += $(CAR_SIM_ALL)
# TODO

###########
# Xcelium #
###########

## @section Xcelium simulator target

CAR_XCELIUM_ALL += $(CAR_XCELIUM_ALL)
# TODO

## @section Global targets
.PHONY: car-sim-init

## Generate all required VIPs and compilation scripts for all supported simulators
car-sim-init: car-vsim-sim-init
