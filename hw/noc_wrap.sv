// Copyright 2023 ETH Zurich and University of Bologna.
// Solderpad Hardware License, Version 0.51, see LICENSE for details.
// SPDX-License-Identifier: SHL-0.51
//
// Yvan Tortorella <yvan.tortorella@unibo.it>

module noc_wrap #(
  parameter cheshire_pkg::cheshire_cfg_t Cfg = '0,
  parameter int unsigned LogDepth = 3,
  parameter int unsigned CdcSyncStages = 2,
  // NoC master ports connect to external slave devices, and viceversa
  parameter int unsigned NumNocSlv = carfield_pkg::CarfieldAxiNumMasters,
  parameter int unsigned NumNocMst = carfield_pkg::CarfieldAxiNumSlaves - 1,
  parameter type noc_llc_ar_chan_t = logic,
  parameter type noc_llc_aw_chan_t = logic,
  parameter type noc_llc_b_chan_t  = logic,
  parameter type noc_llc_r_chan_t  = logic,
  parameter type noc_llc_w_chan_t  = logic,
  parameter type noc_llc_req_t     = logic,
  parameter type noc_llc_rsp_t     = logic,
  parameter type noc_mst_ar_chan_t = logic,
  parameter type noc_mst_aw_chan_t = logic,
  parameter type noc_mst_b_chan_t  = logic,
  parameter type noc_mst_r_chan_t  = logic,
  parameter type noc_mst_w_chan_t  = logic,
  parameter type noc_mst_req_t     = logic,
  parameter type noc_mst_rsp_t     = logic,
  parameter type noc_slv_ar_chan_t = logic,
  parameter type noc_slv_aw_chan_t = logic,
  parameter type noc_slv_b_chan_t  = logic,
  parameter type noc_slv_r_chan_t  = logic,
  parameter type noc_slv_w_chan_t  = logic,
  parameter type noc_slv_req_t     = logic,
  parameter type noc_slv_rsp_t     = logic,
  parameter int unsigned NocSlvIdWidth = Cfg.AxiMstIdWidth,
  parameter int unsigned LlcIdWidth = NocSlvIdWidth + Cfg.LlcNotBypass,
  // LLC Parameters
  parameter int unsigned LlcArWidth = (2**LogDepth)*
                                       axi_pkg::ar_width(Cfg.AddrWidth   ,
                                                         LlcIdWidth      ,
                                                         Cfg.AxiUserWidth),
  parameter int unsigned LlcAwWidth = (2**LogDepth)*
                                        axi_pkg::aw_width(Cfg.AddrWidth  ,
                                                         LlcIdWidth      ,
                                                         Cfg.AxiUserWidth),
  parameter int unsigned LlcBWidth  = (2**LogDepth)*
                                        axi_pkg::b_width(LlcIdWidth      ,
                                                         Cfg.AxiUserWidth),
  parameter int unsigned LlcRWidth  = (2**LogDepth)*
                                        axi_pkg::r_width(Cfg.AxiDataWidth,
                                                        LlcIdWidth      ,
                                                        Cfg.AxiUserWidth),
  parameter int unsigned LlcWWidth  = (2**LogDepth)*
                                        axi_pkg::w_width(Cfg.AxiDataWidth,
                                                         Cfg.AxiUserWidth),
  // External slaves Parameters
  localparam int unsigned NocSlvArWidth = (2**LogDepth)*
                                           axi_pkg::ar_width(Cfg.AddrWidth  ,
                                                            NocSlvIdWidth   ,
                                                            Cfg.AxiUserWidth),
  localparam int unsigned NocSlvAwWidth = (2**LogDepth)*
                                           axi_pkg::aw_width(Cfg.AddrWidth  ,
                                                            NocSlvIdWidth   ,
                                                            Cfg.AxiUserWidth),
  localparam int unsigned NocSlvBWidth  = (2**LogDepth)*
                                           axi_pkg::b_width(NocSlvIdWidth   ,
                                                            Cfg.AxiUserWidth),
  localparam int unsigned NocSlvRWidth  = (2**LogDepth)*
                                          axi_pkg::r_width(Cfg.AxiDataWidth,
                                                           NocSlvIdWidth   ,
                                                           Cfg.AxiUserWidth),
  localparam int unsigned NocSlvWWidth  = (2**LogDepth)*
                                           axi_pkg::w_width(Cfg.AxiDataWidth,
                                                            Cfg.AxiUserWidth),
  // External Master Parameters
  localparam int unsigned NocMstArWidth = (2**LogDepth)*
                                           axi_pkg::ar_width(Cfg.AddrWidth    ,
                                                             Cfg.AxiMstIdWidth,
                                                             Cfg.AxiUserWidth ),
  localparam int unsigned NocMstAwWidth = (2**LogDepth)*
                                           axi_pkg::aw_width(Cfg.AddrWidth    ,
                                                             Cfg.AxiMstIdWidth,
                                                             Cfg.AxiUserWidth ),
  localparam int unsigned NocMstBWidth  = (2**LogDepth)*
                                           axi_pkg::b_width(Cfg.AxiMstIdWidth,
                                                            Cfg.AxiUserWidth ),
  localparam int unsigned NocMstRWidth  = (2**LogDepth)*
                                           axi_pkg::r_width(Cfg.AxiDataWidth ,
                                                            Cfg.AxiMstIdWidth,
                                                            Cfg.AxiUserWidth ),
  localparam int unsigned NocMstWWidth  = (2**LogDepth)*
                                           axi_pkg::w_width(Cfg.AxiDataWidth,
                                                            Cfg.AxiUserWidth)
)(
  input  logic clk_i,
  input  logic rst_ni,
  input  logic [NumNocMst-1:0] noc_ext_slv_isolate_i,
  output logic [NumNocMst-1:0] noc_ext_slv_isolated_o,
  input  noc_slv_req_t cheshire_slv_req_i,
  output noc_slv_rsp_t cheshire_slv_rsp_o,
  output noc_mst_req_t cheshire_mst_req_o,
  input  noc_mst_rsp_t cheshire_mst_rsp_i,
  output noc_mst_req_t mailbox_mst_req_o,
  input  noc_mst_rsp_t mailbox_mst_rsp_i,
  // External async AXI master Ports
  output logic [NumNocMst-1:0][NocMstArWidth-1:0] noc_ext_mst_ar_data_o,
  output logic [NumNocMst-1:0][       LogDepth:0] noc_ext_mst_ar_wptr_o,
  input  logic [NumNocMst-1:0][       LogDepth:0] noc_ext_mst_ar_rptr_i,
  output logic [NumNocMst-1:0][NocMstAwWidth-1:0] noc_ext_mst_aw_data_o,
  output logic [NumNocMst-1:0][       LogDepth:0] noc_ext_mst_aw_wptr_o,
  input  logic [NumNocMst-1:0][       LogDepth:0] noc_ext_mst_aw_rptr_i,
  input  logic [NumNocMst-1:0][ NocMstBWidth-1:0] noc_ext_mst_b_data_i ,
  input  logic [NumNocMst-1:0][       LogDepth:0] noc_ext_mst_b_wptr_i ,
  output logic [NumNocMst-1:0][       LogDepth:0] noc_ext_mst_b_rptr_o ,
  input  logic [NumNocMst-1:0][ NocMstRWidth-1:0] noc_ext_mst_r_data_i ,
  input  logic [NumNocMst-1:0][       LogDepth:0] noc_ext_mst_r_wptr_i ,
  output logic [NumNocMst-1:0][       LogDepth:0] noc_ext_mst_r_rptr_o ,
  output logic [NumNocMst-1:0][ NocMstWWidth-1:0] noc_ext_mst_w_data_o ,
  output logic [NumNocMst-1:0][       LogDepth:0] noc_ext_mst_w_wptr_o ,
  input  logic [NumNocMst-1:0][       LogDepth:0] noc_ext_mst_w_rptr_i ,
  // External async AXI slave Ports
  input  logic [NumNocSlv-1:0][NocSlvArWidth-1:0] noc_ext_slv_ar_data_i,
  input  logic [NumNocSlv-1:0][       LogDepth:0] noc_ext_slv_ar_wptr_i,
  output logic [NumNocSlv-1:0][       LogDepth:0] noc_ext_slv_ar_rptr_o,
  input  logic [NumNocSlv-1:0][NocSlvAwWidth-1:0] noc_ext_slv_aw_data_i,
  input  logic [NumNocSlv-1:0][       LogDepth:0] noc_ext_slv_aw_wptr_i,
  output logic [NumNocSlv-1:0][       LogDepth:0] noc_ext_slv_aw_rptr_o,
  output logic [NumNocSlv-1:0][ NocSlvBWidth-1:0] noc_ext_slv_b_data_o ,
  output logic [NumNocSlv-1:0][       LogDepth:0] noc_ext_slv_b_wptr_o ,
  input  logic [NumNocSlv-1:0][       LogDepth:0] noc_ext_slv_b_rptr_i ,
  output logic [NumNocSlv-1:0][ NocSlvRWidth-1:0] noc_ext_slv_r_data_o ,
  output logic [NumNocSlv-1:0][       LogDepth:0] noc_ext_slv_r_wptr_o ,
  input  logic [NumNocSlv-1:0][       LogDepth:0] noc_ext_slv_r_rptr_i ,
  input  logic [NumNocSlv-1:0][ NocSlvWWidth-1:0] noc_ext_slv_w_data_i ,
  input  logic [NumNocSlv-1:0][       LogDepth:0] noc_ext_slv_w_wptr_i ,
  output logic [NumNocSlv-1:0][       LogDepth:0] noc_ext_slv_w_rptr_o
);

