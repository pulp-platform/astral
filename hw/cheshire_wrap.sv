// Copyright 2023 ETH Zurich and University of Bologna.
// Solderpad Hardware License, Version 0.51, see LICENSE for details.
// SPDX-License-Identifier: SHL-0.51
//
// Luca Valente    <luca.valente@unibo.it>
// Yvan Tortorella <yvan.tortorella@unibo.it>
// Alessandro Ottaviano <aottaviano@ii.ee.ethz.ch>

`include "cheshire/typedef.svh"
 `include "axi/typedef.svh"
 `include "axi/assign.svh"

module cheshire_wrap
  import axi_pkg::*;
  import carfield_pkg::*;
  import cheshire_pkg::*;
#(
  parameter cheshire_cfg_t Cfg = '0,
  parameter dm::hartinfo_t [iomsb(Cfg.NumExtDbgHarts)-1:0] ExtHartinfo = '0,
  parameter int unsigned NumExtIntrs            = 32,
  parameter axi_in_t     AxiIn  = gen_axi_in(Cfg) ,
  parameter axi_out_t    AxiOut = gen_axi_out(Cfg),
  parameter type cheshire_axi_ext_llc_ar_chan_t = logic,
  parameter type cheshire_axi_ext_llc_aw_chan_t = logic,
  parameter type cheshire_axi_ext_llc_b_chan_t  = logic,
  parameter type cheshire_axi_ext_llc_r_chan_t  = logic,
  parameter type cheshire_axi_ext_llc_w_chan_t  = logic,
  parameter type cheshire_axi_ext_llc_req_t     = logic,
  parameter type cheshire_axi_ext_llc_rsp_t     = logic,
  parameter type cheshire_axi_ext_mst_ar_chan_t = logic,
  parameter type cheshire_axi_ext_mst_aw_chan_t = logic,
  parameter type cheshire_axi_ext_mst_b_chan_t  = logic,
  parameter type cheshire_axi_ext_mst_r_chan_t  = logic,
  parameter type cheshire_axi_ext_mst_w_chan_t  = logic,
  parameter type cheshire_axi_ext_mst_req_t     = logic,
  parameter type cheshire_axi_ext_mst_rsp_t     = logic,
  parameter type cheshire_axi_ext_slv_ar_chan_t = logic,
  parameter type cheshire_axi_ext_slv_aw_chan_t = logic,
  parameter type cheshire_axi_ext_slv_b_chan_t  = logic,
  parameter type cheshire_axi_ext_slv_r_chan_t  = logic,
  parameter type cheshire_axi_ext_slv_w_chan_t  = logic,
  parameter type cheshire_axi_ext_slv_req_t     = logic,
  parameter type cheshire_axi_ext_slv_rsp_t     = logic,
  parameter type cheshire_reg_ext_req_t         = logic,
  parameter type cheshire_reg_ext_rsp_t         = logic,
  parameter int unsigned LogDepth = 3,
  parameter int unsigned CdcSyncStages = 2,
  parameter int unsigned ExtSlvIdWidth = Cfg.AxiMstIdWidth   +
                                         $clog2(AxiIn.num_in),
  parameter int unsigned LlcIdWidth = ExtSlvIdWidth   +
                                      Cfg.LlcNotBypass,
  // LLC Parameters
  parameter int unsigned LlcArWidth = (2**LogDepth)*
                                       axi_pkg::ar_width(Cfg.AddrWidth   ,
                                                         LlcIdWidth      ,
                                                         Cfg.AxiUserWidth),
  parameter int unsigned LlcAwWidth = (2**LogDepth)*
                                       axi_pkg::aw_width(Cfg.AddrWidth    ,
                                                         LlcIdWidth       ,
                                                         Cfg.AxiUserWidth),
  parameter int unsigned LlcBWidth  = (2**LogDepth)*
                                       axi_pkg::b_width(LlcIdWidth       ,
                                                        Cfg.AxiUserWidth),
  parameter int unsigned LlcRWidth  = (2**LogDepth)*
                                       axi_pkg::r_width(Cfg.AxiDataWidth ,
                                                        LlcIdWidth       ,
                                                        Cfg.AxiUserWidth),
  parameter int unsigned LlcWWidth  = (2**LogDepth)*
                                       axi_pkg::w_width(Cfg.AxiDataWidth ,
                                                        Cfg.AxiUserWidth),
  // External Slaves Parameters
  localparam int unsigned ExtSlvArWidth = (2**LogDepth)*
                                           axi_pkg::ar_width(Cfg.AddrWidth  ,
                                                            ExtSlvIdWidth   ,
                                                            Cfg.AxiUserWidth),
  localparam int unsigned ExtSlvAwWidth = (2**LogDepth)*
                                           axi_pkg::aw_width(Cfg.AddrWidth  ,
                                                            ExtSlvIdWidth   ,
                                                            Cfg.AxiUserWidth),
  localparam int unsigned ExtSlvBWidth  = (2**LogDepth)*
                                           axi_pkg::b_width(ExtSlvIdWidth   ,
                                                            Cfg.AxiUserWidth),
  localparam int unsigned ExtSlvRWidth  = (2**LogDepth)*
                                          axi_pkg::r_width(Cfg.AxiDataWidth,
                                                           ExtSlvIdWidth   ,
                                                           Cfg.AxiUserWidth),
  localparam int unsigned ExtSlvWWidth  = (2**LogDepth)*
                                           axi_pkg::w_width(Cfg.AxiDataWidth,
                                                            Cfg.AxiUserWidth),
  // External Master Parameters
  localparam int unsigned ExtMstArWidth = (2**LogDepth)*
                                           axi_pkg::ar_width(Cfg.AddrWidth    ,
                                                             Cfg.AxiMstIdWidth,
                                                             Cfg.AxiUserWidth ),
  localparam int unsigned ExtMstAwWidth = (2**LogDepth)*
                                           axi_pkg::aw_width(Cfg.AddrWidth    ,
                                                             Cfg.AxiMstIdWidth,
                                                             Cfg.AxiUserWidth ),
  localparam int unsigned ExtMstBWidth  = (2**LogDepth)*
                                           axi_pkg::b_width(Cfg.AxiMstIdWidth,
                                                            Cfg.AxiUserWidth ),
  localparam int unsigned ExtMstRWidth  = (2**LogDepth)*
                                           axi_pkg::r_width(Cfg.AxiDataWidth ,
                                                            Cfg.AxiMstIdWidth,
                                                            Cfg.AxiUserWidth ),
  localparam int unsigned ExtMstWWidth  = (2**LogDepth)*
                                           axi_pkg::w_width(Cfg.AxiDataWidth,
                                                            Cfg.AxiUserWidth)
)(
  input  logic        clk_i      ,
  input  logic        rst_ni     ,
  input  logic        test_mode_i,
  input  logic [1:0]  boot_mode_i,
  input  logic        rtc_i      ,
  // External AXI LLC (DRAM) port
  input  logic                  axi_llc_isolate_i,
  output logic                  axi_llc_isolated_o,
  // External async AXI slave Ports (except the Mailbox)
  output cheshire_axi_ext_slv_req_t [1:0] axi_ext_slv_req_o,
  input  cheshire_axi_ext_slv_rsp_t [1:0] axi_ext_slv_rsp_i,
  // External async AXI master Ports
  input  cheshire_axi_ext_mst_req_t axi_ext_mst_req_i,
  output cheshire_axi_ext_mst_rsp_t axi_ext_mst_rsp_o,
  // External reg demux slaves Cheshire's clock domain (sync)
  output cheshire_reg_ext_req_t [iomsb(NumSyncRegSlv):0] reg_ext_slv_req_o,
  input  cheshire_reg_ext_rsp_t [iomsb(NumSyncRegSlv):0] reg_ext_slv_rsp_i,
  // External reg demux slaves other clock domains (async)
  // Padframe and PLL
  output logic                  [NumAsyncRegSlv-1:0] ext_reg_async_slv_req_o,
  input  logic                  [NumAsyncRegSlv-1:0] ext_reg_async_slv_ack_i,
  output cheshire_reg_ext_req_t [NumAsyncRegSlv-1:0] ext_reg_async_slv_data_o,
  input  logic                  [NumAsyncRegSlv-1:0] ext_reg_async_slv_req_i,
  output logic                  [NumAsyncRegSlv-1:0] ext_reg_async_slv_ack_o,
  input  cheshire_reg_ext_rsp_t [NumAsyncRegSlv-1:0] ext_reg_async_slv_data_i,
  // Interrupts from external devices
  input  logic [iomsb(Cfg.NumExtInIntrs):0]                                  intr_ext_i,
  output logic [iomsb(Cfg.NumExtOutIntrTgts):0][iomsb(Cfg.NumExtOutIntrs):0] intr_ext_o,
  // Interrupts to external harts
  output logic [iomsb(NumIrqCtxts*Cfg.NumExtIrqHarts):0] xeip_ext_o,
  output logic [iomsb(Cfg.NumExtIrqHarts):0]             mtip_ext_o,
  output logic [iomsb(Cfg.NumExtIrqHarts):0]             msip_ext_o,
  // Debug interface to external harts
  output logic                               dbg_active_o,
  output logic [iomsb(Cfg.NumExtDbgHarts):0] dbg_ext_req_o,
  input  logic [iomsb(Cfg.NumExtDbgHarts):0] dbg_ext_unavail_i,
  // JTAG interface
  input  logic jtag_tck_i,
  input  logic jtag_trst_ni,
  input  logic jtag_tms_i,
  input  logic jtag_tdi_i,
  output logic jtag_tdo_o,
  output logic jtag_tdo_oe_o,
  // UART interface
  output logic uart_tx_o,
  input  logic uart_rx_i,
  // UART Modem flow control
  output logic uart_rts_no,
  output logic uart_dtr_no,
  input  logic uart_cts_ni,
  input  logic uart_dsr_ni,
  input  logic uart_dcd_ni,
  input  logic uart_rin_ni,
  // I2C interface
  output logic i2c_sda_o,
  input  logic i2c_sda_i,
  output logic i2c_sda_en_o,
  output logic i2c_scl_o,
  input  logic i2c_scl_i,
  output logic i2c_scl_en_o,
  // SPI host interface
  output logic                 spih_sck_o,
  output logic                 spih_sck_en_o,
  output logic [SpihNumCs-1:0] spih_csb_o,
  output logic [SpihNumCs-1:0] spih_csb_en_o,
  output logic [ 3:0]          spih_sd_o,
  output logic [ 3:0]          spih_sd_en_o,
  input  logic [ 3:0]          spih_sd_i,
  // GPIO interface
  input  logic [31:0] gpio_i,
  output logic [31:0] gpio_o,
  output logic [31:0] gpio_en_o,
  // Serial link interface
  input  logic [SlinkNumChan-1:0]                    slink_rcv_clk_i,
  output logic [SlinkNumChan-1:0]                    slink_rcv_clk_o,
  input  logic [SlinkNumChan-1:0][SlinkNumLanes-1:0] slink_i,
  output logic [SlinkNumChan-1:0][SlinkNumLanes-1:0] slink_o,
  // VGA interface
  output logic                         vga_hsync_o,
  output logic                         vga_vsync_o,
  output logic [Cfg.VgaRedWidth  -1:0] vga_red_o,
  output logic [Cfg.VgaGreenWidth-1:0] vga_green_o,
  output logic [Cfg.VgaBlueWidth -1:0] vga_blue_o
);

// External LLC (DRAM) bus
cheshire_axi_ext_llc_req_t axi_llc_mst_req, axi_llc_mst_isolated_req;
cheshire_axi_ext_llc_rsp_t axi_llc_mst_rsp, axi_llc_mst_isolated_rsp;

cheshire_reg_ext_req_t [iomsb(Cfg.RegExtNumSlv):0] ext_reg_req;
cheshire_reg_ext_rsp_t [iomsb(Cfg.RegExtNumSlv):0] ext_reg_rsp;

// Generate synchronous external register interface from Cheshire
for (genvar i = 0; i < NumSyncRegSlv; i++) begin: gen_ext_reg_sync
  assign reg_ext_slv_req_o[i] = ext_reg_req[i];
  assign ext_reg_rsp[i]       = reg_ext_slv_rsp_i[i];
end

cheshire_soc #(
  .Cfg               ( Cfg                        ),
  .ExtHartinfo       ( '0                         ),
  .axi_ext_llc_req_t ( cheshire_axi_ext_llc_req_t ),
  .axi_ext_llc_rsp_t ( cheshire_axi_ext_llc_rsp_t ),
  .axi_ext_mst_req_t ( cheshire_axi_ext_mst_req_t ),
  .axi_ext_mst_rsp_t ( cheshire_axi_ext_mst_rsp_t ),
  .axi_ext_slv_req_t ( cheshire_axi_ext_slv_req_t ),
  .axi_ext_slv_rsp_t ( cheshire_axi_ext_slv_rsp_t ),
  .reg_ext_req_t     ( cheshire_reg_ext_req_t     ),
  .reg_ext_rsp_t     ( cheshire_reg_ext_rsp_t     )
) i_cheshire_soc     (
  .clk_i      ,
  .rst_ni     ,
  .test_mode_i,
  .boot_mode_i,
  .rtc_i      ,
  // External AXI LLC (DRAM) port
  .axi_llc_mst_req_o ( axi_llc_mst_req ),
  .axi_llc_mst_rsp_i ( axi_llc_mst_rsp ),
  // External AXI crossbar ports
  .axi_ext_mst_req_i ( axi_ext_mst_req_i ),
  .axi_ext_mst_rsp_o ( axi_ext_mst_rsp_o ),
  .axi_ext_slv_req_o ( axi_ext_slv_req_o[0] ),
  .axi_ext_slv_rsp_i ( axi_ext_slv_rsp_i[0] ),
  // External reg demux slaves
  .reg_ext_slv_req_o ( ext_reg_req ),
  .reg_ext_slv_rsp_i ( ext_reg_rsp ),
  // Interrupts from external devices
  .intr_ext_i,
  .intr_ext_o,
  // Interrupts to external harts
  .xeip_ext_o,
  .mtip_ext_o,
  .msip_ext_o,
  // Debug interface to external harts
  .dbg_active_o     ,
  .dbg_ext_req_o    ,
  .dbg_ext_unavail_i,
  // JTAG interface
  .jtag_tck_i   ,
  .jtag_trst_ni ,
  .jtag_tms_i   ,
  .jtag_tdi_i   ,
  .jtag_tdo_o   ,
  .jtag_tdo_oe_o,
  // UART interface
  .uart_tx_o,
  .uart_rx_i,
  // UART Modem flow control
  .uart_rts_no,
  .uart_dtr_no,
  .uart_cts_ni,
  .uart_dsr_ni,
  .uart_dcd_ni,
  .uart_rin_ni,
  // I2C interface
  .i2c_sda_o   ,
  .i2c_sda_i   ,
  .i2c_sda_en_o,
  .i2c_scl_o   ,
  .i2c_scl_i   ,
  .i2c_scl_en_o,
  // SPI host interface
  .spih_sck_o   ,
  .spih_sck_en_o,
  .spih_csb_o   ,
  .spih_csb_en_o,
  .spih_sd_o    ,
  .spih_sd_en_o ,
  .spih_sd_i    ,
  // GPIO interface
  .gpio_i   ,
  .gpio_o   ,
  .gpio_en_o,
  // Serial link interface
  .slink_rcv_clk_i,
  .slink_rcv_clk_o,
  .slink_i        ,
  .slink_o        ,
  // VGA interface
  .vga_hsync_o,
  .vga_vsync_o,
  .vga_red_o  ,
  .vga_green_o,
  .vga_blue_o
);

axi_isolate              #(
  .NumPending             ( Cfg.AxiMaxSlvTrans         ),
  .TerminateTransaction   ( 1                          ),
  .AtopSupport            ( 1                          ),
  .AxiAddrWidth           ( Cfg.AddrWidth              ),
  .AxiDataWidth           ( Cfg.AxiDataWidth           ),
  .AxiIdWidth             ( LlcIdWidth                 ),
  .AxiUserWidth           ( Cfg.AxiUserWidth           ),
  .axi_req_t              ( cheshire_axi_ext_llc_req_t ),
  .axi_resp_t             ( cheshire_axi_ext_llc_rsp_t )
) i_axi_llc_isolate       (
  .clk_i                  ( clk_i                    ),
  .rst_ni                 ( rst_ni                   ),
  .slv_req_i              ( axi_llc_mst_req          ),
  .slv_resp_o             ( axi_llc_mst_rsp          ),
  .mst_req_o              ( axi_llc_mst_isolated_req ),
  .mst_resp_i             ( axi_llc_mst_isolated_rsp ),
  .isolate_i              ( axi_llc_isolate_i        ),
  .isolated_o             ( axi_llc_isolated_o       )
);

axi_iw_converter #(
  .AxiSlvPortIdWidth      ( LlcIdWidth    ),
  .AxiMstPortIdWidth      ( ExtSlvIdWidth ),
  .AxiSlvPortMaxUniqIds   ( 1 ),
  .AxiSlvPortMaxTxnsPerId ( Cfg.AxiMaxMstTrans ),
  .AxiSlvPortMaxTxns      ( Cfg.AxiMaxMstTrans ),
  .AxiMstPortMaxUniqIds   ( 1 ),
  .AxiMstPortMaxTxnsPerId ( Cfg.AxiMaxMstTrans ),
  .AxiAddrWidth ( Cfg.AddrWidth ),
  .AxiDataWidth ( Cfg.AxiDataWidth ),
  .AxiUserWidth ( Cfg.AxiUserWidth ),
  .slv_req_t  ( cheshire_axi_ext_llc_req_t ),
  .slv_resp_t ( cheshire_axi_ext_llc_rsp_t ),
  .mst_req_t  ( cheshire_axi_ext_slv_req_t ),
  .mst_resp_t ( cheshire_axi_ext_slv_rsp_t )
) i_llc_idw_converter (
  .clk_i,
  .rst_ni,
  .slv_req_i  ( axi_llc_mst_isolated_req ),
  .slv_resp_o ( axi_llc_mst_isolated_rsp ),
  .mst_req_o  ( axi_ext_slv_req_o[1] ),
  .mst_resp_i ( axi_ext_slv_rsp_i[1] )
);

// Async reg interface:
// See carfield_pkg.sv for indices referring to sync and async reg interfaces.
for (genvar i = 0; i < NumAsyncRegSlv; i++) begin : gen_ext_reg_async
  reg_cdc_src #(
    .CDC_KIND ( "cdc_4phase"              ),
    .req_t     ( cheshire_reg_ext_req_t   ),
    .rsp_t     ( cheshire_reg_ext_rsp_t   )
  ) i_reg_cdc_src (
      .src_clk_i    ( clk_i  ),
      .src_rst_ni   ( rst_ni ),
      .src_req_i    ( ext_reg_req[NumSyncRegSlv + i] ),
      .src_rsp_o    ( ext_reg_rsp[NumSyncRegSlv + i] ),

      .async_req_o  ( ext_reg_async_slv_req_o[i]  ),
      .async_ack_i  ( ext_reg_async_slv_ack_i[i]  ),
      .async_data_o ( ext_reg_async_slv_data_o[i] ),

      .async_req_i  ( ext_reg_async_slv_req_i[i]  ),
      .async_ack_o  ( ext_reg_async_slv_ack_o[i]  ),
      .async_data_i ( ext_reg_async_slv_data_i[i] )
  );
end

endmodule: cheshire_wrap
