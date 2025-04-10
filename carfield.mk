# Copyright 2022 ETH Zurich and University of Bologna.
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0
#
# Luca Valente <luca.valente@unibo.it>
# Alessandro Ottaviano <aottaviano@iis.ee.ethz.ch>
# Yvan Tortorella <yvan.tortorella@unibo.it>
# Robert Balas <balasr@iis.ee.ethz.ch>
# Manuel Eggimann <meggiman@iis.ee.ethz.ch>

# Carfield main make fragment

# Note: this makefrag uses autodocumentation, hence it follows rules for the comment style. See
# `utils/help.mk` for more information.

###################################
# Generic variable initialization #
###################################

SHELL := /bin/bash

CAR_ROOT    ?= $(shell $(BENDER) path carfield)
CAR_HW_DIR  := $(CAR_ROOT)/hw
CAR_SW_DIR  := $(CAR_ROOT)/sw
CAR_TGT_DIR := $(CAR_ROOT)/target
CAR_XIL_DIR := $(CAR_TGT_DIR)/xilinx
CAR_SIM_DIR := $(CAR_TGT_DIR)/sim
SECD_ROOT ?= $(shell $(BENDER) path opentitan)
HYP_ROOT    := $(shell $(BENDER) path hyperbus)

# Questasim
CAR_VSIM_DIR := $(CAR_TGT_DIR)/sim/vsim

TECH_ROOT   := $(CAR_ROOT)/tech

BENDER      ?= bender
BENDER_ROOT ?= $(CAR_ROOT)/.bender
BENDER_PATH ?= $(shell which $(BENDER))

PYTHON      ?= python3

PADRICK ?= $(CAR_HW_DIR)/padframe/padrick

# Include mandatory bender targets and defines for multiple targets (sim, fpga, synth)
include $(CAR_ROOT)/bender-common.mk
include $(CAR_ROOT)/bender-sim.mk
include $(CAR_ROOT)/bender-synth.mk
include $(CAR_ROOT)/bender-xilinx.mk

######################
# Nonfree components #
######################

CAR_NONFREE_REMOTE ?= git@iis-git.ee.ethz.ch:astral/astral-nonfree.git
CAR_NONFREE_COMMIT ?= 18b3c78500e6dacc9530283098e20de573292cff

## @section Carfield platform nonfree components
## Clone the non-free verification IP for Carfield. Some components such as CI scripts and ASIC
## implementations with tech-specific resources are not open-sourced and contained in a `nonfree`
## folder cloned from a remote location, whose access is restricted. If you do not have access, this
## step will be skipped and the usage of the repository will **not** be compromised.
isolde-nonfree-init:
	git clone $(CAR_NONFREE_REMOTE) $(CAR_ROOT)/nonfree
	cd $(CAR_ROOT)/nonfree && git checkout $(CAR_NONFREE_COMMIT)

-include $(CAR_ROOT)/nonfree/nonfree.mk

#####################################
# Islands' variables initialization #
#####################################

# Cheshire, host domain
CHS_ROOT ?= $(shell $(BENDER) path cheshire)
# Include cheshire's makefrag only if the dependency was cloned
-include $(CHS_ROOT)/cheshire.mk
CHS_BOOTMODE ?= 0 # default passive bootmode
CHS_PRELMODE ?= 1 # default serial link preload
CHS_BINARY   ?=
CHS_IMAGE    ?=

# Security island, security and secure boot
SECD_ROOT     ?= $(shell $(BENDER) path opentitan)
SECD_BINARY   ?=
SECD_BOOTMODE ?= 0
SECD_IMAGE    ?=
# Secure boot
SECURE_BOOT   ?= 0

# PULP cluster, reliability and general-purpose accelerator
PULPD_ROOT      ?= $(shell $(BENDER) path pulp_cluster)
PULPD_BINARY    ?=
PULPD_TEST_NAME ?=
PULPD_BOOTMODE  ?=

# PLL/FLL bypass
BYPASS_PLL ?= 0

###########################
# System HW configuration #
###########################

