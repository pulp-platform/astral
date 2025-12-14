// Copyright 2022 ETH Zurich and University of Bologna.
// Solderpad Hardware License, Version 0.51, see LICENSE for details.
// SPDX-License-Identifier: SHL-0.51
//
// Thomas Benz  <tbenz@ethz.ch>
// Yvan Tortorella <yvan.tortorella@unibo.it>
// Alessandro Ottaviano <aottaviano@iis.ee.ethz.ch>

`include "cheshire/typedef.svh"

/// Carfield constants and Cheshire overwrites
package carfield_pkg;

import cheshire_pkg::*;

import carfield_configuration::*;

/***********************************
* Carfield Configuration functions *
***********************************/

// Below there are the functions used to flexibly reconfigure
// Carfield's depending on a `carfield_configuration` file were
// it is possible to enable/disable given islands and adapt the
// SoC's memory map accordingly. The following functions are all
// used within the `carfield_pkg` only.

typedef struct packed {
  bit enable;
  doub_bt base;
  doub_bt size;
} islands_properties_t;

typedef struct packed {
  islands_properties_t l2_port0;
  islands_properties_t l2_port1;
  islands_properties_t safed;
  islands_properties_t ethernet;
  islands_properties_t periph;
  islands_properties_t spatz;
  islands_properties_t pulp;
  islands_properties_t secured;
  islands_properties_t mbox;
} islands_cfg_t;

// Types are obtained from Cheshire package
// Parameter MaxExtAxiSlvWidth is obtained from Cheshire
// Structure used to create the AXI map to be passed to
// the Cheshire configuration parameter to create the
// AXI crossbar.
localparam int unsigned MaxExtAxiSlv = 2**MaxExtAxiSlvWidth;
typedef struct packed {
  byte_bt [MaxExtAxiSlv-1:0] AxiIdx;
  doub_bt [MaxExtAxiSlv-1:0] AxiStart;
  doub_bt [MaxExtAxiSlv-1:0] AxiEnd;
} axi_struct_t;

typedef struct packed {
  byte_bt l2_port0;
  byte_bt l2_port1;
  byte_bt safed;
  byte_bt periph;
  byte_bt spatz;
  byte_bt pulp;
  byte_bt mbox;
} carfield_slave_idx_t;

typedef struct packed {
  byte_bt safed;
  byte_bt spatz;
  byte_bt secured;
  byte_bt secured_idma;
  byte_bt pulp;
  byte_bt ethernet;
} carfield_master_idx_t;

// Generate the number of AXI slave devices to be connected to the
// crossbar starting from the islands enable structure.
function automatic int unsigned gen_num_axi_slave(islands_cfg_t island_cfg);
  int unsigned ret = 0; // Number of slaves starts from 0
  if (island_cfg.l2_port0.enable) begin
    ret++; // If we enable L2, we increase by 1
    if (island_cfg.l2_port1.enable)
      ret++; // If the L2 is dualport, increase again
  end
  if (island_cfg.safed.enable   ) begin ret++; end
  if (island_cfg.periph.enable  ) begin ret++; end
  if (island_cfg.spatz.enable   ) begin ret++; end
  if (island_cfg.pulp.enable    ) begin ret++; end
  if (island_cfg.mbox.enable    ) begin ret++; end
  return ret;
endfunction

// Generate the IDs for each AXI slave device
function automatic carfield_slave_idx_t carfield_gen_axi_slave_idx(islands_cfg_t island_cfg);
  carfield_slave_idx_t ret = '{default: '0}; // Initialize struct first
  byte_bt i = 0;
  byte_bt j = 0;
  if (island_cfg.l2_port0.enable) begin ret.l2_port0 = i; i++;
    if (island_cfg.l2_port1.enable) begin ret.l2_port1 = i; i++; end
  end else begin
    ret.l2_port0 = MaxExtAxiSlv + j; j++;
    ret.l2_port1 = MaxExtAxiSlv + j; j++;
  end
  if (island_cfg.safed.enable) begin ret.safed = i; i++;
  end else begin ret.safed = MaxExtAxiSlv + j; j++; end
  if (island_cfg.periph.enable) begin ret.periph = i; i++;
  end else begin ret.periph = MaxExtAxiSlv + j; j++; end
  if (island_cfg.spatz.enable) begin ret.spatz = i; i++;
  end else begin ret.spatz = MaxExtAxiSlv + j; j++; end
  if (island_cfg.pulp.enable) begin ret.pulp = i; i++;
  end else begin ret.pulp = MaxExtAxiSlv + j; j++; end
  if (island_cfg.mbox.enable) begin ret.mbox = i; i++;
  end else begin ret.mbox = MaxExtAxiSlv + j; j++; end
  return ret;
endfunction

// Generate the number of AXI master devices that connect to the
// crossbar starting from the islands enable structure.
function automatic int unsigned gen_num_axi_master(islands_cfg_t island_cfg);
  int unsigned ret = 0; // Number of masters starts from 0
  if (island_cfg.safed.enable  ) begin ret++; end
  if (island_cfg.spatz.enable  ) begin ret++; end
  if (island_cfg.pulp.enable   ) begin ret++; end
  if (island_cfg.ethernet.enable) begin ret++; end
  if (island_cfg.secured.enable) begin ret+=2; end
  return ret;
endfunction

// Generate the IDs for each AXI master device
localparam int unsigned MaxExtAxiMst = 2**MaxExtAxiMstWidth;
function automatic carfield_master_idx_t carfield_gen_axi_master_idx(islands_cfg_t island_cfg);
  carfield_master_idx_t ret = '{default: '0}; // Initialize struct first
  byte_bt i = 0;
  byte_bt j = 0;
  if (island_cfg.safed.enable) begin ret.safed = i; i++;
  end else begin ret.safed = MaxExtAxiMst + j; j++; end
  if (island_cfg.secured.enable) begin ret.secured = i; ret.secured_idma = i+1; i+=2;
  end else begin ret.secured = MaxExtAxiMst + j; ret.secured_idma = MaxExtAxiMst + j + 1; j+=2; end
  if (island_cfg.spatz.enable) begin ret.spatz = i; i++;
  end else begin ret.spatz = MaxExtAxiMst + j; j++; end
  if (island_cfg.pulp.enable) begin ret.pulp = i; i++;
  end else begin ret.pulp = MaxExtAxiMst + j; j++; end
  if (island_cfg.ethernet.enable) begin ret.ethernet = i; i++;
  end else begin ret.ethernet = MaxExtAxiMst + j; j++; end
  return ret;
endfunction

// Compute memory map
function automatic axi_struct_t carfield_gen_axi_map(int unsigned NumSlave  ,
                                                    islands_cfg_t island_cfg,
                                                    carfield_slave_idx_t idx);
  axi_struct_t ret = '0; // Initialize the map first
  int unsigned i = 0;
  if (island_cfg.l2_port0.enable) begin
    ret.AxiIdx[i] = idx.l2_port0;
    ret.AxiStart[i] = island_cfg.l2_port0.base;
    ret.AxiEnd[i] = island_cfg.l2_port0.base + island_cfg.l2_port0.size;
    if (i < NumSlave - 1) i++;
    if (island_cfg.l2_port1.enable) begin
      ret.AxiIdx[i] = idx.l2_port1;
      ret.AxiStart[i] = island_cfg.l2_port1.base;
      ret.AxiEnd[i] = island_cfg.l2_port1.base + island_cfg.l2_port1.size;
      if (i < NumSlave - 1) i++;
    end
  end
  if (island_cfg.safed.enable) begin
    ret.AxiIdx[i] = idx.safed;
    ret.AxiStart[i] = island_cfg.safed.base;
    ret.AxiEnd[i] = island_cfg.safed.base + island_cfg.safed.size;
    if (i < NumSlave - 1) i++;
  end
  if (island_cfg.periph.enable) begin
    ret.AxiIdx[i] = idx.periph;
    ret.AxiStart[i] = island_cfg.periph.base;
    ret.AxiEnd[i] = island_cfg.periph.base + island_cfg.periph.size;
    if (i < NumSlave - 1) i++;
  end
  if (island_cfg.spatz.enable) begin
    ret.AxiIdx[i] = idx.spatz;
    ret.AxiStart[i] = island_cfg.spatz.base;
    ret.AxiEnd[i] = island_cfg.spatz.base + island_cfg.spatz.size;
    if (i < NumSlave - 1) i++;
  end
  if (island_cfg.pulp.enable) begin
    ret.AxiIdx[i] = idx.pulp;
    ret.AxiStart[i] = island_cfg.pulp.base;
    ret.AxiEnd[i] = island_cfg.pulp.base + island_cfg.pulp.size;
    if (i < NumSlave - 1) i++;
  end
  if (island_cfg.mbox.enable) begin
    ret.AxiIdx[i] = idx.mbox;
    ret.AxiStart[i] = island_cfg.mbox.base;
    ret.AxiEnd[i] = island_cfg.mbox.base + island_cfg.mbox.size;
    if (i < NumSlave - 1) i++;
  end
  return ret;
endfunction

/********************
 * RegBus functions *
 *******************/
typedef struct packed {
  islands_properties_t pcrs;
  islands_properties_t pll;
  islands_properties_t padframe;
  islands_properties_t l2ecc;
  islands_properties_t ethernet;
} regbus_cfg_t;

typedef struct packed {
  byte_bt pcrs;
  byte_bt pll;
  byte_bt padframe;
  byte_bt ethernet;
  byte_bt l2ecc;
} carfield_regbus_slave_idx_t;

// Generate the number of AXI slave devices to be connected to the
// crossbar starting from the islands enable structure.
function automatic int unsigned gen_num_regbus_sync_slave(regbus_cfg_t regbus_cfg);
  int unsigned ret = 0; // Number of slaves starts from 0
  if (regbus_cfg.pcrs.enable) begin ret++; end
  return ret;
endfunction

function automatic int unsigned gen_num_regbus_async_slave(regbus_cfg_t regbus_cfg);
  int unsigned ret = 0; // Number of slaves starts from 0
  if (regbus_cfg.pll.enable     ) begin ret++; end
  if (regbus_cfg.padframe.enable) begin ret++; end
  if (regbus_cfg.l2ecc.enable   ) begin ret++; end
  if (regbus_cfg.ethernet.enable) begin ret++; end
  return ret;
endfunction

localparam regbus_cfg_t CarfieldRegBusCfg = '{
  pcrs:     '{1, PcrsBase, PcrsSize},
  pll:      '{PllCfgEnable, PllCfgBase, PllCfgSize},
  padframe: '{PadframeCfgEnable, PadframeCfgBase, PadframeCfgSize},
  l2ecc:    '{L2EccCfgEnable, L2EccCfgBase, L2EccCfgSize},
  ethernet: '{EthernetEnable, EthernetBase, EthernetSize}
};

localparam int unsigned NumSyncRegSlv = gen_num_regbus_sync_slave(CarfieldRegBusCfg);
localparam int unsigned NumAsyncRegSlv = gen_num_regbus_async_slave(CarfieldRegBusCfg);
localparam int unsigned NumTotalRegSlv = NumSyncRegSlv + NumAsyncRegSlv;

// Generate the IDs for each AXI slave device
// verilog_lint: waive-start line-length
function automatic carfield_regbus_slave_idx_t carfield_gen_regbus_slave_idx(regbus_cfg_t regbus_cfg);
// verilog_lint: waive-stop line-length
  carfield_regbus_slave_idx_t ret = '{default: '0}; // Initialize struct first
  byte_bt i = 0;
  byte_bt j = 0;
  if (regbus_cfg.pcrs.enable) begin ret.pcrs = i; i++;
  end else begin ret.pcrs = NumTotalRegSlv + j; j++; end
  if (regbus_cfg.pll.enable) begin ret.pll = i; i++;
  end else begin ret.pll = NumTotalRegSlv + j; j++; end
  if (regbus_cfg.padframe.enable) begin ret.padframe = i; i++;
  end else begin ret.padframe = NumTotalRegSlv + j; j++; end
  if (regbus_cfg.l2ecc.enable) begin ret.l2ecc = i; i++;
  end else begin ret.l2ecc = NumTotalRegSlv + j; j++; end
  if (regbus_cfg.ethernet.enable) begin ret.ethernet = i; i++;
  end else begin ret.ethernet = NumTotalRegSlv + j; j++; end
  return ret;
endfunction

typedef struct packed {
  byte_bt [NumTotalRegSlv-1:0] RegBusIdx;
  doub_bt [NumTotalRegSlv-1:0] RegBusStart;
  doub_bt [NumTotalRegSlv-1:0] RegBusEnd;
} regbus_struct_t;

// Compute RegBus memory map
function automatic regbus_struct_t carfield_gen_regbus_map(int unsigned NumSlave          ,
                                                           regbus_cfg_t regbus_cfg        ,
                                                           carfield_regbus_slave_idx_t idx);
  regbus_struct_t ret = '0; // Initialize the map first
  int unsigned i = 0;
  if (regbus_cfg.pcrs.enable) begin
    ret.RegBusIdx[i] = idx.pcrs;
    ret.RegBusStart[i] = regbus_cfg.pcrs.base;
    ret.RegBusEnd[i] = regbus_cfg.pcrs.base + regbus_cfg.pcrs.size;
    if (i < NumSlave - 1) i++;
  end
  if (regbus_cfg.pll.enable) begin
    ret.RegBusIdx[i] = idx.pll;
    ret.RegBusStart[i] = regbus_cfg.pll.base;
    ret.RegBusEnd[i] = regbus_cfg.pll.base + regbus_cfg.pll.size;
    if (i < NumSlave - 1) i++;
  end
  if (regbus_cfg.padframe.enable) begin
    ret.RegBusIdx[i] = idx.padframe;
    ret.RegBusStart[i] = regbus_cfg.padframe.base;
    ret.RegBusEnd[i] = regbus_cfg.padframe.base + regbus_cfg.padframe.size;
    if (i < NumSlave - 1) i++;
  end
  if (regbus_cfg.l2ecc.enable) begin
    ret.RegBusIdx[i] = idx.l2ecc;
    ret.RegBusStart[i] = regbus_cfg.l2ecc.base;
    ret.RegBusEnd[i] = regbus_cfg.l2ecc.base + regbus_cfg.l2ecc.size;
    if (i < NumSlave - 1) i++;
  end
  if (regbus_cfg.ethernet.enable) begin
    ret.RegBusIdx[i] = idx.ethernet;
    ret.RegBusStart[i] = regbus_cfg.ethernet.base;
    ret.RegBusEnd[i] = regbus_cfg.ethernet.base + regbus_cfg.ethernet.size;
    if (i < NumSlave - 1) i++;
  end
  return ret;
endfunction

// Generate number of existent domains
function automatic int unsigned gen_carfield_domains(islands_cfg_t island_cfg);
  int unsigned ret = 0; // Number of availale domains starts from 0
  if (island_cfg.l2_port0.enable) begin ret++; end
  if (island_cfg.safed.enable   ) begin ret++; end
  if (island_cfg.periph.enable  ) begin ret++; end
  if (island_cfg.spatz.enable   ) begin ret++; end
  if (island_cfg.pulp.enable    ) begin ret++; end
  if (island_cfg.secured.enable ) begin ret++; end
  return ret;
endfunction

// Possible clock domains are:
// - RT (fixed)
// - Host (fixed)
// - Alt (PULP Cluster, L2 Memory, Safety Island)
// - Fast (Snitch/Spatz/MAGIA)
// - Secure
// - Periph
// Generate number of clock sources
function automatic int unsigned gen_carfield_clock_srcs(islands_cfg_t island_cfg);
  int unsigned ret = 2; // Number of clock sources starts from 2 (Host + rt clock)
  if (island_cfg.safed.enable  ||
      island_cfg.pulp.enable   ||
      island_cfg.l2_port0.enable) begin ret++; end
  if (island_cfg.periph.enable  ) begin ret++; end
  if (island_cfg.secured.enable ) begin ret++; end
  if (island_cfg.spatz.enable   ) begin ret++; end
  return ret;
endfunction

localparam byte_bt RtClockIdx = 0;
localparam byte_bt HostClockIdx = 1;
typedef struct packed {
  byte_bt AltClockIdx;
  byte_bt PeriphClockIdx;
  byte_bt SecureClockIdx;
  byte_bt SpatzClockIdx;
} carfield_clock_idx_t;

function automatic int unsigned gen_carfield_clock_idx(islands_cfg_t island_cfg);
  carfield_clock_idx_t ret = '{default: '0};
  byte_bt i = 2;
  byte_bt j = 0;
  if (island_cfg.safed.enable  ||
      island_cfg.pulp.enable   ||
      island_cfg.l2_port0.enable) begin ret.AltClockIdx = i; i++; end
  else begin ret.AltClockIdx = RtClockIdx; end
  if (island_cfg.periph.enable  ) begin ret.PeriphClockIdx = i; i++; end
  else begin ret.PeriphClockIdx = RtClockIdx; end
  if (island_cfg.secured.enable ) begin ret.SecureClockIdx = i; i++; end
  else begin ret.SecureClockIdx = RtClockIdx; end
  if (island_cfg.spatz.enable   ) begin ret.SpatzClockIdx = i; i++; end
  else begin ret.SpatzClockIdx = RtClockIdx; end
  return ret;
endfunction

localparam islands_cfg_t CarfieldIslandsCfg = '{
  l2_port0:      '{L2Port0Enable, L2Port0Base, L2Port0Size},
  l2_port1:      '{L2Port1Enable, L2Port1Base, L2Port1Size},
  safed:         '{SafetyIslandEnable, SafetyIslandBase, SafetyIslandSize},
  ethernet:      '{EthernetEnable, EthernetBase, EthernetSize},
  periph:        '{PeriphEnable, PeriphBase, PeriphSize},
  spatz:         '{SpatzClusterEnable, SpatzClusterBase, SpatzClusterSize},
  pulp:          '{PulpClusterEnable, PulpClusterBase, PulpClusterSize},
  secured:       '{SecurityIslandEnable, SecurityIslandBase, SecurityIslandSize},
  mbox:          '{MailboxEnable, MailboxBase, MailboxSize}
};

localparam int unsigned CarfieldAxiNumSlaves  = gen_num_axi_slave(CarfieldIslandsCfg);
localparam carfield_slave_idx_t CarfieldAxiSlvIdx = carfield_gen_axi_slave_idx(CarfieldIslandsCfg);
localparam int unsigned CarfieldAxiNumMasters = gen_num_axi_master(CarfieldIslandsCfg);
localparam carfield_master_idx_t CarfieldMstIdx = carfield_gen_axi_master_idx(CarfieldIslandsCfg);

localparam axi_struct_t CarfieldAxiMap = carfield_gen_axi_map(CarfieldAxiNumSlaves,
                                                              CarfieldIslandsCfg  ,
                                                              CarfieldAxiSlvIdx   );
// verilog_lint: waive-start line-length
localparam carfield_regbus_slave_idx_t CarfieldRegBusSlvIdx = carfield_gen_regbus_slave_idx(CarfieldRegBusCfg);
// verilog_lint: waive-stop line-length

localparam regbus_struct_t CarfieldRegBusMap = carfield_gen_regbus_map(NumTotalRegSlv      ,
                                                                       CarfieldRegBusCfg   ,
                                                                       CarfieldRegBusSlvIdx);

localparam int unsigned CarfieldNumDomains = gen_carfield_domains(CarfieldIslandsCfg);

localparam int unsigned NumFll = gen_carfield_clock_srcs(CarfieldIslandsCfg);
localparam carfield_clock_idx_t CarfieldClockIdx = gen_carfield_clock_idx(CarfieldIslandsCfg);

typedef struct {
  int unsigned clock_div_value[CarfieldNumDomains];
} carfield_clk_div_values_t;

function automatic carfield_clk_div_values_t gen_carfield_clk_div_value(int unsigned num_domains);
  carfield_clk_div_values_t ret = '{default: '0};
  for (int i = 0; i < num_domains; i++) ret.clock_div_value[i] = 1;
  return ret;
endfunction

// verilog_lint: waive-start line-length
localparam carfield_clk_div_values_t CarfieldClkDivValue = gen_carfield_clk_div_value(CarfieldNumDomains);
// verilog_lint: waive-stop line-length

typedef struct packed {
  byte_bt l2;
  byte_bt spatz;
  byte_bt pulp;
  byte_bt secured;
  byte_bt safed;
  byte_bt periph;
  byte_bt ethernet;
} carfield_domain_idx_t;

function automatic carfield_domain_idx_t gen_domain_idx(islands_cfg_t island_cfg);
  carfield_domain_idx_t ret = '{default: '0};
  int unsigned i = 0;
  if (island_cfg.periph.enable   ) begin ret.periph  = i; i++; end
  if (island_cfg.safed.enable    ) begin ret.safed   = i; i++; end
  if (island_cfg.secured.enable  ) begin ret.secured = i; i++; end
  if (island_cfg.pulp.enable     ) begin ret.pulp    = i; i++; end
  if (island_cfg.spatz.enable    ) begin ret.spatz   = i; i++; end
  if (island_cfg.l2_port0.enable ) begin ret.l2      = i; i++; end
  return ret;
endfunction

localparam carfield_domain_idx_t CarfieldDomainIdx = gen_domain_idx(CarfieldIslandsCfg);

/*******************************
* Carfield package starts here *
*******************************/
localparam int unsigned CheshireNumInternalHarts = 1;
localparam bit CheshireSerialLinkEnable = 0;
localparam int unsigned CarfieldNumExtIntrs           = 32; // Number of external interrupts
localparam int unsigned CarfieldNumInterruptibleHarts = 2;  // Spatz (2 Snitch cores)
localparam int unsigned CarfieldNumRouterTargets      = 1;  // Safety Island

typedef enum int {
  FPClusterIntrHart0Idx = 'd0,
  FPClusterIntrHart1Idx = 'd1,
  SafedIntrHartIdx      = 'd2
} carfield_ext_intr_harts_e;

// Clock dividers integer value after PoR
localparam int unsigned PeriphDomainClkDivValue     = 1;
localparam int unsigned SafedDomainClkDivValue      = 1;
localparam int unsigned SecdDomainClkDivValue       = 1;
localparam int unsigned IntClusterDomainClkDivValue = 1;
localparam int unsigned FPClusterDomainClkDivValue  = 1;
localparam int unsigned L2DomainClkDivValue         = 1;

typedef enum byte_bt {
  L2Port0SlvIdx      = CarfieldAxiSlvIdx.l2_port0,
  L2Port1SlvIdx      = CarfieldAxiSlvIdx.l2_port1,
  SafetyIslandSlvIdx = CarfieldAxiSlvIdx.safed,
  PeriphsSlvIdx      = CarfieldAxiSlvIdx.periph,
  FPClusterSlvIdx    = CarfieldAxiSlvIdx.spatz,
  IntClusterSlvIdx   = CarfieldAxiSlvIdx.pulp,
  MailboxSlvIdx      = CarfieldAxiSlvIdx.mbox
} axi_slv_idx_t;

typedef enum byte_bt {
  SafetyIslandMstIdx       = CarfieldMstIdx.safed,
  SecurityIslandTlulMstIdx = CarfieldMstIdx.secured,
  SecurityIslandiDMAMstIdx = CarfieldMstIdx.secured_idma,
  FPClusterMstIdx          = CarfieldMstIdx.spatz,
  IntClusterMstIdx         = CarfieldMstIdx.pulp,
  EthernetMstIdx           = CarfieldMstIdx.ethernet
} axi_mst_idx_t;

// APB peripherals
localparam int unsigned CarfieldNumAdvTimerIntrs  = 4;
localparam int unsigned CarfieldNumAdvTimerEvents = 4;
localparam int unsigned CarfieldNumSysTimerIntrs  = 2;
localparam int unsigned CarfieldNumTimerIntrs = CarfieldNumAdvTimerIntrs +
                        CarfieldNumAdvTimerEvents + CarfieldNumSysTimerIntrs;
localparam int unsigned CarfieldNumWdtIntrs = 5;
localparam int unsigned CarfieldNumCanIntrs = 1;
localparam int unsigned CarfieldNumEthIntrs = 1;
localparam int unsigned CarfieldNumPeriphsIntrs = CarfieldNumTimerIntrs +
                        CarfieldNumWdtIntrs + CarfieldNumCanIntrs + CarfieldNumEthIntrs;

// Synchronization stages (for FIFOs read/write pointers and single-bit signals syncronization after
// CDCs)
localparam int unsigned SyncStages = 3;

// Hart IDs
typedef bit [5:0] hartid_t;

typedef enum hartid_t {
  ChsHartIdOffs       = 'd0 ,
  OpnTitHartIdOffs    = 'd4 ,
  SafetyIslHartIdOffs = 'd8 ,
  SpatzHartIdOffs     = 'd16,
  PulpHartIdOffs      = 'd32
} hartid_offs_e;


localparam int unsigned MaxHartId = 63;
localparam int unsigned IntClusterNumCores = 8;
localparam bit [MaxHartId:0] SafetyIslandExtHarts =
  {MaxHartId+1{1'b0}} | (((1<<IntClusterNumCores) - 1) << PulpHartIdOffs);

localparam dm::hartinfo_t PulpHartInfo = '{
  zero1: '0,
  nscratch: 2,
  zero0: '0,
  dataaccess: 1'b1,
  datasize: dm::DataCount,
  dataaddr: dm::DataAddr
};
function automatic dm::hartinfo_t [MaxHartId:0] pulp_hart_info(bit [MaxHartId:0] available);
  for (int i = 0; i <= MaxHartId; i++) begin
    if (available[i]) begin
      pulp_hart_info[i] = PulpHartInfo;
    end else begin
      pulp_hart_info[i] = '0;
    end
  end
endfunction

localparam dm::hartinfo_t [MaxHartId:0] SafetyIslandExtHartinfo =
  carfield_pkg::pulp_hart_info(SafetyIslandExtHarts);

// Safety island configuration
`ifdef SAFED_ENABLE
  localparam bit [31:0] SafedDebugOffs          = safety_island_pkg::DebugAddrOffset;
  localparam int unsigned SafetyIslandMemOffset = 'h0000_0000;
  localparam int unsigned SafetyIslandPerOffset = 'h0020_0000;
  localparam safety_island_pkg::safety_island_cfg_t SafetyIslandCfg = '{
      HartId:             carfield_pkg::SafetyIslHartIdOffs,
      BankNumBytes:       32'h0001_0000,
      NumBanks:           2,
      // JTAG ID code:
      // LSB                        [0]:     1'h1
      // PULP Platform Manufacturer [11:1]:  11'h6d9
      // Part Number                [27:12]: 16'hca71
      // Version                    [31:28]: 4'h1
      PulpJtagIdCode:     32'h1_ca71_db3,
      NumTimers:          1,
      UseClic:            1,
      ClicIntCtlBits:     8,
      UseSSClic:          0,
      UseUSClic:          0,
      UseVSClic:          0,
      UseVSPrio:          0,
      NVsCtxts:           0,
      UseFastIrq:         1,
      UseFpu:             1,
      UseIntegerCluster:  1,
      UseXPulp:           1,
      UseZfinx:           1,
      UseTCLS:            1,
      NumInterrupts:      128,
      NumMhpmCounters:    1,
      // All non-set values should be zero
      default: '0
  };
  localparam int unsigned SafetyIslandIrqs = SafetyIslandCfg.NumInterrupts;
  localparam safety_island_pkg::bootmode_e SafetyIslandPreloaded = safety_island_pkg::Preloaded;