noc_mst_req_t [NumNocMst-1:0] mst_req, mst_isolated_req;
noc_mst_rsp_t [NumNocMst-1:0] mst_rsp, mst_isolated_rsp;

noc_slv_req_t [NumNocSlv-1:0] slv_req;
noc_slv_rsp_t [NumNocSlv-1:0] slv_rsp;

noc_llc_req_t llc_req, llc_isolated_req;
noc_llc_rsp_t llc_rsp, llc_isolated_rsp;

for (genvar i = 0; i < NumNocMst; i++) begin: gen_mst_src_cdc

  axi_isolate              #(
    .NumPending             ( Cfg.AxiMaxMstTrans ),
    .TerminateTransaction   ( 1                  ),
    .AtopSupport            ( 1                  ),
    .AxiAddrWidth           ( Cfg.AddrWidth      ),
    .AxiDataWidth           ( Cfg.AxiDataWidth   ),
    .AxiIdWidth             ( Cfg.AxiMstIdWidth  ),
    .AxiUserWidth           ( Cfg.AxiUserWidth   ),
    .axi_req_t              ( noc_mst_req_t      ),
    .axi_resp_t             ( noc_mst_rsp_t      )
  ) i_slave_isolate         (
    .clk_i                  ( clk_i                      ),
    .rst_ni                 ( rst_ni                     ),
    .slv_req_i              ( mst_req          [i]       ),
    .slv_resp_o             ( mst_rsp          [i]       ),
    .mst_req_o              ( mst_isolated_req [i]       ),
    .mst_resp_i             ( mst_isolated_rsp [i]       ),
    .isolate_i              ( noc_ext_slv_isolate_i  [i] ),
    .isolated_o             ( noc_ext_slv_isolated_o [i] )
  );

  axi_cdc_src #(
    .LogDepth   ( LogDepth          ),
    .SyncStages ( CdcSyncStages     ),
    .aw_chan_t  ( noc_mst_aw_chan_t ),
    .w_chan_t   ( noc_mst_w_chan_t  ),
    .b_chan_t   ( noc_mst_b_chan_t  ),
    .ar_chan_t  ( noc_mst_ar_chan_t ),
    .r_chan_t   ( noc_mst_r_chan_t  ),
    .axi_req_t  ( noc_mst_req_t     ),
    .axi_resp_t ( noc_mst_rsp_t     )
  ) i_slv_cdc_src (
    // synchronous slave port
    .src_clk_i                   ( clk_i                ),
    .src_rst_ni                  ( rst_ni               ),
    .src_req_i                   ( mst_isolated_req [i] ),
    .src_resp_o                  ( mst_isolated_rsp [i] ),
    // asynchronous master port
    .async_data_master_aw_data_o ( noc_ext_mst_aw_data_o [i] ),
    .async_data_master_aw_wptr_o ( noc_ext_mst_aw_wptr_o [i] ),
    .async_data_master_aw_rptr_i ( noc_ext_mst_aw_rptr_i [i] ),
    .async_data_master_w_data_o  ( noc_ext_mst_w_data_o  [i] ),
    .async_data_master_w_wptr_o  ( noc_ext_mst_w_wptr_o  [i] ),
    .async_data_master_w_rptr_i  ( noc_ext_mst_w_rptr_i  [i] ),
    .async_data_master_b_data_i  ( noc_ext_mst_b_data_i  [i] ),
    .async_data_master_b_wptr_i  ( noc_ext_mst_b_wptr_i  [i] ),
    .async_data_master_b_rptr_o  ( noc_ext_mst_b_rptr_o  [i] ),
    .async_data_master_ar_data_o ( noc_ext_mst_ar_data_o [i] ),
    .async_data_master_ar_wptr_o ( noc_ext_mst_ar_wptr_o [i] ),
    .async_data_master_ar_rptr_i ( noc_ext_mst_ar_rptr_i [i] ),
    .async_data_master_r_data_i  ( noc_ext_mst_r_data_i  [i] ),
    .async_data_master_r_wptr_i  ( noc_ext_mst_r_wptr_i  [i] ),
    .async_data_master_r_rptr_o  ( noc_ext_mst_r_rptr_o  [i] )
  );
