<%
  int_sig = range(4)
  phys = ["phy0", "phy1"]
  pins = ["cs_no", "ck_o", "ck_no", "rwds_o", "rwds_i", "rwds_oe_o", "dq_i", "dq_o", "dq_oe_o", "reset_no", "pad_cfg_o"]
  pads = ["cs_n", "ck", "ck_n", "rwds", "dq", "reset_n"]  
  chips = {n: [""] for n in pins + pads}
  bits = {n: [""] for n in pins + pads}
  chips["cs_no"] = chips["cs_n"] = range(2)
  bits["dq_o"] = bits["dq_i"] = bits["dq"] = range(8)
  bits["pad_cfg_o"] = range(8)
  def loop_over(p):
    items = []
    for phy in phys:
      for pin in p:
        for chip in chips[pin]:
          for bit in bits[pin]:
            items.append((phy, pin, chip, bit))
    return items
%>\
<%def name="pad_name(phy, pin, chip, bit)">\
hyper_${phy}_${pin}${f"_{chip}" if chip!="" else ""}${f"_b{bit}" if bit!="" else ""}\
</%def>\
<%def name="hyp_name(phy, pin, chip, bit)">\
hyper_${pin}[${phy.removeprefix("phy")}]${[chip] if chip!="" else ""}${[bit] if bit!="" else ""}\
</%def>\
<%def name="pad_conn(phy, pin, chip, bit)">\
pad_hyper_${phy}_${pin}${f"_{chip}" if chip!="" else ""}${f"_b{bit}" if bit!="" else ""}_pad\
</%def>\
// Copyright 2023 ETH Zurich and University of Bologna.
// Solderpad Hardware License, Version 0.51, see LICENSE for details.
// SPDX-License-Identifier: SHL-0.51
//
// Yvan Tortorella <yvan.tortorella@unibo.it>