# Interrupt configuration in cheshire
# CLINT interruptible harts
CLINTCORES     := 4
# PLIC interruptible harts
PLICCORES      := 8
# PLIC number of input interrupts
PLIC_NUM_INTRS := 89

# Serial Link configuration in cheshire
SERIAL_LINK_NUM_BITS := 16

# AXI Real-Time unit configuration in Carfield
AXIRT_NUM_MGRS := 9
AXIRT_NUM_SUBS := 2

##########################################
# Virtual environment for python scripts #
##########################################

VENVDIR?=$(WORKDIR)/.venv
REQUIREMENTS_TXT?=$(wildcard requirements.txt)
include $(CAR_ROOT)/utils/venv.mk

##########################
# Dependency maintenance #
##########################

## @section Carfield platform dependency management
.PHONY: isolde-update-deps
## Update and re-resove all IP dependencies. Bender will try to resolve dependency conflicts with
## semantic versioning and the Bender.local file that contains overrides. You should run this target
## only if you changed the Bender.yml file and updated the version of some sub-IP. This will
## regenerate the Bender.lock. Once you resolved all remaining dependency conflicts you must commit
## the udpated Bender.lock file to keep the pinned IP versions in line with the Bender.yml file.
isolde-update-deps:
	$(BENDER) update

.PHONY: isolde-checkout-deps
## Checkout all IP dependencies that are currently pinned in the Bender.lock file. This command will
## not re-resolve dependencies but use the exact versions checked into the repository through the
## lock file. Use the isolde-update-deps target to update all IPs to the latest version and to
## regenerate the lock file.
isolde-checkout-deps:
	$(BENDER) checkout
	touch Bender.lock

.PHONY: isolde-checkout
isolde-checkout: isolde-checkout-deps

############
# Build SW #
############
## @section Islands compile exclusion
ifeq ($(shell echo $(PULPD_PRESENT)), 1)
PULPD_SW_BUILD := pulpd-sw-build
PULPD_SW_INIT := pulpd-sw-init
endif

## @section Carfield platform SW build
include $(CAR_SW_DIR)/sw.mk
.PHONY: chs-sw-build
## Build the host domain (Cheshire) SW libraries and generates an archive (`libcheshire.a`)
## available for Carfield as static library at link time.
chs-sw-build: chs-sw-all

.PHONY: isolde-sw-build
## Builds carfield application SW and specific libraries. It links against `libcheshire.a`.
isolde-sw-build: chs-sw-build $(PULPD_SW_BUILD) isolde-sw-all

.PHONY: pulpd-sw-init

## Clone integer PMCA domain's SW stack in the dedicated repository.
pulpd-sw-init: $(PULPD_ROOT) $(PULPD_ROOT)/pulp-runtime $(PULPD_ROOT)/regression_tests

$(PULPD_ROOT)/pulp-runtime: $(PULPD_ROOT)
	$(MAKE) -C $(PULPD_ROOT) pulp-runtime
$(PULPD_ROOT)/regression_tests: $(PULPD_ROOT)
	$(MAKE) -C $(PULPD_ROOT) regression_tests

## Build integer PMCA domain SW
.PHONY: pulpd-sw-build
pulpd-sw-build: pulpd-sw-init
	. $(CAR_ROOT)/env/pulpd-env.sh; \
	$(MAKE) pulpd-sw-all

###############
# Generate HW #
###############

## @section Carfield platform HW generation
.PHONY: isolde-hw-init
## Initialize Carfield HW. This step takes care of the generation of the missing hardware or the
## update of default HW configurations in some of the domains. See the two prerequisite's comment
## for more information.
isolde-hw-init: chs-hw-init $(SECD_HW_INIT)

