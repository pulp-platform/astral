// Copyright 2023 ETH Zurich and University of Bologna.
// Solderpad Hardware License, Version 0.51, see LICENSE for details.
// SPDX-License-Identifier: SHL-0.51
//
// Victor Isachi <victor.isachi@unibo.it>

module astral_wrap
  import carfield_pkg::*;
  import carfield_chip_pkg::*;
  import carfield_reg_pkg::*;
  import cheshire_pkg::*;
`ifdef SAFED_ENABLE
  import safety_island_pkg::*;
`endif
  import tlul_ot_pkg::*;
`ifdef SPATZ_ENABLE
  import spatz_cluster_pkg::*;
`endif
  import pkg_astral_padframe::*;
#(
  parameter cheshire_cfg_t Cfg = carfield_pkg::CarfieldCfgDefault,
  parameter int unsigned   HypNumPhys  = 1,
  parameter int unsigned   HypNumChips = 1,
  parameter type           reg_req_t   = logic,
  parameter type           reg_rsp_t   = logic
) (
  inout wire logic pad_periph_ref_clk_pad_i,
  inout wire logic pad_periph_ref_clk_pad_o,
  inout wire logic pad_periph_fll_bypass_pad,
  inout wire logic pad_periph_pwr_on_rst_n_pad,
  inout wire logic pad_periph_test_mode_pad,
  inout wire logic pad_periph_boot_mode_0_pad,
  inout wire logic pad_periph_boot_mode_1_pad,
  inout wire logic pad_periph_secure_boot_pad,
  inout wire logic pad_periph_jtag_tclk_pad,
  inout wire logic pad_periph_jtag_trst_n_pad,
  inout wire logic pad_periph_jtag_tms_pad,
  inout wire logic pad_periph_jtag_tdi_pad,
  inout wire logic pad_periph_jtag_tdo_pad,
  inout wire logic pad_periph_jtag_ot_tclk_pad,
  inout wire logic pad_periph_jtag_ot_trst_ni_pad,
  inout wire logic pad_periph_jtag_ot_tms_pad,
  inout wire logic pad_periph_jtag_ot_tdi_pad,
  inout wire logic pad_periph_jtag_ot_tdo_pad,
  inout wire logic pad_periph_hyper_cs_0_n_pad,
  inout wire logic pad_periph_hyper_cs_1_n_pad,
  inout wire logic pad_periph_hyper_ck_pad,
  inout wire logic pad_periph_hyper_ck_n_pad,
  inout wire logic pad_periph_hyper_rwds_pad,
  inout wire logic pad_periph_hyper_dq_0_pad,
  inout wire logic pad_periph_hyper_dq_1_pad,
  inout wire logic pad_periph_hyper_dq_2_pad,
  inout wire logic pad_periph_hyper_dq_3_pad,
  inout wire logic pad_periph_hyper_dq_4_pad,
  inout wire logic pad_periph_hyper_dq_5_pad,
  inout wire logic pad_periph_hyper_dq_6_pad,
  inout wire logic pad_periph_hyper_dq_7_pad,
  inout wire logic pad_periph_hyper_reset_n_pad,
  inout wire logic pad_periph_spw_data_in_pad,
  inout wire logic pad_periph_spw_strb_in_pad,
  inout wire logic pad_periph_spw_data_out_pad,
  inout wire logic pad_periph_spw_strb_out_pad,
  inout wire logic pad_periph_uart_tx_out_pad,
  inout wire logic pad_periph_uart_rx_in_pad,
  inout wire logic pad_periph_muxed_v_00_pad,
  inout wire logic pad_periph_muxed_v_01_pad,
  inout wire logic pad_periph_muxed_v_02_pad,
  inout wire logic pad_periph_muxed_v_03_pad,
  inout wire logic pad_periph_muxed_v_04_pad,
  inout wire logic pad_periph_muxed_v_05_pad,
  inout wire logic pad_periph_muxed_v_06_pad,
  inout wire logic pad_periph_muxed_v_07_pad,
  inout wire logic pad_periph_muxed_v_08_pad,
  inout wire logic pad_periph_muxed_v_09_pad,
  inout wire logic pad_periph_muxed_v_10_pad,
  inout wire logic pad_periph_muxed_v_11_pad,
  inout wire logic pad_periph_muxed_v_12_pad,
  inout wire logic pad_periph_muxed_v_13_pad,
  inout wire logic pad_periph_muxed_v_14_pad,
  inout wire logic pad_periph_muxed_v_15_pad,
  inout wire logic pad_periph_muxed_v_16_pad,
  inout wire logic pad_periph_muxed_v_17_pad,
  inout wire logic pad_periph_muxed_v_18_pad,
  inout wire logic pad_periph_muxed_v_19_pad,
  inout wire logic pad_periph_muxed_v_20_pad,
  inout wire logic pad_periph_muxed_v_21_pad
);

  ////////////////////////////
  // Carfield configuration //
  ////////////////////////////

  localparam cheshire_cfg_t CarfieldCfg = carfield_pkg::CarfieldCfgDefault;
  `CHESHIRE_TYPEDEF_ALL(carfield_, CarfieldCfg)


  ////////////////////////
  // Connection Signals //
  ////////////////////////

  // POR
  logic pwr_on_rst_n;
  logic ref_clk_pwr_on_rst_n;

  // clock signals
  logic ref_clk;
  // generated clocks
  logic host_clk, periph_clk, alt_clk, rt_clk;

  // secure boot mode signal
  logic secure_boot;

  //////////////
  // Padframe //
  //////////////

  // register interface
  // to padframe: ref clock domain
  carfield_reg_req_t padframe_refclk_cfg_reg_req;
  carfield_reg_rsp_t padframe_refclk_cfg_reg_rsp;

  // signal to pad
  static_connection_signals_pad2soc_t st_pad2soc_signals;
  static_connection_signals_soc2pad_t st_soc2pad_signals;
  port_signals_pad2soc_t              pad2soc_port_signals;
  port_signals_soc2pad_t              soc2pad_port_signals;

  // pad2soc

  // is secure boot enabled
  assign secure_boot = st_pad2soc_signals.periph.secure_boot_i;
  // safed bootmodes - no sefety island
  logic [1:0] bootmode_safe_isln_s;
  assign bootmode_safe_isln_s[0] = 1'b0;
  assign bootmode_safe_isln_s[1] = 1'b0;
  // secd bootmodes
  logic [1:0] bootmode_sec_isln_s;
  assign bootmode_sec_isln_s[0] = st_pad2soc_signals.periph.secure_boot_i;
  assign bootmode_sec_isln_s[1] = 1'b0;
  // hostd bootmodes
  logic [1:0] bootmode_host_s;
  assign bootmode_host_s[0] = st_pad2soc_signals.periph.boot_mode_0_i;
  assign bootmode_host_s[1] = st_pad2soc_signals.periph.boot_mode_1_i;
  // serial link
  logic [SlinkNumChan-1:0][SlinkNumLanes-1:0] serial_link_data_in_s;
  assign serial_link_data_in_s[0][0] = st_pad2soc_signals.periph.slink_0_i;
  assign serial_link_data_in_s[0][1] = st_pad2soc_signals.periph.slink_1_i;
  assign serial_link_data_in_s[0][2] = st_pad2soc_signals.periph.slink_2_i;
  assign serial_link_data_in_s[0][3] = st_pad2soc_signals.periph.slink_3_i;
  assign serial_link_data_in_s[0][4] = st_pad2soc_signals.periph.slink_4_i;
  assign serial_link_data_in_s[0][5] = st_pad2soc_signals.periph.slink_5_i;
  assign serial_link_data_in_s[0][6] = st_pad2soc_signals.periph.slink_6_i;
  assign serial_link_data_in_s[0][7] = st_pad2soc_signals.periph.slink_7_i;
  // hyperbus signals
  logic [HypNumPhys-1:0]      hyperbus_rwds_in_s;
  logic [HypNumPhys-1:0][7:0] hyperbus_data_in_s;
  // hyperbus 0
  assign hyperbus_data_in_s[0][0] = st_pad2soc_signals.periph.hyper_dq_0_i;
  assign hyperbus_data_in_s[0][1] = st_pad2soc_signals.periph.hyper_dq_1_i;
  assign hyperbus_data_in_s[0][2] = st_pad2soc_signals.periph.hyper_dq_2_i;
  assign hyperbus_data_in_s[0][3] = st_pad2soc_signals.periph.hyper_dq_3_i;
  assign hyperbus_data_in_s[0][4] = st_pad2soc_signals.periph.hyper_dq_4_i;
  assign hyperbus_data_in_s[0][5] = st_pad2soc_signals.periph.hyper_dq_5_i;
  assign hyperbus_data_in_s[0][6] = st_pad2soc_signals.periph.hyper_dq_6_i;
  assign hyperbus_data_in_s[0][7] = st_pad2soc_signals.periph.hyper_dq_7_i;
  assign hyperbus_rwds_in_s[0]    = st_pad2soc_signals.periph.hyper_rwds_i;

  // soc2pad

  // serial link
  logic [SlinkNumChan-1:0][SlinkNumLanes-1:0] serial_link_data_out_s;
  assign st_soc2pad_signals.periph.slink_0_o = serial_link_data_out_s[0][0];
  assign st_soc2pad_signals.periph.slink_1_o = serial_link_data_out_s[0][1];
  assign st_soc2pad_signals.periph.slink_2_o = serial_link_data_out_s[0][2];
  assign st_soc2pad_signals.periph.slink_3_o = serial_link_data_out_s[0][3];
  assign st_soc2pad_signals.periph.slink_4_o = serial_link_data_out_s[0][4];
  assign st_soc2pad_signals.periph.slink_5_o = serial_link_data_out_s[0][5];
  assign st_soc2pad_signals.periph.slink_6_o = serial_link_data_out_s[0][6];
  assign st_soc2pad_signals.periph.slink_7_o = serial_link_data_out_s[0][7];
  //hyperbus
  logic [HypNumPhys-1:0]                  hyperbus_rwds_out_s;
  logic [HypNumPhys-1:0]                  hyperbus_rwds_oe_s;
  logic [HypNumPhys-1:0]                  hyperbus_clk_o_s;
  logic [HypNumPhys-1:0]                  hyperbus_clk_no_s;
  logic [HypNumPhys-1:0]                  hyperbus_rst_no_s;
  logic [HypNumPhys-1:0][HypNumChips-1:0] hyperbus_cs_no_s;
  logic [HypNumPhys-1:0][7:0]             hyperbus_data_out_s;
  logic [HypNumPhys-1:0]                  hyperbus_data_oe_s;
  // hyper bus 0
  assign st_soc2pad_signals.periph.hyper_ck_no      = hyperbus_clk_no_s[0];
  assign st_soc2pad_signals.periph.hyper_ck_o       = hyperbus_clk_o_s[0];
  assign st_soc2pad_signals.periph.hyper_cs_0_no    = hyperbus_cs_no_s[0][0];
  assign st_soc2pad_signals.periph.hyper_cs_1_no    = hyperbus_cs_no_s[0][1];
  assign st_soc2pad_signals.periph.hyper_dq_0_o     = hyperbus_data_out_s[0][0];
  assign st_soc2pad_signals.periph.hyper_dq_1_o     = hyperbus_data_out_s[0][1];
  assign st_soc2pad_signals.periph.hyper_dq_2_o     = hyperbus_data_out_s[0][2];
  assign st_soc2pad_signals.periph.hyper_dq_3_o     = hyperbus_data_out_s[0][3];
  assign st_soc2pad_signals.periph.hyper_dq_4_o     = hyperbus_data_out_s[0][4];
  assign st_soc2pad_signals.periph.hyper_dq_5_o     = hyperbus_data_out_s[0][5];
  assign st_soc2pad_signals.periph.hyper_dq_6_o     = hyperbus_data_out_s[0][6];
  assign st_soc2pad_signals.periph.hyper_dq_7_o     = hyperbus_data_out_s[0][7];
  assign st_soc2pad_signals.periph.hyper_dq_oen_i   = hyperbus_data_oe_s[0];
  assign st_soc2pad_signals.periph.hyper_reset_no   = hyperbus_rst_no_s[0];
  assign st_soc2pad_signals.periph.hyper_rwds_o     = hyperbus_rwds_out_s[0];
  assign st_soc2pad_signals.periph.hyper_rwds_oen_i = hyperbus_rwds_oe_s[0];

  //  peripherals

  // pad2soc
  // spih
  logic [ 3:0]                                 spih_sd_i_s;
  assign spih_sd_i_s[0] = pad2soc_port_signals.periph.spi.spih_sd_0_i;
  assign spih_sd_i_s[1] = pad2soc_port_signals.periph.spi.spih_sd_1_i;
  assign spih_sd_i_s[2] = pad2soc_port_signals.periph.spi.spih_sd_2_i;
  assign spih_sd_i_s[3] = pad2soc_port_signals.periph.spi.spih_sd_3_i;
  // spih_ot
  logic [ 3:0]                                 spih_ot_sd_i_s;
  assign spih_ot_sd_i_s[0] = pad2soc_port_signals.periph.spi_ot.spih_ot_sd_0_i;
  assign spih_ot_sd_i_s[1] = pad2soc_port_signals.periph.spi_ot.spih_ot_sd_1_i;
  assign spih_ot_sd_i_s[2] = pad2soc_port_signals.periph.spi_ot.spih_ot_sd_2_i;
  assign spih_ot_sd_i_s[3] = pad2soc_port_signals.periph.spi_ot.spih_ot_sd_3_i;
  // ethernet
  logic [3:0]                                eth_rxd_i_s;
  assign eth_rxd_i_s[0]  = pad2soc_port_signals.periph.ethernet.eth_rxd_0_i;
  assign eth_rxd_i_s[1]  = pad2soc_port_signals.periph.ethernet.eth_rxd_1_i;
  assign eth_rxd_i_s[2]  = pad2soc_port_signals.periph.ethernet.eth_rxd_2_i;
  assign eth_rxd_i_s[3]  = pad2soc_port_signals.periph.ethernet.eth_rxd_3_i;

  // gpio
  logic [31:0]              gpio_out_s;
  logic [31:0]              gpio_tx_en_s;
  logic [31:0]              gpio_in_s;
  assign soc2pad_port_signals.periph.gpio.gpio_00_o = gpio_out_s[0];
  assign soc2pad_port_signals.periph.gpio.gpio_01_o = gpio_out_s[1];
  assign soc2pad_port_signals.periph.gpio.gpio_02_o = gpio_out_s[2];
  assign soc2pad_port_signals.periph.gpio.gpio_03_o = gpio_out_s[3];
  assign soc2pad_port_signals.periph.gpio.gpio_04_o = gpio_out_s[4];
  assign soc2pad_port_signals.periph.gpio.gpio_05_o = gpio_out_s[5];
  assign soc2pad_port_signals.periph.gpio.gpio_06_o = gpio_out_s[6];
  assign soc2pad_port_signals.periph.gpio.gpio_07_o = gpio_out_s[7];
  assign soc2pad_port_signals.periph.gpio.gpio_08_o = gpio_out_s[8];
  assign soc2pad_port_signals.periph.gpio.gpio_09_o = gpio_out_s[9];
  assign soc2pad_port_signals.periph.gpio.gpio_10_o = gpio_out_s[10];
  assign soc2pad_port_signals.periph.gpio.gpio_11_o = gpio_out_s[11];
  assign soc2pad_port_signals.periph.gpio.gpio_12_o = gpio_out_s[12];
  assign soc2pad_port_signals.periph.gpio.gpio_13_o = gpio_out_s[13];
  assign soc2pad_port_signals.periph.gpio.gpio_14_o = gpio_out_s[14];
  assign soc2pad_port_signals.periph.gpio.gpio_15_o = gpio_out_s[15];
  assign soc2pad_port_signals.periph.gpio.gpio_16_o = gpio_out_s[16];
  assign soc2pad_port_signals.periph.gpio.gpio_17_o = gpio_out_s[17];
  assign soc2pad_port_signals.periph.gpio.gpio_18_o = gpio_out_s[18];
  assign soc2pad_port_signals.periph.gpio.gpio_19_o = gpio_out_s[19];
  assign soc2pad_port_signals.periph.gpio.gpio_20_o = gpio_out_s[20];
  assign soc2pad_port_signals.periph.gpio.gpio_21_o = gpio_out_s[21];
  // GPIO 22-31 remain unconnected
  assign soc2pad_port_signals.periph.gpio.gpio_00_oen_i = gpio_tx_en_s[0];
  assign soc2pad_port_signals.periph.gpio.gpio_01_oen_i = gpio_tx_en_s[1];
  assign soc2pad_port_signals.periph.gpio.gpio_02_oen_i = gpio_tx_en_s[2];
  assign soc2pad_port_signals.periph.gpio.gpio_03_oen_i = gpio_tx_en_s[3];
  assign soc2pad_port_signals.periph.gpio.gpio_04_oen_i = gpio_tx_en_s[4];
  assign soc2pad_port_signals.periph.gpio.gpio_05_oen_i = gpio_tx_en_s[5];
  assign soc2pad_port_signals.periph.gpio.gpio_06_oen_i = gpio_tx_en_s[6];
  assign soc2pad_port_signals.periph.gpio.gpio_07_oen_i = gpio_tx_en_s[7];
  assign soc2pad_port_signals.periph.gpio.gpio_08_oen_i = gpio_tx_en_s[8];
  assign soc2pad_port_signals.periph.gpio.gpio_09_oen_i = gpio_tx_en_s[9];
  assign soc2pad_port_signals.periph.gpio.gpio_10_oen_i = gpio_tx_en_s[10];
  assign soc2pad_port_signals.periph.gpio.gpio_11_oen_i = gpio_tx_en_s[11];
  assign soc2pad_port_signals.periph.gpio.gpio_12_oen_i = gpio_tx_en_s[12];
  assign soc2pad_port_signals.periph.gpio.gpio_13_oen_i = gpio_tx_en_s[13];
  assign soc2pad_port_signals.periph.gpio.gpio_14_oen_i = gpio_tx_en_s[14];
  assign soc2pad_port_signals.periph.gpio.gpio_15_oen_i = gpio_tx_en_s[15];
  assign soc2pad_port_signals.periph.gpio.gpio_16_oen_i = gpio_tx_en_s[16];
  assign soc2pad_port_signals.periph.gpio.gpio_17_oen_i = gpio_tx_en_s[17];
  assign soc2pad_port_signals.periph.gpio.gpio_18_oen_i = gpio_tx_en_s[18];
  assign soc2pad_port_signals.periph.gpio.gpio_19_oen_i = gpio_tx_en_s[19];
  assign soc2pad_port_signals.periph.gpio.gpio_20_oen_i = gpio_tx_en_s[20];
  assign soc2pad_port_signals.periph.gpio.gpio_21_oen_i = gpio_tx_en_s[21];
  // GPIO 22-31 remain unconnected
  assign gpio_in_s[0]  = pad2soc_port_signals.periph.gpio.gpio_00_i;
  assign gpio_in_s[1]  = pad2soc_port_signals.periph.gpio.gpio_01_i;
  assign gpio_in_s[2]  = pad2soc_port_signals.periph.gpio.gpio_02_i;
  assign gpio_in_s[3]  = pad2soc_port_signals.periph.gpio.gpio_03_i;
  assign gpio_in_s[4]  = pad2soc_port_signals.periph.gpio.gpio_04_i;
  assign gpio_in_s[5]  = pad2soc_port_signals.periph.gpio.gpio_05_i;
  assign gpio_in_s[6]  = pad2soc_port_signals.periph.gpio.gpio_06_i;
  assign gpio_in_s[7]  = pad2soc_port_signals.periph.gpio.gpio_07_i;
  assign gpio_in_s[8]  = pad2soc_port_signals.periph.gpio.gpio_08_i;
  assign gpio_in_s[9]  = pad2soc_port_signals.periph.gpio.gpio_09_i;
  assign gpio_in_s[10] = pad2soc_port_signals.periph.gpio.gpio_10_i;
  assign gpio_in_s[11] = pad2soc_port_signals.periph.gpio.gpio_11_i;
  assign gpio_in_s[12] = pad2soc_port_signals.periph.gpio.gpio_12_i;
  assign gpio_in_s[13] = pad2soc_port_signals.periph.gpio.gpio_13_i;
  assign gpio_in_s[14] = pad2soc_port_signals.periph.gpio.gpio_14_i;
  assign gpio_in_s[15] = pad2soc_port_signals.periph.gpio.gpio_15_i;
  assign gpio_in_s[16] = pad2soc_port_signals.periph.gpio.gpio_16_i;
  assign gpio_in_s[17] = pad2soc_port_signals.periph.gpio.gpio_17_i;
  assign gpio_in_s[18] = pad2soc_port_signals.periph.gpio.gpio_18_i;
  assign gpio_in_s[19] = pad2soc_port_signals.periph.gpio.gpio_19_i;
  assign gpio_in_s[20] = pad2soc_port_signals.periph.gpio.gpio_20_i;
  assign gpio_in_s[21] = pad2soc_port_signals.periph.gpio.gpio_21_i;
  // GPI0 22-31 remain unconnected
  assign gpio_in_s[31:22] = '0;


  // soc2pad
  // uart-- carfield itf
  // spi
  logic                                        spih_sck_o_s;
  logic [ 1:0]                                 spih_csb_o_s;
  logic [ 3:0]                                 spih_sd_o_s;
  logic [ 3:0]                                 spih_sd_en_o_s;
  assign soc2pad_port_signals.periph.spi.spih_csb_0_o    = spih_csb_o_s[0]; // TO CHECK POLARITY OF THE SIGNAL
  assign soc2pad_port_signals.periph.spi.spih_csb_1_o    = spih_csb_o_s[1];
  assign soc2pad_port_signals.periph.spi.spih_sck_o      = spih_sck_o_s;
  assign soc2pad_port_signals.periph.spi.spih_sd_0_o     = spih_sd_o_s[0];
  assign soc2pad_port_signals.periph.spi.spih_sd_0_oen_i = spih_sd_en_o_s[0];
  assign soc2pad_port_signals.periph.spi.spih_sd_1_o     = spih_sd_o_s[1];
  assign soc2pad_port_signals.periph.spi.spih_sd_1_oen_i = spih_sd_en_o_s[1];
  assign soc2pad_port_signals.periph.spi.spih_sd_2_o     = spih_sd_o_s[2];
  assign soc2pad_port_signals.periph.spi.spih_sd_2_oen_i = spih_sd_en_o_s[2];
  assign soc2pad_port_signals.periph.spi.spih_sd_3_o     = spih_sd_o_s[3];
  assign soc2pad_port_signals.periph.spi.spih_sd_3_oen_i = spih_sd_en_o_s[3];
  // i2c -- carfield itf
  // spi_ot
  logic                                        spih_ot_sck_o_s;
  logic                                        spih_ot_csb_o_s;
  logic [ 3:0]                                 spih_ot_sd_o_s;
  logic [ 3:0]                                 spih_ot_sd_en_o_s;
  assign soc2pad_port_signals.periph.spi_ot.spih_ot_csb_0_o    = spih_ot_csb_o_s; // TO CHECK POLARITY OF THE SIGNAL
  assign soc2pad_port_signals.periph.spi_ot.spih_ot_sck_o      = spih_ot_sck_o_s;
  assign soc2pad_port_signals.periph.spi_ot.spih_ot_sd_0_o     = spih_ot_sd_o_s[0];
  assign soc2pad_port_signals.periph.spi_ot.spih_ot_sd_0_oen_i = spih_ot_sd_en_o_s[0];
  assign soc2pad_port_signals.periph.spi_ot.spih_ot_sd_1_o     = spih_ot_sd_o_s[1];
  assign soc2pad_port_signals.periph.spi_ot.spih_ot_sd_1_oen_i = spih_ot_sd_en_o_s[1];
  assign soc2pad_port_signals.periph.spi_ot.spih_ot_sd_2_o     = spih_ot_sd_o_s[2];
  assign soc2pad_port_signals.periph.spi_ot.spih_ot_sd_2_oen_i = spih_ot_sd_en_o_s[2];
  assign soc2pad_port_signals.periph.spi_ot.spih_ot_sd_3_o     = spih_ot_sd_o_s[3];
  assign soc2pad_port_signals.periph.spi_ot.spih_ot_sd_3_oen_i = spih_ot_sd_en_o_s[3];
  // can0 -- carfield itf
  // ethernet
  logic  [ 3:0]                                eth_txd_o_s;
  assign soc2pad_port_signals.periph.ethernet.eth_txd_0_o = eth_txd_o_s[0];
  assign soc2pad_port_signals.periph.ethernet.eth_txd_1_o = eth_txd_o_s[1];
  assign soc2pad_port_signals.periph.ethernet.eth_txd_2_o = eth_txd_o_s[2];
  assign soc2pad_port_signals.periph.ethernet.eth_txd_3_o = eth_txd_o_s[3];

  // External async register interface
  logic[1:0]              ext_reg_async_slv_req_src_out;
  logic[1:0]              ext_reg_async_slv_ack_src_in;
  carfield_reg_req_t[1:0] ext_reg_async_slv_data_src_out;
  logic[1:0]              ext_reg_async_slv_req_src_in;
  logic[1:0]              ext_reg_async_slv_ack_src_out;
  carfield_reg_rsp_t[1:0] ext_reg_async_slv_data_src_in;

  //////////////////////
  // Clock generation //
  //////////////////////

  localparam int unsigned NUM_FLL = 4;
  
  logic[NUM_FLL-1:0] clk_fll_out;
  logic[NUM_FLL-1:0] clk_fll_e;
  logic[NUM_FLL-1:0] fll_lock;
  logic[NUM_FLL-1:0] fll_pwd;
  logic[NUM_FLL-1:0] fll_test_mode;
  logic[NUM_FLL-1:0] fll_scan_e;
  logic[NUM_FLL-1:0] fll_scan_in;
  logic[NUM_FLL-1:0] fll_scan_out;
  logic[NUM_FLL-1:0] fll_scan_jtag_in;
  logic[NUM_FLL-1:0] fll_scan_jtag_out;

  // ref_clk
  assign ref_clk      = st_pad2soc_signals.periph.ref_clk_i;
  // power on reset
  assign pwr_on_rst_n = st_pad2soc_signals.periph.pwr_or_rst_ni;

  assign host_clk    = clk_fll_out[0];
  assign periph_clk  = clk_fll_out[1];
  assign alt_clk     = clk_fll_out[2];
  assign rt_clk      = clk_fll_out[3];
  assign clk_fll_e   = '{default: 1'b1};


  assign fll_pwd          = '{default: 1'b0};
  assign fll_test_mode    = '{default: 1'b0};
  assign fll_scan_e       = '{default: 1'b0};
  assign fll_scan_in      = '{default: 1'b0};
  assign fll_scan_jtag_in = '{default: 1'b0};  

  // synchronize power-on rst with ref clock (required by padframe)
  rstgen i_ref_clk_rstgen (
    .clk_i  (ref_clk),
    .rst_ni (pwr_on_rst_n),
    .test_mode_i ( '0 ),
    .rst_no (ref_clk_pwr_on_rst_n),
    .init_no ()
  );

`ifdef GF12_FLL
  gf12_fll_wrap #(
    .NUM_FLL        ( 4                  ),
    .FLL_REG_OFFSET ( 3                  ), // Addresses: 0x2002_0000, 0x2002_0008, 0x2002_0010, 0x2002_0018, 0x2002_0020, 0x2002_0028, ...
    .reg_req_t      ( carfield_reg_req_t ),
    .reg_rsp_t      ( carfield_reg_rsp_t )
  ) i_fll_wrap (
    .clk_ref_i           ( ref_clk                                ),
    .rst_n_i             ( ref_clk_pwr_on_rst_n                   ),
    .clk_bypass_i        ( st_pad2soc_signals.periph.ref_clk_i    ),
    .bypass_i            ( st_pad2soc_signals.periph.fll_bypass_i ),
    .async_req_i         ( ext_reg_async_slv_req_src_out[0]       ),
    .async_ack_o         ( ext_reg_async_slv_ack_src_in[0]        ),
    .async_data_i        ( ext_reg_async_slv_data_src_out[0]      ),
    .async_req_o         ( ext_reg_async_slv_req_src_in[0]        ),
    .async_ack_i         ( ext_reg_async_slv_ack_src_out[0]       ),
    .async_data_o        ( ext_reg_async_slv_data_src_in[0]       ),
    .clk_fll_out_o       ( clk_fll_out                            ),
    .clk_fll_e_i         ( clk_fll_e                              ),
    .fll_lock_o          ( fll_lock                               ),
    .fll_pwd_i           ( fll_pwd                                ),
    .fll_test_mode_i     ( fll_test_mode                          ),
    .fll_scan_e_i        ( fll_scan_e                             ),
    .fll_scan_in_i       ( fll_scan_in                            ),
    .fll_scan_out_o      ( fll_scan_out                           ),
    .fll_scan_jtag_in_i  ( fll_scan_jtag_in                       ),
    .fll_scan_jtag_out_o ( fll_scan_jtag_out                      )
  );