`include "register_interface/typedef.svh"

module hyperbus_wrap 
  import pkg_hyperbus_padframe::*;
  import pkg_internal_hyperbus_padframe_topr::*;
#(
  parameter int unsigned NumChips        = -1,
  parameter int unsigned NumPhys         = 2,
  parameter int unsigned IsClockODelayed = 0,
  parameter int unsigned AxiAddrWidth    = -1,
  parameter int unsigned AxiDataWidth    = -1,
  parameter int unsigned AxiIdWidth      = -1,
  parameter int unsigned AxiUserWidth    = -1,
  parameter int unsigned AxiMaxTrans     = 0 ,
  parameter type         axi_req_t       = logic,
  parameter type         axi_rsp_t       = logic,
  parameter type         axi_w_chan_t    = logic,
  parameter type         axi_b_chan_t    = logic,
  parameter type         axi_ar_chan_t   = logic,
  parameter type         axi_r_chan_t    = logic,
  parameter type         axi_aw_chan_t   = logic,
  parameter int unsigned RegAddrWidth    = -1,
  parameter int unsigned RegDataWidth    = -1,
  parameter type         reg_req_t       = logic,
  parameter type         reg_rsp_t       = logic,
  parameter type reg_addr_t              = logic [RegAddrWidth-1:0],
  parameter type reg_data_t              = logic [RegDataWidth-1:0],
  parameter type reg_strb_t              = logic [RegDataWidth/8-1:0],
  // The below have sensible defaults, but should be set on integration!
  parameter int unsigned RxFifoLogDepth  = 2,
  parameter int unsigned TxFifoLogDepth  = 2,
  parameter logic [RegDataWidth-1:0] RstChipBase  = 'h0,      // Base address for all chips
  parameter logic [RegDataWidth-1:0] RstChipSpace = 'h1_0000, // 64 KiB: Current maximum H
                                                              // yperBus device size
  parameter int unsigned PhyStartupCycles = 300 * 200, /* us*MHz */
                                                       // Conservative maximum
                                                       // frequency estimate
  parameter int unsigned AxiLogDepth     = 3,
  parameter int unsigned AxiSlaveArWidth = 0,
  parameter int unsigned AxiSlaveAwWidth = 0,
  parameter int unsigned AxiSlaveBWidth  = 0,
  parameter int unsigned AxiSlaveRWidth  = 0,
  parameter int unsigned AxiSlaveWWidth  = 0,
  parameter int unsigned CdcSyncStages   = 0
)(
  input  logic clk_sys_i     ,
  input  logic clk_phy_i     ,
  input  logic rst_ni        ,
  input  logic test_mode_i   ,
  // AXI bus
  input  logic [AxiSlaveArWidth-1:0] axi_slave_ar_data_i,
  input  logic [      AxiLogDepth:0] axi_slave_ar_wptr_i,
  output logic [      AxiLogDepth:0] axi_slave_ar_rptr_o,
  input  logic [AxiSlaveAwWidth-1:0] axi_slave_aw_data_i,
  input  logic [      AxiLogDepth:0] axi_slave_aw_wptr_i,
  output logic [      AxiLogDepth:0] axi_slave_aw_rptr_o,
  output logic [ AxiSlaveBWidth-1:0] axi_slave_b_data_o,
  output logic [      AxiLogDepth:0] axi_slave_b_wptr_o,
  input  logic [      AxiLogDepth:0] axi_slave_b_rptr_i,
  output logic [ AxiSlaveRWidth-1:0] axi_slave_r_data_o,
  output logic [      AxiLogDepth:0] axi_slave_r_wptr_o,
  input  logic [      AxiLogDepth:0] axi_slave_r_rptr_i,
  input  logic [ AxiSlaveWWidth-1:0] axi_slave_w_data_i,
  input  logic [      AxiLogDepth:0] axi_slave_w_wptr_i,
  output logic [      AxiLogDepth:0] axi_slave_w_rptr_o,
  // Reg bus
  input  reg_addr_t                   rbus_req_addr_i,
  input  logic                        rbus_req_write_i,
  input  reg_data_t                   rbus_req_wdata_i,
  input  reg_strb_t                   rbus_req_wstrb_i,
  input  logic                        rbus_req_valid_i,
  output reg_data_t                   rbus_rsp_rdata_o,
  output logic                        rbus_rsp_ready_o,
  output logic                        rbus_rsp_error_o,
  // Physical interace: HyperBus PADs
% for i in int_sig:
  inout wire logic pad_config_tc_pad_internal_signals_${i},
% endfor
% for phy, pin, chip, bit in loop_over(pads):
  inout wire logic ${pad_conn(phy, pin, chip, bit)}${"," if not loop.last else ""}
% endfor  
);

reg_req_t   reg_req;
reg_rsp_t   reg_rsp;

typedef struct packed {
  logic [31:0]             idx;
  logic [AxiAddrWidth-1:0] start_addr;
  logic [AxiAddrWidth-1:0] end_addr;
} addr_rule_t;

axi_req_t hyper_req;
axi_rsp_t hyper_rsp;

axi_cdc_dst      #(
  .LogDepth       ( AxiLogDepth   ),
  .SyncStages     ( CdcSyncStages ),
  .aw_chan_t      ( axi_aw_chan_t ),
  .w_chan_t       ( axi_w_chan_t  ),
  .b_chan_t       ( axi_b_chan_t  ),
  .ar_chan_t      ( axi_ar_chan_t ),
  .r_chan_t       ( axi_r_chan_t  ),
  .axi_req_t      ( axi_req_t     ),
  .axi_resp_t     ( axi_rsp_t     )
) i_hyper_cdc_dst (
  // asynchronous slave port
  .async_data_slave_aw_data_i ( axi_slave_aw_data_i ),
  .async_data_slave_aw_wptr_i ( axi_slave_aw_wptr_i ),
  .async_data_slave_aw_rptr_o ( axi_slave_aw_rptr_o ),
  .async_data_slave_w_data_i  ( axi_slave_w_data_i  ),
  .async_data_slave_w_wptr_i  ( axi_slave_w_wptr_i  ),
  .async_data_slave_w_rptr_o  ( axi_slave_w_rptr_o  ),
  .async_data_slave_b_data_o  ( axi_slave_b_data_o  ),
  .async_data_slave_b_wptr_o  ( axi_slave_b_wptr_o  ),
  .async_data_slave_b_rptr_i  ( axi_slave_b_rptr_i  ),
  .async_data_slave_ar_data_i ( axi_slave_ar_data_i ),
  .async_data_slave_ar_wptr_i ( axi_slave_ar_wptr_i ),
  .async_data_slave_ar_rptr_o ( axi_slave_ar_rptr_o ),
  .async_data_slave_r_data_o  ( axi_slave_r_data_o  ),
  .async_data_slave_r_wptr_o  ( axi_slave_r_wptr_o  ),
  .async_data_slave_r_rptr_i  ( axi_slave_r_rptr_i  ),
  // synchronous master port
  .dst_clk_i                  ( clk_sys_i ),
  .dst_rst_ni                 ( rst_ni    ),
  .dst_req_o                  ( hyper_req ),
  .dst_resp_i                 ( hyper_rsp )
);

assign reg_req.addr         = rbus_req_addr_i;
assign reg_req.write        = rbus_req_write_i;
assign reg_req.wdata        = rbus_req_wdata_i;
assign reg_req.wstrb        = rbus_req_wstrb_i;
assign reg_req.valid        = rbus_req_valid_i;
assign rbus_rsp_rdata_o     = reg_rsp.rdata;
assign rbus_rsp_ready_o     = reg_rsp.ready;
assign rbus_rsp_error_o     = reg_rsp.error;

% for pin in pins:
logic [NumPhys-1:0]${"[NumChips-1:0]" if len(chips[pin])>1 else ""}${f"[{len(bits[pin])-1}:0]" if len(bits[pin])>1 else ""} hyper_${pin};
% endfor

hyperbus           #(
  .NumChips         ( NumChips         ),
  .NumPhys          ( NumPhys          ),
  .IsClockODelayed  ( IsClockODelayed  ),
  .AxiAddrWidth     ( AxiAddrWidth     ),
  .AxiDataWidth     ( AxiDataWidth     ),
  .AxiIdWidth       ( AxiIdWidth       ),
  .AxiUserWidth     ( AxiUserWidth     ),
  .axi_req_t        ( axi_req_t        ),
  .axi_rsp_t        ( axi_rsp_t        ),
  .RegAddrWidth     ( RegAddrWidth     ),
  .RegDataWidth     ( RegDataWidth     ),
  .reg_req_t        ( reg_req_t        ),
  .reg_rsp_t        ( reg_rsp_t        ),
  .axi_rule_t       ( addr_rule_t      ),
  .RxFifoLogDepth   ( RxFifoLogDepth   ),
  .TxFifoLogDepth   ( TxFifoLogDepth   ),
  .RstChipBase      ( RstChipBase      ),
  .RstChipSpace     ( RstChipSpace     ),
  .PhyStartupCycles ( PhyStartupCycles ),
  .AxiLogDepth      ( AxiLogDepth      ),
  .SyncStages       ( CdcSyncStages    )
) i_hyperbus        (
  .clk_phy_i        ( clk_phy_i          ),
  .rst_phy_ni       ( rst_ni             ),
  .clk_sys_i        ( clk_sys_i          ),
  .rst_sys_ni       ( rst_ni             ),
  .test_mode_i      ( test_mode_i        ),
  .axi_req_i        ( hyper_req          ),
  .axi_rsp_o        ( hyper_rsp          ),
  .reg_req_i        ( reg_req            ),
  .reg_rsp_o        ( reg_rsp            ),
% for pin in pins:
  .hyper_${pin}${"," if not loop.last else ""}
% endfor
);

pad_domain_topr_static_connection_signals_pad2soc_t pad2soc; //output
pad_domain_topr_static_connection_signals_soc2pad_t soc2pad; //input

hyperbus_padframe_topr_pads i_hyperbus_padframe_topr_pads(
  .static_connection_signals_pad2soc(pad2soc),
  .static_connection_signals_soc2pad(soc2pad),
% for i in int_sig:
  .pad_config_tc_pad_internal_signals_${i},
% endfor
% for phy, pin, chip, bit in loop_over(pads):
  .${pad_conn(phy, pin, chip, bit)}${"," if not loop.last else ""}
% endfor
);

// PAD input and output signals assignment
<% pins_to_slip = [p for p in pins if p != "pad_cfg_o"] %>
% for phy, pin, chip, bit in loop_over(pins_to_slip):
  % if pin[-1] == "o":
assign soc2pad.${pad_name(phy, pin, chip, bit)} = ${hyp_name(phy, pin, chip, bit)};
  % else:
assign ${hyp_name(phy, pin, chip, bit)} = pad2soc.${pad_name(phy, pin, chip, bit)};
  % endif
% endfor

% for phy in phys:
assign soc2pad.hyper_${phy}_slew_en_o = hyper_pad_cfg_o[${phy.removeprefix("phy")}][3];
assign soc2pad.hyper_${phy}_drive_strength_o = hyper_pad_cfg_o[${phy.removeprefix("phy")}][1:0];
% endfor

endmodule: hyperbus_wrap