`else
  localparam int unsigned SafetyIslandCfg = '0;
  localparam bit [31:0] SafedDebugOffs          = 0;
  localparam int unsigned SafetyIslandMemOffset = 0;
  localparam int unsigned SafetyIslandPerOffset = 0;
  localparam int unsigned SafetyIslandIrqs = 1;
  localparam int unsigned SafetyIslandPreloaded = 0;
`endif

// Compute the number of atomic MSBs depending on the configuration
function automatic dw_bt carfield_get_axi_user_amo_msb(islands_cfg_t island_cfg,
                                                       int unsigned CheshireNumHarts,
                                                       bit SerialLinkEnabled);
  dw_bt ret = '{default: 0}; // Initialize value
  int unsigned i = CheshireNumHarts; // Start with the number of Cheshire internal Harts
  if (SerialLinkEnabled) i += 1;
  if (island_cfg.safed.enable) i += 1;
  if (island_cfg.spatz.enable) i += 1;
  ret = $clog2(i);
  return ret;
endfunction

localparam dw_bt AxiUserAmoMsb = carfield_get_axi_user_amo_msb(CarfieldIslandsCfg,
                                                               CheshireNumInternalHarts,
                                                               CheshireSerialLinkEnable);

// verilog_lint: waive-start line-length
// Cheshire configuration
function automatic cheshire_pkg::cheshire_cfg_t gen_carfield_cfg();
  cheshire_pkg::cheshire_cfg_t ret = cheshire_pkg::DefaultCfg;
  // CVA6 parameters
  ret.Cva6RASDepth      = cva6_config_pkg::cva6_cfg.RASDepth;
  ret.Cva6BTBEntries    = cva6_config_pkg::cva6_cfg.BTBEntries;
  ret.Cva6BHTEntries    = cva6_config_pkg::cva6_cfg.BHTEntries;
  ret.Cva6NrPMPEntries  = 0;
  ret.Cva6ExtCieLength  = 'h1000_0000; // [0x2000_0000, 0x7000_0000) is non-CIE,
                                   // [0x7000_0000, 0x8000_0000) is CIE
  ret.Cva6ExtCieOnTop   = 1;
  // Harts
  ret.NumCores          = CheshireNumInternalHarts;
  ret.CoreMaxTxns       = 8;
  ret.CoreMaxTxnsPerId  = 4;
  ret.CoreUserAmoOffs   = 0; // Convention: lower AMO bits for cores, MSB for serial link
  // Interrupt parameters
  ret.NumExtIrqHarts    = CarfieldNumInterruptibleHarts;
  ret.NumExtInIntrs     = CarfieldNumExtIntrs;
  ret.NumExtClicIntrs   = CarfieldNumExtIntrs;
  ret.NumExtOutIntrTgts = CarfieldNumRouterTargets;
  ret.NumExtOutIntrs    = CarfieldNumExtIntrs+$bits(cheshire_int_intr_t);
  ret.ClicIntCtlBits    = 8;
  // ClicUseSMode      : 1,
  // ClicUseUMode      : 0,
  // ClicUseVsMode     : 1,
  // ClicUseVsModePrio : 1,
  // ClicNumVsCtxts    : 2, // TODO: choose appropriately
  ret.NumExtIntrSyncs   = SyncStages;
  // Interconnect
  ret.AddrWidth         = 48;
  ret.AxiDataWidth      = 64;
  ret.AxiUserWidth      = 10;  // {CACHE_PARTITIONING(5[9:5]), ECC_ERROR(1[4:4]), ATOPS(4[3:0])}
  ret.AxiMstIdWidth     = 2;
  // TFLenWidth        : 32, // ?
  ret.AxiMaxMstTrans    = 64;
  ret.AxiMaxSlvTrans    = 64;
  ret.AxiUserAmoMsb     = AxiUserAmoMsb; // A0:0001, A1:0011, SF:0101, FP:0111, SL:1XXX, none: '0
  ret.AxiUserAmoLsb     = 0;             // A0:0001, A1:0011, SF:0101, FP:0111, SL:1XXX, none: '0
  ret.AxiUserErrBits    = 1;
  ret.AxiUserErrLsb     = 4;
  ret.RegMaxReadTxns    = 8;
  ret.RegMaxWriteTxns   = 8;
  // CorePostCut       : 1, // ?
  ret.RegAmoNumCuts     = 1;
  ret.RegAmoPostCut     = 1;
  ret.RegAdaptMemCut    = 1;
  // External AXI ports (at most 8 ports and rules)
  ret.AxiExtNumMst      = CarfieldAxiNumMasters;
  ret.AxiExtNumSlv      = CarfieldAxiNumSlaves;
  ret.AxiExtNumRules    = CarfieldAxiNumSlaves;
  // External AXI region map
  ret.AxiExtRegionIdx   = CarfieldAxiMap.AxiIdx;
  ret.AxiExtRegionStart = CarfieldAxiMap.AxiStart;
  ret.AxiExtRegionEnd   = CarfieldAxiMap.AxiEnd;
  // External reg slaves (at most 8 ports and rules)
  ret.RegExtNumSlv      = NumTotalRegSlv;
  ret.RegExtNumRules    = NumTotalRegSlv;
  // For carfield, PllIdx is the first index of the async reg interfaces. Please add async reg
  // interfaces indices to the left of PllIdx, and sync reg interface indices to its right.
  ret.RegExtRegionIdx   = CarfieldRegBusMap.RegBusIdx;
  ret.RegExtRegionStart = CarfieldRegBusMap.RegBusStart;
  ret.RegExtRegionEnd   = CarfieldRegBusMap.RegBusEnd;
  // RTC
  ret.RtcFreq           = 1000000; // FIXME
  // Features
  ret.Bootrom           = 1;
  ret.Uart              = 1;
  ret.I2c               = 1;
  ret.SpiHost           = 1;
  ret.Gpio              = 1;
  ret.Dma               = 1;
  // IOMMU             : 1,
  ret.SerialLink        = CheshireSerialLinkEnable;
  ret.Vga               = 0;
  ret.AxiRt             = 0;
  ret.Clic              = 0;
  ret.IrqRouter         = 1;
  ret.BusErr            = 0;
  ret.Snooper           = 1;
  // HmrUnit           : 1,
  // Cva6DMR           : 1,
  // Cva6DMRFixed      : 0,
  // RapidRecovery     : 0,
  // Debug
  ret.DbgIdCode         = '{
      version: 4'h1,
      part_num: 16'hca70,
      manufacturer: JtagPulpManufacturer,
      _one: 1
    };
  ret.DbgMaxReqs        = 4;
  ret.DbgMaxReadTxns    = 4;
  ret.DbgMaxWriteTxns   = 4;
  ret.DbgAmoNumCuts     = 1;
  ret.DbgAmoPostCut     = 1;
  // LLC: 128 KiB, up to 2 GiB DRAM
  ret.LlcNotBypass      = 1;
  ret.LlcSetAssoc       = 8;
  ret.LlcNumLines       = 256;
  ret.LlcNumBlocks      = 8;
  ret.LlcMaxReadTxns    = 32;
  ret.LlcMaxWriteTxns   = 32;
  ret.LlcAmoNumCuts     = 1;
  ret.LlcAmoPostCut     = 1;
  ret.LlcOutConnect     = 1;
  ret.LlcOutRegionStart = 'h8000_0000;
  ret.LlcOutRegionEnd   = 'h1_0000_0000;
  // LlcUserMsb        : 9,
  // LlcUserLsb        : 5,
  // LlcCachePartition : 1,
  // LlcMaxPartition   : 16,
  // LlcRemapHash      : axi_llc_pkg::Modulo,
  // VGA: RGB332; carfield doesn't have a vga, but widths are required for top-level pins anyway.
  ret.VgaRedWidth       = 3;
  ret.VgaGreenWidth     = 3;
  ret.VgaBlueWidth      = 2;
  // Serial Link: map other chip's lower 32bit to 'h1_000_0000
  ret.SlinkMaxTxnsPerId = 4;
  ret.SlinkMaxUniqIds   = 4;
  ret.SlinkMaxClkDiv    = 1024;
  ret.SlinkRegionStart  = 'h1_0000_0000;
  ret.SlinkRegionEnd    = 'h2_0000_0000;
  ret.SlinkTxAddrMask   = 'hFFFF_FFFF;
  ret.SlinkTxAddrDomain = 'h0000_0000;
  ret.SlinkUserAmoBit   = 3;  // Convention: lower AMO bits for cores, MSB for serial link
  // DMA config
  ret.DmaConfMaxReadTxns  = 4;
  ret.DmaConfMaxWriteTxns = 4;
  ret.DmaConfAmoNumCuts   = 1;
  ret.DmaNumAxInFlight    = 24;
  ret.DmaMemSysDepth      = 16;
  ret.DmaJobFifoDepth     = 4;
  ret.DmaRAWCouplingAvail = 1;
  ret.DmaConfAmoPostCut   = 1;
  ret.DmaConfEnableTwoD   = 1;
  // GPIOs
  ret.GpioInputSyncs      = 1;
  // AXI RT
  ret.AxiRtNumPending     = 32;
  ret.AxiRtWBufferDepth   = 32;
  ret.AxiRtNumAddrRegions = 2;
  ret.AxiRtCutPaths       = 1;
  ret.AxiRtEnableChecks   = 0;

  return ret;
