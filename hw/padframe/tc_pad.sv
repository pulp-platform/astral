// Copyright 2026 Fondazione Chips-IT.
//
// Author: Riccardo Fiorani Gallotta <riccardo.fiorani3@unibo.it>
//
// Behaviour model of generic io pads
//
// When implementing tech cell wrappers do not change the default parameter value
// and put assertions to check the correct values 
// 

// Power management pad: LSB of internal signal is retention enable
module tc_pad_pwr_mng #(
    parameter tc_pad_pkg::tc_pad_orientation_t tc_pad_orientation,
    parameter tc_pad_pkg::tc_pad_config_t      tc_pad_config      = tc_pad_pkg::default_tc_pad_config
) (
    // retention enable signal
    input logic                         ret_en_i,

    // internal signals
    inout logic [tc_pad_config.n_int:0] int_io
);

    assign int_io[0] = (ret_en_i == tc_pad_config.rt_en_ah) ? 1'b1 
                     : (ret_en_i == ~tc_pad_config.rt_en_ah) ? 1'b0 : 1'bx;

endmodule

// Power pad for core power domain
module tc_pad_vdd_core #(
    parameter tc_pad_pkg::tc_pad_orientation_t tc_pad_orientation,
    parameter tc_pad_pkg::tc_pad_config_t      tc_pad_config      = tc_pad_pkg::default_tc_pad_config
) (
    // internal signals
    inout logic [tc_pad_config.n_int:0] int_io
);

    // void

endmodule

// Ground pad for core power domain
module tc_pad_vss_core #(
    parameter tc_pad_pkg::tc_pad_orientation_t tc_pad_orientation,
    parameter tc_pad_pkg::tc_pad_config_t      tc_pad_config      = tc_pad_pkg::default_tc_pad_config
) (
    // internal signals
    inout logic [tc_pad_config.n_int:0] int_io
);

    // void

endmodule

// Power pad for io power domain
module tc_pad_vdd_io #(
    parameter tc_pad_pkg::tc_pad_orientation_t tc_pad_orientation,
    parameter tc_pad_pkg::tc_pad_config_t      tc_pad_config      = tc_pad_pkg::default_tc_pad_config
) (
    // internal signals
    inout logic [tc_pad_config.n_int:0] int_io
);

    // void

endmodule

// Ground pad for io power domain
module tc_pad_vss_io #(
    parameter tc_pad_pkg::tc_pad_orientation_t tc_pad_orientation,
    parameter tc_pad_pkg::tc_pad_config_t      tc_pad_config      = tc_pad_pkg::default_tc_pad_config
) (
    // internal signals
    inout logic [tc_pad_config.n_int:0] int_io
);

    // void

endmodule

// Corner pad
module tc_pad_corner #(
    parameter tc_pad_pkg::tc_pad_config_t tc_pad_config = tc_pad_pkg::default_tc_pad_config
) (
    // internal signals
    inout logic [tc_pad_config.n_int:0] int_io
);

    // void

endmodule