end

for (genvar i = 0; i < NumNocSlv; i++) begin: gen_ext_slv_dst_cdc
  axi_cdc_dst #(
    .LogDepth   ( LogDepth          ),
    .SyncStages ( CdcSyncStages     ),
    .aw_chan_t  ( noc_slv_aw_chan_t ),
    .w_chan_t   ( noc_slv_w_chan_t  ),
    .b_chan_t   ( noc_slv_b_chan_t  ),
    .ar_chan_t  ( noc_slv_ar_chan_t ),
    .r_chan_t   ( noc_slv_r_chan_t  ),
    .axi_req_t  ( noc_slv_req_t     ),
    .axi_resp_t ( noc_slv_rsp_t     )
  ) i_cheshire_ext_mst_cdc_dst  (
    // asynchronous slave port
    .async_data_slave_aw_data_i ( noc_ext_slv_aw_data_i [i] ),
    .async_data_slave_aw_wptr_i ( noc_ext_slv_aw_wptr_i [i] ),
    .async_data_slave_aw_rptr_o ( noc_ext_slv_aw_rptr_o [i] ),
    .async_data_slave_w_data_i  ( noc_ext_slv_w_data_i  [i] ),
    .async_data_slave_w_wptr_i  ( noc_ext_slv_w_wptr_i  [i] ),
    .async_data_slave_w_rptr_o  ( noc_ext_slv_w_rptr_o  [i] ),
    .async_data_slave_b_data_o  ( noc_ext_slv_b_data_o  [i] ),
    .async_data_slave_b_wptr_o  ( noc_ext_slv_b_wptr_o  [i] ),
    .async_data_slave_b_rptr_i  ( noc_ext_slv_b_rptr_i  [i] ),
    .async_data_slave_ar_data_i ( noc_ext_slv_ar_data_i [i] ),
    .async_data_slave_ar_wptr_i ( noc_ext_slv_ar_wptr_i [i] ),
    .async_data_slave_ar_rptr_o ( noc_ext_slv_ar_rptr_o [i] ),
    .async_data_slave_r_data_o  ( noc_ext_slv_r_data_o  [i] ),
    .async_data_slave_r_wptr_o  ( noc_ext_slv_r_wptr_o  [i] ),
    .async_data_slave_r_rptr_i  ( noc_ext_slv_r_rptr_i  [i] ),
    // synchronous master port
    .dst_clk_i                  ( clk_i       ),
    .dst_rst_ni                 ( rst_ni      ),
    .dst_req_o                  ( slv_req [i] ),
    .dst_resp_i                 ( slv_rsp [i] )
  );