endfunction // gen_carfield_cfg
localparam cheshire_cfg_t CarfieldCfgDefault = gen_carfield_cfg();
// verilog_lint: waive-stop line-length
/***********************/
/* Ethernet Parameters */
/***********************/
localparam int unsigned EthTxFifoLogDepth   = 2;
localparam int unsigned EthRxFifoLogDepth   = 3;
localparam int unsigned EthDmaNumAxInFlight = 15;
localparam int unsigned EthDmaBufferDepth   = 2;
localparam int unsigned EthDmaTFLenWidth    = 20;
localparam int unsigned EthDmaMemSysDepth   = 0;

// CDC FIFO parameters (FIFO depth).
localparam int unsigned LogDepth   = 3;

/*****************/
/* L2 Parameters */
/*****************/
localparam int unsigned NumL2Ports = (CarfieldIslandsCfg.l2_port1.enable) ? 2 : 1;
localparam int unsigned L2MemSize = CarfieldIslandsCfg.l2_port0.size;
localparam int unsigned L2NumRules = 4; // 2 rules per each access mode
                                        // (interleaved, non-interleaved)
localparam doub_bt L2Port0InterlBase = CarfieldIslandsCfg.l2_port0.base;
localparam doub_bt L2Port1InterlBase = CarfieldIslandsCfg.l2_port1.base;
localparam doub_bt L2Port0NonInterlBase = CarfieldIslandsCfg.l2_port0.base + L2MemSize/2;
localparam doub_bt L2Port1NonInterlBase = CarfieldIslandsCfg.l2_port1.base + L2MemSize/2;