`else
  logic              dummy_rst;
  logic              dummy_clk;
  carfield_reg_rsp_t dummy_rsp;
  
  clk_rst_gen #(
    .ClkPeriod    ( 20ns ),
    .RstClkCycles ( 33   )
  ) i_dummy_fll (
    .clk_o  ( dummy_clk ),
    .rst_no ( dummy_rst )
  );
  assign clk_fll_out = '{default: dummy_clk & dummy_rst};
  assign fll_lock    = '{default: dummy_rst};

  reg_cdc_dst #(
  .CDC_KIND ( "cdc_4phase"       ),
  .req_t    ( carfield_reg_req_t ),
  .rsp_t    ( carfield_reg_rsp_t )
  ) i_fake_cdc (
    .dst_clk_i    ( dummy_clk                         ),
    .dst_rst_ni   ( dummy_rst                         ),
    .dst_req_o    (                                   ),
    .dst_rsp_i    ( dummy_rsp                         ),

    .async_req_i  ( ext_reg_async_slv_req_src_out[0]  ),
    .async_ack_o  ( ext_reg_async_slv_ack_src_in[0]   ),
    .async_data_i ( ext_reg_async_slv_data_src_out[0] ),

    .async_req_o  ( ext_reg_async_slv_req_src_in[0]   ),
    .async_ack_i  ( ext_reg_async_slv_ack_src_out[0]  ),
    .async_data_o ( ext_reg_async_slv_data_src_in[0]  )
   );
   assign dummy_rsp.ready = 1'b1;
   assign dummy_rsp.error = 1'b0;
   assign dummy_rsp.rdata = 'hCACABABE;
`endif

  //////////////////
  // Carfield SoC //
  //////////////////

  carfield      #(
    .Cfg         ( Cfg         ),
    .HypNumPhys  ( HypNumPhys  ),
    .HypNumChips ( HypNumChips ),
    .reg_req_t   ( carfield_reg_req_t ),
    .reg_rsp_t   ( carfield_reg_rsp_t )
  ) i_dut (
    .host_clk_i                 ( host_clk                                          ),
    .periph_clk_i               ( periph_clk                                        ),
    .alt_clk_i                  ( alt_clk                                           ),
    .rt_clk_i                   ( rt_clk                                            ),
    .pwr_on_rst_ni              ( pwr_on_rst_n                                      ),
    .test_mode_i                ( '0                                                ),
    .boot_mode_i                ( bootmode_host_s[1:0]                              ),
    .jtag_tck_i                 ( st_pad2soc_signals.periph.jtag_tclk_i             ),
    .jtag_trst_ni               ( st_pad2soc_signals.periph.jtag_trst_ni            ),
    .jtag_tms_i                 ( st_pad2soc_signals.periph.jtag_tms_i              ),
    .jtag_tdi_i                 ( st_pad2soc_signals.periph.jtag_tdi_i              ),
    .jtag_tdo_o                 ( st_soc2pad_signals.periph.jtag_tdo_o              ),
    .jtag_tdo_oe_o              (                                                   ),
    .jtag_ot_tck_i              ( st_pad2soc_signals.periph.jtag_ot_tclk_i          ),
    .jtag_ot_trst_ni            ( st_pad2soc_signals.periph.jtag_ot_trst_ni         ),
    .jtag_ot_tms_i              ( st_pad2soc_signals.periph.jtag_ot_tms_i           ),
    .jtag_ot_tdi_i              ( st_pad2soc_signals.periph.jtag_ot_tdi_i           ),
    .jtag_ot_tdo_o              ( st_soc2pad_signals.periph.jtag_ot_tdo_o           ),
    .jtag_ot_tdo_oe_o           (                                                   ),
    .bootmode_ot_i              ( bootmode_sec_isln_s                               ),
    .jtag_safety_island_tck_i   ( '0                                                ),
    .jtag_safety_island_trst_ni ( '0                                                ),
    .jtag_safety_island_tms_i   ( '0                                                ),
    .jtag_safety_island_tdi_i   ( '0                                                ),
    .jtag_safety_island_tdo_o   (                                                   ),
    .bootmode_safe_isln_i       ( bootmode_safe_isln_s                              ),
    .secure_boot_i              ( secure_boot                                       ),
    .uart_tx_o                  ( soc2pad_port_signals.periph.uart_tx_o             ),
    .uart_rx_i                  ( pad2soc_port_signals.periph.uart_rx_i             ),
    .uart_ot_tx_o               (                                                   ),
    .uart_ot_rx_i               ( '0                                                ),
    .i2c_sda_o                  ( soc2pad_port_signals.periph.i2c.i2c_sda_o         ),
    .i2c_sda_i                  ( pad2soc_port_signals.periph.i2c.i2c_sda_i         ),
    .i2c_sda_en_o               ( soc2pad_port_signals.periph.i2c.i2c_sda_en_o      ),
    .i2c_scl_o                  ( soc2pad_port_signals.periph.i2c.i2c_scl_o         ),
    .i2c_scl_i                  ( pad2soc_port_signals.periph.i2c.i2c_scl_i         ),
    .i2c_scl_en_o               ( soc2pad_port_signals.periph.i2c.i2c_scl_en_o      ),
    .spih_sck_o                 ( spih_sck_o_s                                      ),
    .spih_sck_en_o              (                                                   ),
    .spih_csb_o                 ( spih_csb_o_s                                      ),
    .spih_csb_en_o              (                                                   ),
    .spih_sd_o                  ( spih_sd_o_s                                       ),
    .spih_sd_en_o               ( spih_sd_en_o_s                                    ),
    .spih_sd_i                  ( spih_sd_i_s                                       ),
    // spi secd
    .spih_ot_sck_o              ( spih_ot_sck_o_s                                   ),
    .spih_ot_sck_en_o           (                                                   ),
    .spih_ot_csb_o              ( spih_ot_csb_o_s                                   ),
    .spih_ot_csb_en_o           (                                                   ),
    .spih_ot_sd_o               ( spih_ot_sd_o_s                                    ),
    .spih_ot_sd_en_o            ( spih_ot_sd_en_o_s                                 ),
    .spih_ot_sd_i               ( spih_ot_sd_i_s                                    ),
    // ethernet
    .eth_rxck_i                 ( pad2soc_port_signals.periph.ethernet.eth_rxck_i   ),
    .eth_rxctl_i                ( pad2soc_port_signals.periph.ethernet.eth_rxctl_i  ),
    .eth_rxd_i                  ( eth_rxd_i_s                                       ),
    .eth_md_i                   ( pad2soc_port_signals.periph.ethernet.eth_md_o     ),
    .eth_txck_o                 ( soc2pad_port_signals.periph.ethernet.eth_txck_o   ),
    .eth_txctl_o                ( soc2pad_port_signals.periph.ethernet.eth_txctl_o  ),
    .eth_txd_o                  ( eth_txd_o_s                                       ),
    .eth_md_o                   ( soc2pad_port_signals.periph.ethernet.eth_md_i     ),
    .eth_md_oe                  ( soc2pad_port_signals.periph.ethernet.eth_md_oen_i ),
    .eth_mdc_o                  ( soc2pad_port_signals.periph.ethernet.eth_mdc_o    ),
    .eth_rst_n_o                ( soc2pad_port_signals.periph.ethernet.eth_rst_no   ),
    // can bus
    .can_rx_i                   ( pad2soc_port_signals.periph.can.can_rx_i          ),
    .can_tx_o                   ( soc2pad_port_signals.periph.can.can_tx_o          ),
    // gpios
    .gpio_i                     ( gpio_in_s                                         ),
    .gpio_o                     ( gpio_out_s                                        ),
    .gpio_en_o                  ( gpio_tx_en_s                                      ),
    // serial link
    .slink_rcv_clk_i            ( st_pad2soc_signals.periph.slink_rcv_clk_i         ),
    .slink_rcv_clk_o            ( st_soc2pad_signals.periph.slink_rcv_clk_o         ),
    .slink_i                    ( serial_link_data_in_s                             ),
    .slink_o                    ( serial_link_data_out_s                            ),
    // hyperbus
    .hyper_cs_no                ( hyperbus_cs_no_s                                  ),
    .hyper_ck_o                 ( hyperbus_clk_o_s                                  ),
    .hyper_ck_no                ( hyperbus_clk_no_s                                 ),
    .hyper_rwds_o               ( hyperbus_rwds_out_s                               ),
    .hyper_rwds_i               ( hyperbus_rwds_in_s                                ),
    .hyper_rwds_oe_o            ( hyperbus_rwds_oe_s                                ),
    .hyper_dq_i                 ( hyperbus_data_in_s                                ),
    .hyper_dq_o                 ( hyperbus_data_out_s                               ),
    .hyper_dq_oe_o              ( hyperbus_data_oe_s                                ),
    .hyper_reset_no             ( hyperbus_rst_no_s                                 ),
    .ext_reg_async_slv_req_o    ( ext_reg_async_slv_req_src_out                     ),
    .ext_reg_async_slv_ack_i    ( ext_reg_async_slv_ack_src_in                      ),
    .ext_reg_async_slv_data_o   ( ext_reg_async_slv_data_src_out                    ),
    .ext_reg_async_slv_req_i    ( ext_reg_async_slv_req_src_in                      ),
    .ext_reg_async_slv_ack_o    ( ext_reg_async_slv_ack_src_out                     ),
    .ext_reg_async_slv_data_i   ( ext_reg_async_slv_data_src_in                     ),
    // Debug Signals
    .debug_signals_o            (                                                   )
  );

  //////////////
  // Padframe //
  //////////////

  reg_cdc_dst #(
     .CDC_KIND ( "cdc_4phase"       ),
     .req_t    ( carfield_reg_req_t ),
     .rsp_t    ( carfield_reg_rsp_t )
  ) i_reg_cdc_dst_padframe (
      .dst_clk_i   ( ref_clk                           ),
      .dst_rst_ni  ( ref_clk_pwr_on_rst_n              ),
      .dst_req_o   ( padframe_refclk_cfg_reg_req       ),
      .dst_rsp_i   ( padframe_refclk_cfg_reg_rsp       ),

      .async_req_i ( ext_reg_async_slv_req_src_out[1]  ),
      .async_ack_o ( ext_reg_async_slv_ack_src_in[1]   ),
      .async_data_i( ext_reg_async_slv_data_src_out[1] ),

      .async_req_o ( ext_reg_async_slv_req_src_in[1]   ),
      .async_ack_i ( ext_reg_async_slv_ack_src_out[1]  ),
      .async_data_o( ext_reg_async_slv_data_src_in[1]  )
  );

  astral_padframe #(
    .req_t  ( carfield_reg_req_t ),
    .resp_t ( carfield_reg_rsp_t )
  ) i_astral_padframe (
    .clk_i  ( ref_clk              ),
    .rst_ni ( ref_clk_pwr_on_rst_n ),
    .static_connection_signals_pad2soc ( st_pad2soc_signals ),
    .static_connection_signals_soc2pad ( st_soc2pad_signals ),
    .port_signals_pad2soc ( pad2soc_port_signals ),
    .port_signals_soc2pad ( soc2pad_port_signals ),
    // Landing Pads
    .pad_periph_ref_clk_pad_i,
    .pad_periph_ref_clk_pad_o,
    .pad_periph_fll_bypass_pad,
    .pad_periph_pwr_on_rst_n_pad,
    .pad_periph_test_mode_pad,
    .pad_periph_boot_mode_0_pad,
    .pad_periph_boot_mode_1_pad,
    .pad_periph_secure_boot_pad,
    .pad_periph_jtag_tclk_pad,
    .pad_periph_jtag_trst_n_pad,
    .pad_periph_jtag_tms_pad,
    .pad_periph_jtag_tdi_pad,
    .pad_periph_jtag_tdo_pad,
    .pad_periph_jtag_ot_tclk_pad,
    .pad_periph_jtag_ot_trst_ni_pad,
    .pad_periph_jtag_ot_tms_pad,
    .pad_periph_jtag_ot_tdi_pad,
    .pad_periph_jtag_ot_tdo_pad,
    .pad_periph_hyper_cs_0_n_pad,
    .pad_periph_hyper_cs_1_n_pad,
    .pad_periph_hyper_ck_pad,
    .pad_periph_hyper_ck_n_pad,
    .pad_periph_hyper_rwds_pad,
    .pad_periph_hyper_dq_0_pad,
    .pad_periph_hyper_dq_1_pad,
    .pad_periph_hyper_dq_2_pad,
    .pad_periph_hyper_dq_3_pad,
    .pad_periph_hyper_dq_4_pad,
    .pad_periph_hyper_dq_5_pad,
    .pad_periph_hyper_dq_6_pad,
    .pad_periph_hyper_dq_7_pad,
    .pad_periph_hyper_reset_n_pad,
    .pad_periph_spw_data_in_pad,
    .pad_periph_spw_strb_in_pad,
    .pad_periph_spw_data_out_pad,
    .pad_periph_spw_strb_out_pad,
    .pad_periph_uart_tx_out_pad,
    .pad_periph_uart_rx_in_pad,
    .pad_periph_muxed_v_00_pad,
    .pad_periph_muxed_v_01_pad,
    .pad_periph_muxed_v_02_pad,
    .pad_periph_muxed_v_03_pad,
    .pad_periph_muxed_v_04_pad,
    .pad_periph_muxed_v_05_pad,
    .pad_periph_muxed_v_06_pad,
    .pad_periph_muxed_v_07_pad,
    .pad_periph_muxed_v_08_pad,
    .pad_periph_muxed_v_09_pad,
    .pad_periph_muxed_v_10_pad,
    .pad_periph_muxed_v_11_pad,
    .pad_periph_muxed_v_12_pad,
    .pad_periph_muxed_v_13_pad,
    .pad_periph_muxed_v_14_pad,
    .pad_periph_muxed_v_15_pad,
    .pad_periph_muxed_v_16_pad,
    .pad_periph_muxed_v_17_pad,
    .pad_periph_muxed_v_18_pad,
    .pad_periph_muxed_v_19_pad,
    .pad_periph_muxed_v_20_pad,
    .pad_periph_muxed_v_21_pad,
    // Config Interface
    .config_req_i ( padframe_refclk_cfg_reg_req ),
    .config_rsp_o ( padframe_refclk_cfg_reg_rsp )
  );

endmodule: astral_wrap