## @section Carfield platform PCRs generation
.PHONY: regenerate_soc_regs
## Regenerate the toplevel PCRs from the CSV description of all registers in
## hw/regs/carfield_regs.csv. You don't have to run this target unless you changed the CSV file. The
## checked-in pregenerated register file RTL should be up-to-date. If you regenerate the regfile, do
## not forget to check in the generated RTL. In addition, dedicated documentation is autogenerated.
regenerate_soc_regs: $(CAR_ROOT)/hw/regs/carfield_reg_pkg.sv $(CAR_ROOT)/hw/regs/carfield_reg_top.sv $(CAR_SW_DIR)/include/regs/soc_ctrl.h $(CAR_HW_DIR)/regs/pcr.md

.PHONY: $(CAR_ROOT)/hw/regs/carfield_regs.hjson
$(CAR_ROOT)/hw/regs/carfield_regs.hjson: hw/regs/carfield_regs.csv | venv
	$(VENV)/$(PYTHON) ./scripts/csv_to_json.py --input $< --output $@

.PHONY: $(CAR_ROOT)/hw/regs/carfield_reg_pkg.sv hw/regs/carfield_reg_top.sv
$(CAR_ROOT)/hw/regs/carfield_reg_pkg.sv $(CAR_ROOT)/hw/regs/carfield_reg_top.sv: $(CAR_ROOT)/hw/regs/carfield_regs.hjson | venv
	$(VENV)/$(PYTHON) utils/reggen/regtool.py -r $< --outdir $(dir $@)

.PHONY: $(CAR_SW_DIR)/include/regs/soc_ctrl.h
$(CAR_SW_DIR)/include/regs/soc_ctrl.h: $(CAR_ROOT)/hw/regs/carfield_regs.hjson | venv
	$(VENV)/$(PYTHON) utils/reggen/regtool.py -D $<  > $@

.PHONY: $(CAR_SW_DIR)/hw/regs/pcr.md
$(CAR_HW_DIR)/regs/pcr.md: $(CAR_ROOT)/hw/regs/carfield_regs.hjson | venv
	$(VENV)/$(PYTHON) utils/reggen/regtool.py -d $<  > $@

## @section Carfield padframe generation
.PHONY: regenerate_padframe
regenerate_padframe: $(CAR_HW_DIR)/padframe/astral_padframe $(CAR_SW_DIR)/include/regs/padframe_regs.h

$(CAR_HW_DIR)/padframe/astral_padframe: $(CAR_HW_DIR)/padframe/astral_padframe.yml
	$(PADRICK) generate rtl $< -o $@
	sed -i.original '/i_pad_vss_core_v_2/d' $@/src/astral_padframe_periph_pads.sv

.PHONY: $(CAR_SW_DIR)/include/regs/padframe_regs.h
$(CAR_SW_DIR)/include/regs/padframe_regs.h: $(CAR_ROOT)/hw/padframe/astral_padframe/src/astral_padframe_periph_regs.hjson | venv
	$(VENV)/$(PYTHON) utils/reggen/regtool.py -D $<  > $@

## Update host domain PLIC and CLINT interrupt controllers configuration. The default configuration
## in cheshire allows for one interruptible hart. When the number of external interruptible harts is
## updated in the Cheshire cfg (cheshire_pkg.sv), we need to regenerate the PLIC and CLINT
## accordingly. CLINT: define CLINTCORES used in cheshire.mk before including the makefrag. PLIC:
## edit the hjson configuration file in cheshire.
.PHONY: update_plic
update_plic: $(CHS_ROOT)/hw/rv_plic.cfg.hjson
	sed -i 's/src: .*/src: $(PLIC_NUM_INTRS),/' $<
	sed -i 's/target: .*/target: $(PLICCORES),/' $<

## Update host domain Serial Link configuration. The default configuration in cheshire allows for 4
## data lanes for the serial link. We update the configuration to 8 data lanes.
.PHONY: update_serial_link
update_serial_link: $(CHS_ROOT)/hw/serial_link.hjson
	sed -i 's/\(default: "\)8/\116/' $<

## Install basic python packages used to build Cheshire HW.
.PHONY: python_requirements
python_requirements:
	pip install tabulate hjson