/******************************/
/* Integer Cluster Parameters */
/******************************/
localparam bit[CarfieldCfgDefault.AddrWidth-1:0] PulpClustPeriphOffs = 'h00200000;
localparam bit[CarfieldCfgDefault.AddrWidth-1:0] PulpClustExtOffs    = 'h00400000;
localparam int unsigned IntClusterNumEoc = 1;
localparam logic [ 5:0] IntClusterIndex = (PulpHartIdOffs >> 5);
`ifdef PULPD_ENABLE
  localparam pulp_cluster_package::pulp_cluster_cfg_t PulpClusterCfg = '{
    CoreType: pulp_cluster_package::RI5CY,
    NumCores: IntClusterNumCores,
    DmaNumPlugs: 4,
    DmaNumOutstandingBursts: 8,
    DmaBurstLength: 256,
    NumMstPeriphs: 1,
    NumSlvPeriphs: 12,
    ClusterAlias: 1,
    ClusterAliasBase: 'h0,
    NumSyncStages: 3,
    UseHci: 1,
    TcdmSize: 128*1024,
    TcdmNumBank: 16,
    HwpePresent: 1,
    HwpeCfg: '{NumHwpes: 3,
               HwpeList: {pulp_cluster_package::SOFTEX,
                          pulp_cluster_package::NEUREKA,
                          pulp_cluster_package::REDMULE}
              },
    HwpeNumPorts: 9,
    HMRPresent: 1,
    HMRDmrEnabled: 1,
    HMRTmrEnabled: 1,
    HMRDmrFIxed: 0,
    HMRTmrFIxed: 0,
    HMRInterleaveGrps: 1,
    HMREnableRapidRecovery: 1,
    HMRSeparateDataVoters: 1,
    HMRSeparateAxiBus: 0,
    HMRNumBusVoters: 1,
    EnableECC: 1,
    ECCInterco: 1,
    iCacheNumBanks: 2,
    iCacheNumLines: 1,
    iCacheNumWays: 4,
    iCacheSharedSize: 4*1024,
    iCachePrivateSize: 512,
    iCachePrivateDataWidth: 32,
    EnableReducedTag: 1,
    L2Size: L2MemSize,
    DmBaseAddr: carfield_pkg::CarfieldIslandsCfg.safed.base+
                carfield_pkg::SafetyIslandPerOffset +
                carfield_pkg::SafedDebugOffs,
    BootRomBaseAddr: carfield_pkg::CarfieldIslandsCfg.l2_port0.base + 'h8080,
    BootAddr: carfield_pkg::CarfieldIslandsCfg.l2_port0.base + 'h8080,
    EnablePrivateFpu: 1,
    EnablePrivateFpDivSqrt: 0,
    EnableSharedFpu: 0,
    EnableSharedFpDivSqrt: 0,
    NumSharedFpu: 0,
    NumAxiIn: 4,
    NumAxiOut: 3,
    AxiIdInWidth: AxiSlvIdWidth,
    AxiIdOutWidth: Cfg.AxiMstIdWidth,
    AxiAddrWidth: Cfg.AddrWidth,
    AxiDataInWidth:  Cfg.AxiDataWidth,
    AxiDataOutWidth: Cfg.AxiDataWidth,
    AxiUserWidth: Cfg.AxiUserWidth,
    AxiMaxInTrans: Cfg.AxiMaxSlvTrans,
    AxiMaxOutTrans: Cfg.AxiMaxMstTrans,
    AxiCdcLogDepth: 3,
    AxiCdcSyncStages: carfield_pkg::SyncStages,
    SyncStages: carfield_pkg::SyncStages,
    ClusterBaseAddr: carfield_pkg::CarfieldAxiMap.AxiStart[CarfieldAxiSlvIdx.pulp]
                     - (carfield_pkg::IntClusterIndex << 22),
    ClusterPeriphOffs: carfield_pkg::PulpClustPeriphOffs,
    ClusterExternalOffs: carfield_pkg::PulpClustExtOffs,
    EnableRemapAddress: 0,
    SnitchICache: 0,
    default: '0
  };
`else
  localparam int unsigned PulpClusterCfg = 0;