// Digital bidirectional input/output pad
module tc_pad_bidir #(
    parameter tc_pad_pkg::tc_pad_orientation_t tc_pad_orientation,
    parameter int unsigned                     tc_pad_w           = 1,
    parameter tc_pad_pkg::tc_pad_config_t      tc_pad_config      = tc_pad_pkg::default_tc_pad_config
) (
    // pad signal
    inout  logic [(tc_pad_w>0 ? tc_pad_w-1 : 0):0] pad_io,

    // input signals
    output logic [(tc_pad_w>0 ? tc_pad_w-1 : 0):0] pad2chip_o,
    input  logic                                   input_en_i,
    input  logic                                   pu_en_i,
    input  logic                                   pd_en_i,
    input  logic                                   schmitt_en_i,
    input  logic                                   nand_in_i,
    output logic                                   nand_out_o,
    
    // output signals
    input logic [                    (tc_pad_w>0 ? tc_pad_w-1 : 0):0] chip2pad_i,
    input logic                                                       output_en_i,
    input logic                                                       slew_en_i,
    input logic [(tc_pad_config.ds_w>0 ? tc_pad_config.ds_w-1 : 0):0] drive_strength_i,

    // internal signals
    inout  logic [tc_pad_config.n_int:0] int_io
);

    // check config for the availability of bidirectional io cells
    initial begin
        assert (tc_pad_config.av_bidir_cell === 1) else $fatal(1, "With the used config, bidirectional IO pad cells (tc_pad_bidir) are not available");
    end

    wire [(tc_pad_w>0 ? tc_pad_w-1 : 0):0] pad_internal_latch;
    logic [(tc_pad_w>0 ? tc_pad_w-1 : 0):0] chip2pad_latch;
    logic input_en_latch, pu_en_latch, pd_en_latch, output_en_latch;

    // if retention enabled latch input_en, pu_en, pd_en, output_en and chip2pad
    // LSB of internal signal is retention enable
    always_latch begin : gen_retention_latch
        if (~int_io[0]) begin
            pu_en_latch     <= pu_en_i;
            pd_en_latch     <= pd_en_i;
            output_en_latch <= output_en_i;
            chip2pad_latch  <= chip2pad_i;
        end
    end

    if (tc_pad_config.in_en_latch == 1'b1) begin
        always_latch begin : gen_input_en_latch
            if (~int_io[0]) begin
                input_en_latch  <= input_en_i;
            end
        end
    end else begin
        assign input_en_latch = input_en_i;
    end

    assign pad_internal_latch = pad_io;

    for (genvar i = 0; i < (tc_pad_w>0 ? tc_pad_w : 1); i++) begin
        bufif1 (weak1, weak0) (pad_io[i], '0, (output_en_latch == ~tc_pad_config.out_en_ah) && (pu_en_latch == ~tc_pad_config.pu_en_ah) && (pd_en_latch == tc_pad_config.pd_en_ah));
        bufif1 (weak1, weak0) (pad_io[i], '1, (output_en_latch == ~tc_pad_config.out_en_ah) && (pu_en_latch == tc_pad_config.pu_en_ah) && (pd_en_latch == ~tc_pad_config.pd_en_ah));
    end

    // if both pu_en and pd_en are enabled bus hold or assertion
    if (tc_pad_config.pu_pd_both_en == 1'b1) begin
        for (genvar i = 0; i < (tc_pad_w>0 ? tc_pad_w : 1); i++) begin
            bufif1 (weak1, weak0) (pad_io[i], pad_internal_latch[i], (output_en_latch == ~tc_pad_config.out_en_ah) && (pu_en_latch == tc_pad_config.pu_en_ah) && (pd_en_latch == tc_pad_config.pd_en_ah));
        end
    end else begin
        always_comb assert (!((pu_en_latch === tc_pad_config.pu_en_ah) && (pd_en_latch === tc_pad_config.pd_en_ah))) 
            else $error("Pull up and pull down can't be both enabled");
    end
	
    // output
    assign pad2chip_o = (input_en_latch == tc_pad_config.in_en_ah) ? pad_io & '1
                      : (input_en_latch == ~tc_pad_config.in_en_ah) ? '0 : 'x;

    for (genvar i = 0; i < (tc_pad_w>0 ? tc_pad_w : 1); i++) begin
        bufif1 (pad_io[i], chip2pad_latch[i], output_en_latch == tc_pad_config.out_en_ah);
    end

    // nand
    wire [(tc_pad_w>0 ? tc_pad_w : 1):0] pad_internal_nand;
    assign pad_internal_nand[0] = nand_in_i;
    assign nand_out_o = pad_internal_nand[(tc_pad_w>0 ? tc_pad_w : 1)];

    for (genvar i = 0; i < (tc_pad_w>0 ? tc_pad_w : 1); i++) begin
        nand (pad_internal_nand[i+1], pad2chip_o[i], pad_internal_nand[i]);
    end

endmodule

// Digital input pad
module tc_pad_input #(
    parameter tc_pad_pkg::tc_pad_orientation_t tc_pad_orientation,
    parameter int unsigned                     tc_pad_w           = 1,
    parameter tc_pad_pkg::tc_pad_config_t      tc_pad_config      = tc_pad_pkg::default_tc_pad_config
) (

    // pad signal
    inout  logic [(tc_pad_w>0 ? tc_pad_w-1 : 0):0] pad_io,

    // input signals
    output logic [(tc_pad_w>0 ? tc_pad_w-1 : 0):0] pad2chip_o,
    input  logic                                   input_en_i,
    input  logic                                   pu_en_i,
    input  logic                                   pd_en_i,
    input  logic                                   schmitt_en_i,
    input  logic                                   nand_in_i,
    output logic                                   nand_out_o,

    // internal signals
    inout  logic [tc_pad_config.n_int:0] int_io
);

    // check config for the availability of only input cells
    initial begin
        assert (tc_pad_config.av_in_cell === 1) else $fatal(1, "With the used config, IO pad only input cells (tc_pad_input) are not available");
    end

    wire [(tc_pad_w>0 ? tc_pad_w-1 : 0):0] pad_internal_latch;
    logic input_en_latch, pu_en_latch, pd_en_latch;

    // if retention enabled latch input_en, pu_en and pd_en
    // LSB of internal signal is retention enable
    always_latch begin : gen_retention_latch
        if (~int_io[0]) begin
            pu_en_latch    <= pu_en_i;
            pd_en_latch    <= pd_en_i;
        end
    end

    if (tc_pad_config.in_en_latch == 1'b1) begin
        always_latch begin : gen_input_en_latch
            if (~int_io[0]) begin
                input_en_latch  <= input_en_i;
            end
        end
    end else begin
        assign input_en_latch = input_en_i;
    end

    assign pad_internal_latch = pad_io;

    for (genvar i = 0; i < (tc_pad_w>0 ? tc_pad_w : 1); i++) begin
        bufif1 (weak1, weak0) (pad_io[i], '0, (pu_en_latch == ~tc_pad_config.pu_en_ah) && (pd_en_latch == tc_pad_config.pd_en_ah));
        bufif1 (weak1, weak0) (pad_io[i], '1, (pu_en_latch == tc_pad_config.pu_en_ah) && (pd_en_latch == ~tc_pad_config.pd_en_ah));
    end

    // if both pu_en and pd_en are enabled bus hold or assertion
    if (tc_pad_config.pu_pd_both_en == 1'b1) begin
        for (genvar i = 0; i < (tc_pad_w>0 ? tc_pad_w : 1); i++) begin
            bufif1 (weak1, weak0) (pad_io[i], pad_internal_latch[i], (pu_en_latch == tc_pad_config.pu_en_ah) && (pd_en_latch == tc_pad_config.pd_en_ah));
        end
    end else begin
        always_comb assert (!((pu_en_latch === tc_pad_config.pu_en_ah) && (pd_en_latch === tc_pad_config.pd_en_ah))) 
            else $error("Pull up and pull down can't be both enabled");
    end
	
    // output
    assign pad2chip_o = (input_en_latch == tc_pad_config.in_en_ah) ? pad_io & '1
                      : (input_en_latch == ~tc_pad_config.in_en_ah) ? '0 : 'x;
   
    // nand
    wire [(tc_pad_w>0 ? tc_pad_w : 1):0] pad_internal_nand;
    assign pad_internal_nand[0] = nand_in_i;
    assign nand_out_o = pad_internal_nand[(tc_pad_w>0 ? tc_pad_w : 1)];

    for (genvar i = 0; i < (tc_pad_w>0 ? tc_pad_w : 1); i++) begin
        nand (pad_internal_nand[i+1], pad2chip_o[i], pad_internal_nand[i]);
    end

endmodule

// Digital output pad
module tc_pad_output #(
    parameter tc_pad_pkg::tc_pad_orientation_t tc_pad_orientation,
    parameter int unsigned                     tc_pad_w           = 1,
    parameter tc_pad_pkg::tc_pad_config_t      tc_pad_config      = tc_pad_pkg::default_tc_pad_config
) (
    // pad signal
    inout logic [                    (tc_pad_w>0 ? tc_pad_w-1 : 0):0] pad_io,

    // output signals
    input logic [                    (tc_pad_w>0 ? tc_pad_w-1 : 0):0] chip2pad_i,
    input logic                                                       output_en_i,
    input logic                                                       slew_en_i,
    input logic [(tc_pad_config.ds_w>0 ? tc_pad_config.ds_w-1 : 0):0] drive_strength_i,

    // internal signals
    inout logic [tc_pad_config.n_int:0] int_io
);

    // check config for the availability of only output cells
    initial begin
        assert (tc_pad_config.av_out_cell === 1) else $fatal(1, "With the used config, IO pad only output cells (tc_pad_output) are not available");
    end

    logic [(tc_pad_w>0 ? tc_pad_w-1 : 0):0] chip2pad_latch;
    logic output_en_latch;

    // if retention enabled latch output_en and chip2pad
    // LSB of internal signal is retention enable
    always_latch begin : gen_retention_latch
        if (~int_io[0]) begin
            output_en_latch <= output_en_i;
            chip2pad_latch  <= chip2pad_i;
        end
    end
	
    // output
    for (genvar i = 0; i < (tc_pad_w>0 ? tc_pad_w : 1); i++) begin
        bufif1 (pad_io[i], chip2pad_latch[i], output_en_latch == tc_pad_config.out_en_ah);
    end

endmodule