## Generate Cheshire HW. This target has a prerequisite, i.e. the PLIC and serial link
## configurations must be chosen before generating the hardware.
.PHONY: chs-hw-init
chs-hw-init: update_plic update_serial_link
	$(MAKE) -B chs-hw-all

##############
# Simulation #
##############

## @section Carfield platform simulation
include $(CAR_SIM_DIR)/sim.mk

##################
# Global targets #
##################

## @section Carfield global targets

.PHONY: isolde-init-all
## Shortcut to initialize carfield with all the targets described above.
isolde-init-all: isolde-checkout isolde-hw-init isolde-sim-init $(PULPD_SW_INIT)

## Initialize Carfield and build SW
.PHONY: isolde-all
isolde-all: isolde-init-all isolde-sw-build

#########
# Utils #
#########
## @section Carfield platform utilities

# Lint
SPYGLASS_TARGS += $(common_targs)
SPYGLASS_TARGS += $(synth_targs)
SPYGLASS_DEFS += $(common_defs)
SPYGLASS_DEFS += $(synth_defs)

## Lint the Carfield codebase using Spyglass
.PHONY:lint
lint:
	$(MAKE) -C scripts lint bender_defs="$(SPYGLASS_DEFS)" bender_targs="$(SPYGLASS_TARGS)" > make.log

#############
# Emulation #
#############
## @section Carfield emulation

# Xilinx
include $(CAR_XIL_DIR)/xilinx.mk

#######################
# External benchmarks #
#######################

# Litmus tests
# LITMUS_WORK_DIR  := work-litmus
# LITMUS_TEST_LIST := $(LITMUS_WORK_DIR)/litmus-tests.list
# LITMUS_TESTS     := $(shell xargs printf '\n%s' < $(LITMUS_TEST_LIST) | cut -b 1-)

$(LITMUS_WORK_DIR):
	mkdir -p $(LITMUS_WORK_DIR)

$(LITMUS_TEST_LIST): $(LITMUS_WORK_DIR)
	basename -a `find $(LITMUS_DIR)/binaries/ -name "*.elf" | sed 's/\[/\\\[/g'` > $@

$(LITMUS_TESTS):
	$(MAKE) isolde-vsim-sim-run CHS_BOOTMODE=0 CHS_PRELMODE=1 CHS_BINARY=$(LITMUS_DIR)/binaries/$@ | tee $(LITMUS_WORK_DIR)/$@.log

$(LITMUS_WORK_DIR)/%.uart.log: %
	sed -n 's/^# \[UART\] \(.*\S\)\s*$$/\1/p' $(LITMUS_WORK_DIR)/$<.log > $@

$(LITMUS_WORK_DIR)/%.litmus.log: $(LITMUS_WORK_DIR)/%.uart.log
	echo "Test $(basename $* .elf) Allowed" > $@
	echo "Histogram" >> $@
	cat $< >> $@
	echo "" >> $@

## Clone Litmus tests for the RISC-V concurrency architecture and run them
isolde-run-litmus-tests: $(LITMUS_TEST_LIST) $(addprefix $(LITMUS_WORK_DIR)/, $(addsuffix .litmus.log,$(LITMUS_TESTS)))
	cat $^ > $(LITMUS_WORK_DIR)/litmus.log

## Check Litmus tests results against golden model
isolde-check-litmus-tests: $(LITMUS_WORK_DIR)/litmus.log
	cd $(LITMUS_DIR) && LITMUS_LOG=$(CURDIR)/$(LITMUS_WORK_DIR)/litmus.log ci/compare_model.sh > $(CURDIR)/$(LITMUS_WORK_DIR)/compare.log
	grep "Warning positive differences" $(LITMUS_WORK_DIR)/compare.log
	! grep "Warning negative differences" $(LITMUS_WORK_DIR)/compare.log

########
# Help #
########

# Setup Autodocumentation of the Makefile
HELP_TITLE="ISOLDE Space platform Open-Source RTL"
HELP_DESCRIPTION="Hardware generation and simulation targets for ISOLDE space platform"
include $(CAR_ROOT)/utils/help.mk
.DEFAULT_GOAL := help