`endif

/****************************/
/* Spatz Cluster Parameters */
/****************************/
`ifdef SPATZ_ENABLE
  localparam int unsigned SpatzNumIntHarts = spatz_cluster_pkg::NumCores;
  localparam int unsigned SpatzClusterPeriphStartAddr = spatz_cluster_pkg::PeriStartAddr;
  localparam int unsigned SpatzClusterPeripheralBootControlOffset =
  spatz_cluster_peripheral_reg_pkg::SPATZ_CLUSTER_PERIPHERAL_CLUSTER_BOOT_CONTROL_OFFSET;
  localparam int unsigned SpatzClusterPeripheralsEocOffset =
  spatz_cluster_peripheral_reg_pkg::SPATZ_CLUSTER_PERIPHERAL_CLUSTER_EOC_EXIT_OFFSET;
`else
  localparam int unsigned SpatzNumIntHarts = 0;
  localparam int unsigned SpatzClusterPeriphStartAddr = 0;
  localparam int unsigned SpatzClusterPeripheralBootControlOffset = 0;
  localparam int unsigned SpatzClusterPeripheralsEocOffset = 0;
`endif

/*******************************/
/* Narrow Parameters: A32, D32 */
/*******************************/
localparam int unsigned AxiNarrowAddrWidth = 32;
localparam int unsigned AxiNarrowDataWidth = 32;
localparam int unsigned AxiNarrowStrobe    = AxiNarrowDataWidth/8;

