# \[WIP\] Astral User Guide

_This basic documentation is based on that of [Carfield](https://pulp-platform.github.io/carfield/) which is a similar architecture with the same build flow. While many things are still valid, others may differ. Credit is given to its original author._

## Getting Started

### Architecture

This section provides very basic info about Astral's architecture.

Astral is organized in _domains_, and a fully-featured Astral provides:

-   **Domains**:

    -   _Host domain_ ([_Cheshire_](https://github.com/pulp-platform/cheshire)), a Linux-capable RV64 system based on single-core CVA6 processor
    -   _Secure domain_, a Dual-Core-Lockstep (DCLS) RV32 Hardware Root of Trust (HW RoT) systems
    -   _PULP cluster domain_, an 8-cores cluster augmented with domain-specific hw accelerators targeting AI workloads

-   **On-chip and off-chip memory endpoints**:

    -   _Dynamic SPM_ (L2): dynamically configurable scratchpad memory (SPM) for _interleaved_ or _contiguous_ accesses
    -   _Partitionable hybrid LLC SPM_: host domain last-level cache configurable at runtime as SPM
    -   _External DRAM_: off-chip HyperRAM (Infineon) interfaced with in-house, open-source AXI4 Hyberbus memory controller and digital PHY connected to Cheshire's LLC

### Repository structure

The project is structured as follows:

| Directory | Description                                |
| --------- | ------------------------------------------ |
| `hw`      | Hardware sources as SystemVerilog RTL      |
| `sw`      | Software stack, build setup, and tests     |
| `target`  | Simulation, FPGA, and ASIC target setups   |
| `utils`   | Utility scripts                            |
| `scripts` | Some helper scripts for env setup          |

## Astral FPGA Development Flow

### Dependencies

To build Astral, you will need:

-   GNU Make `>= 3.82`
-   Python `>= 3.6`
	- `hjson` package
	- `tabulate` package
-   RISCV GCC toolchain `>= 11.2.0`
-   PULP RV32 GCC toolchain [`1.0.16`](https://github.com/pulp-platform/pulp-riscv-gnu-toolchain/releases/tag/v1.0.16)
-   Bender `>= 0.27.1, <=0.28.2` (see [Install Bender](#0-install-bender))
-   Vivado`== 2020.2`*

*At the moment it is required to use this specific Vivado version. Newer versions have shown to be problematic.


### 0\. Install Bender

We use [Bender](https://github.com/pulp-platform/bender) for hardware IP and dependency management; for more information on using Bender, please see its documentation. You can install Bender directly through the following command:

```
curl --proto '=https' --tlsv1.2 https://pulp-platform.github.io/bender/init -sSf | sh
```

Make sure to export the path to Bender binary to `$BENDER` variable.

### 1\. Source env file

`source env/env-non-iis.sh`

This bash script set some env variables and check for the presence of RISCV{32,64} toolchain, QuestaSim and Vivado in the `$PATH` and the definition of `$BENDER` variable. If you don't need certain tools, e.g., QuestaSim or Vivado, or if they are managed differently, it's not a problem if these are not in `$PATH`.

### 2\. Initialize all the hardware IPs

-   `make isolde-checkout`: It invokes Bender tool to checkout all IP dependencies that are currently pinned in the `Bender.lock` file.*
-   `make isolde-hw-init`: Initialize Astral HW. This step takes care of the generation of the missing hardware or the update of default HW configurations in some of the domains.

*_Note that this command could show an error about not having the right to fetch the `rv_plic` repository. This happens if you haven't set an SSH key to GitHub (even if the repository is public). However, this is not going to disrupt the build flow as those files are not indeed used. Anyway, we are aware of this and we are working to fix it._

### 2.1 (Recommended) Build Astral with QuestaSim

To check if the IPs initialization went good, it's better to compile the whole architecture with QuestaSim (this is the only tool supported at the moment). To do so:

-   Ensure that QuestaSim is in the `$PATH`. By default, the `QUESTA` variable is left empty. If the QuestaSim binaries directory is included in your `$PATH`, no further configuration is required. Otherwise, adjust it according to your setup.
-   Fix buggy download of hyperbus models.
```
cd .bender/git/checkouts/hyperbus-358c17d6f73a3e33/models
git clone git@iis-git.ee.ethz.ch:astral/hyp_vip.git s27ks0641
cd  -
# manually fix stuff
cd .bender/git/checkouts/opentitan-7d9ffd8b698d2da4/
sed -i '18s|hw/ip/lowrisc_ibex/rtl|hw/vendor/lowrisc_ibex/rtl|' Bender.yml
sed -i 's|hw/ip/prim/rtl/prim_flop_macros\.svh|hw/ip/prim/rtl/prim_flop_macros.sv|; s|hw/ip/sysrst_ctrl/rtl/sysrst_ctrl_detect\.vs|hw/ip/sysrst_ctrl/rtl/sysrst_ctrl_detect.sv|' Bender.yml
sed -i '200d' Bender.yml
```
-   `make isolde-vsim-sim-clean`: clean up mess from previous builds
-   `make isolde-vsim-sim-init`: initialize the simulation environment by fetching verification IP for HyperRam from Infineon website. Next, using Bender, it generates a TCL script that includes a list of all source files for each IP present in the design.
-   `make isolde-vsim-sim-build`: launch QuestaSim sourcing the sourcefiles TCL script to build the design.

If the compilation is successful, the system can be considered to have been properly initialized.

Although not necessary for FPGA implementation purposes, it may be useful to perform RTL simulations of the design. See [RTL Simulation](#rtl-simulation-questasim) for more information on how to run RTL simulation with QuestaSim.

### 3\. Launch FPGA Synthesis

The FPGA synthesis is also plug and play and can be launched with one simple command along with a set of option.

The Astral bitstream generation is divided in two flavors at the moment. The `flavor_vanilla` and the `flavor_bd`.

-   `flavor_vanilla` \- The hardware to be mapped on the FPGA is fully described in System Verilog. This flow is lightweight, easily reproducible, and self contained.
-   `flavor_bd` \- In order to allow for more complex top level, this flow relies on the Vivado block design flow to link Astral with external IPs. This flow is less human readable but allows integrating more complex IPs.

_So far, only the vanilla flavor has been tested._

Ensure that Vivado is in the `$PATH`. By default, the `VIVADO` variable is left empty, but a submodule overrides it when invoking Vivado-related Makefile targets. If the Vivado binaries directory is included in your `$PATH`, it is required to explicitly do `export VIVADO=`. Otherwise, adjust it according to your setup.

#### Vanilla bitstream

If you want to see the Makefiles that you will be using, you can find the generic FPGA rules in `target/xilinx/xilinx.mk` and the vanilla specific rules in `target/xilinx/flavor_vanilla/flavor_vanilla.mk`.

Generate the bitstream in `target/xilinx/out/` by running:

```bash
make isolde-xil-all XILINX_FLAVOR=vanilla XILINX_BOARD=vcu118 GEN_NO_HYPERBUS={0,1} GEN_EXT_JTAG={0,1} CARFIELD_CONFIG=<configuration>
```

My command:
```bash
VIVADO_MODE=batch VIVADO=vivado make isolde-xil-clean-vanilla isolde-xil-all XILINX_FLAVOR=vanilla XILINX_BOARD=vcu118 GEN_NO_HYPERBUS=1 GEN_EXT_JTAG=1 CARFIELD_CONFIG=carfield_l2dual_pulp_periph
```

See the argument list below:


| Argument        | Description                                                                                                                           |
|-----------------|---------------------------------------------------------------------------------------------------------------------------------------
| GEN_NO_HYPERBUS | `0` Use the hyperram controller inside `carfield.sv`<br>`1` Use the Xilinx DDR controller                                             |
| GEN_EXT_JTAG    | `0` Connect the JTAG debugger to the board's JTAG <br>`1` Connect the JTAG debugger to an external JTAG chain |
| CARFIELD_CONFIG | Astral configuration to implement. See below for supported configs.                                                                                                                       |

`<configuration>` is a placeholder for a corresponding SystemVerilog file under the directory `hw/configs` that identifies the specific target Astral configuration, that is which islands/peripherals to include and where they are mapped. The file's name reflects the hardware included:

-   `pulp` : pulp cluster (8 RV32 cores + domain-specific hw accelerator)
-   `secure` security island (OpenTitan root of trust)
-   `periph` basic peripherals


| Configuration| Status | Active Island | Duration |
|--------------|--------| --------------| ----|
| carfield_l2dual_pulp_periph |  OK | Pulp Cluster |
| carfield_l2dual_secure_periph          |  OK    | Security Island | |
| carfield_l2dual_secure_pulp_periph |  OK | Pulp Cluster + Security Island | |

Recommended (and so far tested) options:

```
make isolde-xil-all XILINX_FLAVOR=vanilla XILINX_BOARD=vcu118 GEN_NO_HYPERBUS=1 GEN_EXT_JTAG=1 CARFIELD_CONFIG=<configuration>
```

Where:

-   `GEN_EXT_JTAG=1`: using `EXT_JTAG=1` we add an external JTAG chain for the RV64 host and other islands through the FPGA's Pmod GPIOs header J52 where we connect an Olimex ARM-USB-OCD-H/Digilent JTAG-HS2*.
-   `GEN_NO_HYPERBUS=1`: at the moment interfacing with the Xilinx DDR controller is not properly working, however, to avoid synthesizing the Hyperbus Controller this flag is set to 1.

\* The VCU118 development board only provides one JTAG chain, used by Vivado to program the bitstream, and interact with certain Xilinx IPs (ILAs, VIOs, ...). The RV64 requires access to a JTAG chain to connect GDB to the debug-module in the bitstream. When using `EXT_JTAG=0` it is possible to connect the debug module to the internal FPGA's JTAG by using the Xilinx BSCANE macro. With this, you will only need the normal Xilinx USB cable to interact with CVA6. Note that it means that Vivado and OpenOCD can not use the same cable at the same time. This setup (with `EXT_JTAG=0`) will only work for designs containing the host only, as it is not possible to chain multiple devices on the BSCANE macro. If you need to use `EXT_JTAG=0` consider modifying the RTL to remove the debug modules of the IPs.

#### Additional resources

_[Here](https://github.com/LuigiGhionda/astral-fpga) you can find a collection of scripts designed to simplify the process of loading binaries into an FPGA setup like the one described above, using `openocd` and `gdb`._


## Software Stack

This section provides basic info about Astral's software stack.

Astral's Software Stack is provided in the `sw/` folder, organized as follows:

```
sw
+-- boot
+-- include
+-- lib
+-- link
+-- sw.mk
+-- tests
    +-- bare-metal
    ¦   +-- hostd
    ¦   +-- pulpd
    ¦   +-- secd
    +-- linux
```

### Single domain programs build flow

The global command to build software is:

```bash
sed -i 's/-Wall -Wextra -static/-Wall -Wextra -Wno-int-conversion -Wno-implicit-function-declaration -Wno-incompatible-pointer-types -static/' cheshire/sw/sw.mk # for GCC CVA6
make isolde-sw-build
```

It initializes and builds the SW libraries of the different domains (host, pulp domain, security island), then it compiles all the baremetal tests. It builds program binaries in ELF format for each domain, which can be used with the simulation methods supported by the platform or on FPGA.

As in Cheshire, Astral programs can be created to be executed from several memory locations:

-   Dynamic SPM (`*.l2.elf`): the linkerscript is provided in Astral's `sw/link/` folder, since Dynamic SPM is not integrated in the minimal Cheshire
-   LLC SPM (`*.spm.elf`): valid when the LLC is configured as such. In Astral, half of the LLC is configured as SPM from the boot ROM during system bringup, as this is the default behavior in Cheshire (host_domain).
-   DRAM (`*.dram.elf`): the off-chip DRAM, e.g., the HyperRAM

For example, to build a specific bare-metal test (here `sw/tests/bare-metal/hostd/helloworld.c` to be run on host domain) executing from the Dynamic SPM, run:

```bash
make sw/tests/bare-metal/hostd/helloworld.car.l2.elf
```

### Simple baremetal offload

In these tests, the offloader (_host_domain_) takes care of bootstrapping the target device ELF in the correct memory location, initializing the target and launching its execution through a simple ELF Loader. The ELF Loader source code is located in the offloader's SW directory, and follows a naming convention:

```
<target_device>_offloader_<blocking|non_blocking>.c
```

The target device's ELF is included into the offloader's ELF Loader as a _header file_. The target device's ELF sections are first pre-processed offline to extract instruction addresses.The resulting header file provides the ELF loading process at the selected memory location. The loading process can be carried out by the offloader as R/W sequences, or deferred to a DMA-driven memcopy. In addition, the offloader takes care of bootstrapping the target device, i.e. initializing it and launching its execution. Upon target device completion, the offloader sychronously polls a specific register to catch the completion (_blocking_ offload type).

As an example, assume the _host domain_ as offloader and the _PULP cluster_ as target device.

1.  The host domain ELF Loader is included in `sw/tests/bare-metal/hostd`
2.  A header file is generated out of each regression test available in the PULP cluster repository. For this example, the resulting header files are included in `sw/tests/bare-metal/pulpd`
3.  The final ELF executed by the offloader is created by subsequently including each header file from each cluster regression test

The resulting offloader ELF's name reads:
```
<target_device>_offloader_<blocking|non_blocking>.<target_device_test_name>.car.<l2|spm|dram>.elf
```

According to the memory location where the baremetal test will be executed.


## RTL Simulation (QuestaSim)

This section describes how to simulate Astral to execute baremetal programs.

```bash
. env/pulpd-env.sh
make pulpd-sw-init pulpd-sw-build
```

### Testbench

Astral comprises several bootable domains, as briefly described earlier.

Each of these domains can be independently booted by keeping the rest of the SoC asleep through the domain JTAG, or Cheshire's JTAG and Serial Link, which have access to the whole platform except for the _secure domain_.

Alternatively, _host domain_ can offload baremetal programs to the _accelerator domain_.

We provide a single SystemVerilog testbench that handles standalone execution of baremetal programs for each domain. The code for domain `X` is preloaded through simulated interface drivers. In addition, some domains can read from external memory models from their boot ROM and then jump to execution.

As for Cheshire, Astral testbench employs physical interfaces (JTAG or Serial Link) for memory preload by default. This could increase the memory preload time (independently from the target memory: dynamic SPM, LLC-SPM, or DRAM), significantly based on the ELF size.

#### Passive boot example

Below, it is provided an example with `Serial Link` passive preload of a baremetal program `helloworld.car.l2.elf` to be executed on the _host domain_ (Cheshire, i.e., `X=CHS`):
```bash
make isolde-vsim-sim-run CHS_BOOTMODE=0 CHS_PRELMODE=1 CHS_BINARY=./sw/tests/bare-metal/hostd/helloworld.car.l2.elf
```
The design needs to be recompiled only when hardware is changed.

To clean simulation builds, from the `vsim` folder run

```bash
make isolde-vsim-sim-clean
```

#### Debugging

Per default, Questasim compilation is performance-optimized, and GUI and simulation logging are disabled. To enable full visibility, logging, and the Questa GUI, set `DEBUG=1` when launching the simulation.