end

floo_astral_noc i_astral_noc (
  .clk_i,
  .rst_ni,
  .test_enable_i ( '0 ),
  .cheshire_axi_in_req_i ( cheshire_slv_req_i ),
  .cheshire_axi_in_rsp_o ( cheshire_slv_rsp_o ),
  .cheshire_axi_out_req_o ( cheshire_mst_req_o ),
  .cheshire_axi_out_rsp_i ( cheshire_mst_rsp_i ),
  .opentitan_main_axi_in_req_i ( slv_req [carfield_pkg::SecurityIslandTlulMstIdx] ),
  .opentitan_main_axi_in_rsp_o ( slv_rsp [carfield_pkg::SecurityIslandTlulMstIdx] ),
  .opentitan_dma_axi_in_req_i ( slv_req [carfield_pkg::SecurityIslandiDMAMstIdx] ),
  .opentitan_dma_axi_in_rsp_o ( slv_rsp [carfield_pkg::SecurityIslandiDMAMstIdx] ),
  .l2_port0_axi_out_req_o ( mst_req [carfield_pkg::L2Port0SlvIdx] ),
  .l2_port0_axi_out_rsp_i ( mst_rsp [carfield_pkg::L2Port0SlvIdx] ),
  .l2_port1_axi_out_req_o ( mst_req [carfield_pkg::L2Port1SlvIdx] ),
  .l2_port1_axi_out_rsp_i ( mst_rsp [carfield_pkg::L2Port1SlvIdx] ),
  .cluster_axi_in_req_i ( slv_req [carfield_pkg::IntClusterMstIdx] ),
  .cluster_axi_in_rsp_o ( slv_rsp [carfield_pkg::IntClusterMstIdx] ),
  .cluster_axi_out_req_o ( mst_req [carfield_pkg::IntClusterSlvIdx] ),
  .cluster_axi_out_rsp_i ( mst_rsp [carfield_pkg::IntClusterSlvIdx] ),
  .ethernet_axi_in_req_i ( slv_req [carfield_pkg::EthernetMstIdx] ),
  .ethernet_axi_in_rsp_o ( slv_rsp [carfield_pkg::EthernetMstIdx] ),
  .mbox_axi_out_req_o ( mailbox_mst_req_o ),
  .mbox_axi_out_rsp_i ( mailbox_mst_rsp_i ),
  .peripherals_axi_out_req_o ( mst_req [carfield_pkg::PeriphsSlvIdx] ),
  .peripherals_axi_out_rsp_i ( mst_rsp [carfield_pkg::PeriphsSlvIdx] ),
  .dram_axi_in_req_i ( '0 ),
  .dram_axi_in_rsp_o (  ),
  .dram_axi_out_req_o (  ),
  .dram_axi_out_rsp_i ( '0 )
);

endmodule: noc_wrap