// Narrow AXI types
typedef logic [     AxiNarrowAddrWidth-1:0] car_nar_addrw_t;
typedef logic [     AxiNarrowDataWidth-1:0] car_nar_dataw_t;
typedef logic [        AxiNarrowStrobe-1:0] car_nar_strb_t;

// APB Mapping
localparam int unsigned NumApbMst = 5;

typedef enum int {
  SystemTimerIdx   = 'd0,
  AdvancedTimerIdx = 'd1,
  SystemWdtIdx     = 'd2,
  CanIdx           = 'd3,
  HyperBusIdx      = 'd4
} carfield_peripherals_e;

// Address map of peripheral system
typedef struct packed {
  logic [31:0] idx;
  car_nar_addrw_t start_addr;
  car_nar_addrw_t end_addr;
} carfield_addr_map_rule_t;

localparam carfield_addr_map_rule_t [NumApbMst-1:0] PeriphApbAddrMapRule = '{
  // 0: System Timer
  '{ idx: SystemTimerIdx,   start_addr: SystemTimerBase,
                            end_addr: SystemTimerBase + SystemTimerSize  },
  // 1: Advanced Timer
  '{ idx: AdvancedTimerIdx, start_addr: SystemAdvancedTimerBase,
                            end_addr: SystemAdvancedTimerBase + SystemAdvancedTimerSize },
  // 2: WDT
  '{ idx: SystemWdtIdx,     start_addr: SystemWatchdogBase,
                            end_addr: SystemWatchdogBase + SystemWatchdogSize },
  // 3: Can
  '{ idx: CanIdx,           start_addr: CanBase,
                            end_addr: CanBase + CanSize },
  // 4: Hyperbus
  '{ idx: HyperBusIdx,      start_addr: HyperBusBase,
                            end_addr: HyperBusBase + HyperBusSize }
};

// Narrow reg types
`REG_BUS_TYPEDEF_ALL(carfield_a32_d32_reg, car_nar_addrw_t, car_nar_dataw_t, car_nar_strb_t)


//////////////////////////////
// Debug Signal Port Struct //
//////////////////////////////


// 6 clock gateable Subdomains in Carfield: periph_domain, safety_island, security_isalnd, spatz &
// pulp_cluster, L2 shared memory
localparam int unsigned NumDomains = CarfieldNumDomains;

typedef struct packed {
  logic [NumDomains-1:0] domain_clk;
  logic [NumDomains-1:0] domain_rsts_n;
  logic                  host_pwr_on_rst_n;
} carfield_debug_sigs_t;

endpackage
