// Copyright 2023 ETH Zurich and University of Bologna.
// Solderpad Hardware License, Version 0.51, see LICENSE for details.
// SPDX-License-Identifier: SHL-0.51
//
// Victor Isachi <victor.isachi@unibo.it>

`include "cheshire/typedef.svh"
`include "axi/typedef.svh"
`include "apb/typedef.svh"

module astral_wrap
  import carfield_pkg::*;
  import carfield_chip_pkg::*;
  import carfield_reg_pkg::*;
  import cheshire_pkg::*;
  import pkg_astral_padframe::*;
#(
  parameter cheshire_cfg_t Cfg = carfield_pkg::CarfieldCfgDefault
) (
  inout wire logic pad_botl_ot_boot_mode_pad,
  inout wire logic pad_botl_jtag_ot_tclk_pad,
  inout wire logic pad_botl_jtag_ot_trst_n_pad,
  inout wire logic pad_botl_jtag_ot_tms_pad,
  inout wire logic pad_botl_jtag_ot_tdi_pad,
  inout wire logic pad_botl_jtag_ot_tdo_pad,
  inout wire logic pad_botl_ot_uart_tx_pad,
  inout wire logic pad_botl_ot_uart_rx_pad,
  inout wire logic pad_botl_spih_sck_pad,
  inout wire logic pad_botl_spih_csb_pad,
  inout wire logic pad_botl_spih_sd_0_pad,
  inout wire logic pad_botl_spih_sd_1_pad,
  inout wire logic pad_botl_spih_sd_2_pad,
  inout wire logic pad_botl_spih_sd_3_pad,
  inout wire logic pad_botl_gpio_2_pad,
  inout wire logic pad_botl_gpio_3_pad,
  inout wire logic pad_botl_spih_ot_sd_1_pad,
  inout wire logic pad_botl_spih_ot_sd_2_pad,
  inout wire logic pad_botl_spih_ot_sd_3_pad,
  inout wire logic pad_botl_ref_clk_pad,
  inout wire logic pad_botl_fll_host_pad,
  inout wire logic pad_botl_fll_secd_pad,
  inout wire logic pad_botl_fll_bypass_pad,
  inout wire logic pad_botl_pwr_on_rst_n_pad,
  inout wire logic pad_botl_boot_mode_0_pad,
  inout wire logic pad_botl_boot_mode_1_pad,
  inout wire logic pad_botl_secure_boot_pad,
  inout wire logic pad_botl_jtag_tclk_pad,
  inout wire logic pad_botl_jtag_trst_n_pad,
  inout wire logic pad_botl_jtag_tms_pad,
  inout wire logic pad_botl_jtag_tdi_pad,
  inout wire logic pad_botl_jtag_tdo_pad,
  inout wire logic pad_botl_uart_tx_pad,
  inout wire logic pad_botl_uart_rx_pad,
  inout wire logic pad_botl_gpio_0_pad,
  inout wire logic pad_botl_gpio_1_pad,
  inout wire logic pad_botl_spih_ot_sck_pad,
  inout wire logic pad_botl_spih_ot_csb_pad,
  inout wire logic pad_botl_spih_ot_sd_0_pad,
  // --- HYPERBUS PADS (Hyper 0)
  inout wire logic pad_botl_hyper_0_cs_0_n_pad,
  inout wire logic pad_botl_hyper_0_cs_1_n_pad,
  inout wire logic pad_botl_hyper_0_ck_pad,
  inout wire logic pad_botl_hyper_0_ck_n_pad,
  inout wire logic pad_botl_hyper_0_rwds_pad,
  inout wire logic pad_botl_hyper_0_dq_0_pad,
  inout wire logic pad_botl_hyper_0_dq_1_pad,
  inout wire logic pad_botl_hyper_0_dq_2_pad,
  inout wire logic pad_botl_hyper_0_dq_3_pad,
  inout wire logic pad_botl_hyper_0_dq_4_pad,
  inout wire logic pad_botl_hyper_0_dq_5_pad,
  inout wire logic pad_botl_hyper_0_dq_6_pad,
  inout wire logic pad_botl_hyper_0_dq_7_pad,
  inout wire logic pad_botl_hyper_0_reset_n_pad,
  // --- HYPERBUS PADS (Hyper 1)
  inout wire logic pad_botl_hyper_1_cs_0_n_pad,
  inout wire logic pad_botl_hyper_1_cs_1_n_pad,
  inout wire logic pad_botl_hyper_1_ck_pad,
  inout wire logic pad_botl_hyper_1_ck_n_pad,
  inout wire logic pad_botl_hyper_1_rwds_pad,
  inout wire logic pad_botl_hyper_1_dq_0_pad,
  inout wire logic pad_botl_hyper_1_dq_1_pad,
  inout wire logic pad_botl_hyper_1_dq_2_pad,
  inout wire logic pad_botl_hyper_1_dq_3_pad,
  inout wire logic pad_botl_hyper_1_dq_4_pad,
  inout wire logic pad_botl_hyper_1_dq_5_pad,
  inout wire logic pad_botl_hyper_1_dq_6_pad,
  inout wire logic pad_botl_hyper_1_dq_7_pad,
  inout wire logic pad_botl_hyper_1_reset_n_pad
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
  //port_signals_pad2soc_t              pad2soc_port_signals;
  //port_signals_soc2pad_t              soc2pad_port_signals;

  // pad2soc

  // is secure boot enabled
  assign secure_boot = st_pad2soc_signals.botl.secure_boot_i;
  // safed bootmodes - no sefety island
  logic [1:0] bootmode_safe_isln_s;
  assign bootmode_safe_isln_s[0] = 1'b0;
  assign bootmode_safe_isln_s[1] = 1'b0;
  // secd bootmodes
  logic [1:0] bootmode_sec_isln_s;
  assign bootmode_sec_isln_s[0] = st_pad2soc_signals.botl.ot_boot_mode_i;
  assign bootmode_sec_isln_s[1] = 1'b0;
  // hostd bootmodes
  logic [1:0] bootmode_host_s;
  assign bootmode_host_s[0] = st_pad2soc_signals.botl.boot_mode_i_0;
  assign bootmode_host_s[1] = st_pad2soc_signals.botl.boot_mode_i_1;
  // serial link
  logic [SlinkNumChan-1:0][SlinkNumLanes-1:0] serial_link_data_in_s; //left unconnected
  assign serial_link_data_in_s[0][0] = '0;
  assign serial_link_data_in_s[0][1] = '0;
  assign serial_link_data_in_s[0][2] = '0;
  assign serial_link_data_in_s[0][3] = '0;
  assign serial_link_data_in_s[0][4] = '0;
  assign serial_link_data_in_s[0][5] = '0;
  assign serial_link_data_in_s[0][6] = '0;
  assign serial_link_data_in_s[0][7] = '0;
  // hyperbus signals
  logic [carfield_pkg::NumHyperBusPhys-1:0] hyperbus_rwds_in_s;
  logic [carfield_pkg::NumHyperBusPhys-1:0][7:0] hyperbus_data_in_s;
  // hyperbus 0
  assign hyperbus_data_in_s[0][0] = st_pad2soc_signals.botl.hyper_dq_i_0_0;
  assign hyperbus_data_in_s[0][1] = st_pad2soc_signals.botl.hyper_dq_i_0_1;
  assign hyperbus_data_in_s[0][2] = st_pad2soc_signals.botl.hyper_dq_i_0_2;
  assign hyperbus_data_in_s[0][3] = st_pad2soc_signals.botl.hyper_dq_i_0_3;
  assign hyperbus_data_in_s[0][4] = st_pad2soc_signals.botl.hyper_dq_i_0_4;
  assign hyperbus_data_in_s[0][5] = st_pad2soc_signals.botl.hyper_dq_i_0_5;
  assign hyperbus_data_in_s[0][6] = st_pad2soc_signals.botl.hyper_dq_i_0_6;
  assign hyperbus_data_in_s[0][7] = st_pad2soc_signals.botl.hyper_dq_i_0_7;
  assign hyperbus_rwds_in_s[0]    = st_pad2soc_signals.botl.hyper_rwds_i_0;
  // hyperbus 1
  assign hyperbus_data_in_s[1][0] = st_pad2soc_signals.botl.hyper_dq_i_1_0;
  assign hyperbus_data_in_s[1][1] = st_pad2soc_signals.botl.hyper_dq_i_1_1;
  assign hyperbus_data_in_s[1][2] = st_pad2soc_signals.botl.hyper_dq_i_1_2;
  assign hyperbus_data_in_s[1][3] = st_pad2soc_signals.botl.hyper_dq_i_1_3;
  assign hyperbus_data_in_s[1][4] = st_pad2soc_signals.botl.hyper_dq_i_1_4;
  assign hyperbus_data_in_s[1][5] = st_pad2soc_signals.botl.hyper_dq_i_1_5;
  assign hyperbus_data_in_s[1][6] = st_pad2soc_signals.botl.hyper_dq_i_1_6;
  assign hyperbus_data_in_s[1][7] = st_pad2soc_signals.botl.hyper_dq_i_1_7;
  assign hyperbus_rwds_in_s[1]    = st_pad2soc_signals.botl.hyper_rwds_i_1;

  // soc2pad

  // serial link
  logic [SlinkNumChan-1:0][SlinkNumLanes-1:0] serial_link_data_out_s; //left unconnected
  // assign soc2pad_port_signals.periph.serial_link.slink_v_0_o = serial_link_data_out_s[0][0];
  // assign soc2pad_port_signals.periph.serial_link.slink_v_1_o = serial_link_data_out_s[0][1];
  // assign soc2pad_port_signals.periph.serial_link.slink_v_2_o = serial_link_data_out_s[0][2];
  // assign soc2pad_port_signals.periph.serial_link.slink_v_3_o = serial_link_data_out_s[0][3];
  // assign soc2pad_port_signals.periph.serial_link.slink_h_0_o = serial_link_data_out_s[0][4];
  // assign soc2pad_port_signals.periph.serial_link.slink_h_1_o = serial_link_data_out_s[0][5];
  // assign soc2pad_port_signals.periph.serial_link.slink_h_2_o = serial_link_data_out_s[0][6];
  // assign soc2pad_port_signals.periph.serial_link.slink_h_3_o = serial_link_data_out_s[0][7];
  //hyperbus
  // hyper bus 0

  //  peripherals

  // pad2soc
  // spih
  logic [ 3:0] spih_sd_i_s;
  assign spih_sd_i_s[0] = st_pad2soc_signals.botl.spih_sd_i_0;
  assign spih_sd_i_s[1] = st_pad2soc_signals.botl.spih_sd_i_1;
  assign spih_sd_i_s[2] = st_pad2soc_signals.botl.spih_sd_i_2;
  assign spih_sd_i_s[3] = st_pad2soc_signals.botl.spih_sd_i_3;
  // spih_ot
  logic [ 3:0] spih_ot_sd_i_s;
  assign spih_ot_sd_i_s[0] = st_pad2soc_signals.botl.spih_ot_sd_i_0;
  assign spih_ot_sd_i_s[1] = st_pad2soc_signals.botl.spih_ot_sd_i_1;
  assign spih_ot_sd_i_s[2] = st_pad2soc_signals.botl.spih_ot_sd_i_2;
  assign spih_ot_sd_i_s[3] = st_pad2soc_signals.botl.spih_ot_sd_i_3;
  // ethernet
  logic [3:0] eth_rxd_i_s;
  assign eth_rxd_i_s[0] = '0;
  assign eth_rxd_i_s[1] = '0;
  assign eth_rxd_i_s[2] = '0;
  assign eth_rxd_i_s[3] = '0;

  // gpio
  logic [31:0] gpio_out_s;
  logic [31:0] gpio_tx_en_s;
  logic [31:0] gpio_in_s;
  assign st_soc2pad_signals.botl.gpio_v_o_0  = gpio_out_s[0];
  assign st_soc2pad_signals.botl.gpio_v_o_1  = gpio_out_s[1];
  assign st_soc2pad_signals.botl.gpio_v_o_2  = gpio_out_s[2];
  assign st_soc2pad_signals.botl.gpio_v_o_3  = gpio_out_s[3];
  // assign st_soc2pad_signals.botl.gpio_v_4_o  = gpio_out_s[4];
  // assign st_soc2pad_signals.botl.gpio_v_5_o  = gpio_out_s[5];
  // assign st_soc2pad_signals.botl.gpio_v_6_o  = gpio_out_s[6];
  // assign st_soc2pad_signals.botl.gpio_v_7_o  = gpio_out_s[7];
  // assign st_soc2pad_signals.botl.gpio_v_8_o  = gpio_out_s[8];
  // assign st_soc2pad_signals.botl.gpio_v_9_o  = gpio_out_s[9];
  // assign st_soc2pad_signals.botl.gpio_v_10_o = gpio_out_s[10];
  // assign st_soc2pad_signals.botl.gpio_v_11_o = gpio_out_s[11];
  // assign st_soc2pad_signals.botl.gpio_v_12_o = gpio_out_s[12];
  // assign st_soc2pad_signals.botl.gpio_v_13_o = gpio_out_s[13];
  // assign st_soc2pad_signals.botl.gpio_v_14_o = gpio_out_s[14];
  // assign st_soc2pad_signals.botl.gpio_v_15_o = gpio_out_s[15];
  // assign st_soc2pad_signals.botl.gpio_v_16_o = gpio_out_s[16];
  // assign st_soc2pad_signals.botl.gpio_v_17_o = gpio_out_s[17];
  // assign st_soc2pad_signals.botl.gpio_h_0_o  = gpio_out_s[18];
  // assign st_soc2pad_signals.botl.gpio_h_1_o  = gpio_out_s[19];
  // assign st_soc2pad_signals.botl.gpio_h_2_o  = gpio_out_s[20];
  // assign st_soc2pad_signals.botl.gpio_h_3_o  = gpio_out_s[21];
  // GPIO 4-31 remain unconnected
  assign st_soc2pad_signals.botl.gpio_v_oen_i_0  = gpio_tx_en_s[0];
  assign st_soc2pad_signals.botl.gpio_v_oen_i_1  = gpio_tx_en_s[1];
  assign st_soc2pad_signals.botl.gpio_v_oen_i_2  = gpio_tx_en_s[2];
  assign st_soc2pad_signals.botl.gpio_v_oen_i_3  = gpio_tx_en_s[3];
  // assign st_soc2pad_signals.botl.gpio_v_4_oen_i  = gpio_tx_en_s[4];
  // assign st_soc2pad_signals.botl.gpio_v_5_oen_i  = gpio_tx_en_s[5];
  // assign st_soc2pad_signals.botl.gpio_v_6_oen_i  = gpio_tx_en_s[6];
  // assign st_soc2pad_signals.botl.gpio_v_7_oen_i  = gpio_tx_en_s[7];
  // assign st_soc2pad_signals.botl.gpio_v_8_oen_i  = gpio_tx_en_s[8];
  // assign st_soc2pad_signals.botl.gpio_v_9_oen_i  = gpio_tx_en_s[9];
  // assign st_soc2pad_signals.botl.gpio_v_10_oen_i = gpio_tx_en_s[10];
  // assign st_soc2pad_signals.botl.gpio_v_11_oen_i = gpio_tx_en_s[11];
  // assign st_soc2pad_signals.botl.gpio_v_12_oen_i = gpio_tx_en_s[12];
  // assign st_soc2pad_signals.botl.gpio_v_13_oen_i = gpio_tx_en_s[13];
  // assign st_soc2pad_signals.botl.gpio_v_14_oen_i = gpio_tx_en_s[14];
  // assign st_soc2pad_signals.botl.gpio_v_15_oen_i = gpio_tx_en_s[15];
  // assign st_soc2pad_signals.botl.gpio_v_16_oen_i = gpio_tx_en_s[16];
  // assign st_soc2pad_signals.botl.gpio_v_17_oen_i = gpio_tx_en_s[17];
  // assign st_soc2pad_signals.botl.gpio_h_0_oen_i  = gpio_tx_en_s[18];
  // assign st_soc2pad_signals.botl.gpio_h_1_oen_i  = gpio_tx_en_s[19];
  // assign st_soc2pad_signals.botl.gpio_h_2_oen_i  = gpio_tx_en_s[20];
  // assign st_soc2pad_signals.botl.gpio_h_3_oen_i  = gpio_tx_en_s[21];
  // GPIO 4-31 remain unconnected
  assign gpio_in_s[0]  = st_pad2soc_signals.botl.gpio_v_i_0;
  assign gpio_in_s[1]  = st_pad2soc_signals.botl.gpio_v_i_1;
  assign gpio_in_s[2]  = st_pad2soc_signals.botl.gpio_v_i_2;
  assign gpio_in_s[3]  = st_pad2soc_signals.botl.gpio_v_i_3;
  // assign gpio_in_s[4]  = st_pad2soc_signals.botl.gpio_v_4_i;
  // assign gpio_in_s[5]  = st_pad2soc_signals.botl.gpio_v_5_i;
  // assign gpio_in_s[6]  = st_pad2soc_signals.botl.gpio_v_6_i;
  // assign gpio_in_s[7]  = st_pad2soc_signals.botl.gpio_v_7_i;
  // assign gpio_in_s[8]  = st_pad2soc_signals.botl.gpio_v_8_i;
  // assign gpio_in_s[9]  = st_pad2soc_signals.botl.gpio_v_9_i;
  // assign gpio_in_s[10] = st_pad2soc_signals.botl.gpio_v_10_i;
  // assign gpio_in_s[11] = st_pad2soc_signals.botl.gpio_v_11_i;
  // assign gpio_in_s[12] = st_pad2soc_signals.botl.gpio_v_12_i;
  // assign gpio_in_s[13] = st_pad2soc_signals.botl.gpio_v_13_i;
  // assign gpio_in_s[14] = st_pad2soc_signals.botl.gpio_v_14_i;
  // assign gpio_in_s[15] = st_pad2soc_signals.botl.gpio_v_15_i;
  // assign gpio_in_s[16] = st_pad2soc_signals.botl.gpio_v_16_i;
  // assign gpio_in_s[17] = st_pad2soc_signals.botl.gpio_v_17_i;
  // assign gpio_in_s[18] = st_pad2soc_signals.botl.gpio_h_0_i;
  // assign gpio_in_s[19] = st_pad2soc_signals.botl.gpio_h_1_i;
  // assign gpio_in_s[20] = st_pad2soc_signals.botl.gpio_h_2_i;
  // assign gpio_in_s[21] = st_pad2soc_signals.botl.gpio_h_3_i;
  // GPI0 4-31 remain unconnected
  assign gpio_in_s[31:4] = '0;

  // soc2pad
  // uart-- carfield itf
  // spi
  logic       spih_sck_o_s;
  logic [1:0] spih_csb_o_s;
  logic [3:0] spih_sd_o_s;
  logic [3:0] spih_sd_en_o_s;
  // TODO: CHECK POLARITY OF THE SIGNAL (SPI CS)
  //assign st_soc2pad_signals.botl.spih_csb_o_0    = spih_csb_o_s[0];
  assign st_soc2pad_signals.botl.spih_csb_o_1    = spih_csb_o_s[1];
  assign st_soc2pad_signals.botl.spih_sck_o      = spih_sck_o_s;
  assign st_soc2pad_signals.botl.spih_sd_o_0     = spih_sd_o_s[0];
  assign st_soc2pad_signals.botl.spih_sd_o_1     = spih_sd_o_s[1];
  assign st_soc2pad_signals.botl.spih_sd_o_2     = spih_sd_o_s[2];
  assign st_soc2pad_signals.botl.spih_sd_o_3     = spih_sd_o_s[3];
  assign st_soc2pad_signals.botl.spih_sd_oen_i_0 = spih_sd_en_o_s[0];
  assign st_soc2pad_signals.botl.spih_sd_oen_i_1 = spih_sd_en_o_s[1];
  assign st_soc2pad_signals.botl.spih_sd_oen_i_2 = spih_sd_en_o_s[2];
  assign st_soc2pad_signals.botl.spih_sd_oen_i_3 = spih_sd_en_o_s[3];
  // i2c -- carfield itf
  // spi_ot
  logic       spih_ot_sck_o_s;
  logic       spih_ot_csb_o_s;
  logic [3:0] spih_ot_sd_o_s;
  logic [3:0] spih_ot_sd_en_o_s;
  // TODO: CHECK POLARITY OF THE SIGNAL (SPI CS)
  assign st_soc2pad_signals.botl.spih_ot_csb_o      = spih_ot_csb_o_s;
  assign st_soc2pad_signals.botl.spih_ot_sck_o      = spih_ot_sck_o_s;
  assign st_soc2pad_signals.botl.spih_ot_sd_o_0     = spih_ot_sd_o_s[0];
  assign st_soc2pad_signals.botl.spih_ot_sd_o_1     = spih_ot_sd_o_s[1];
  assign st_soc2pad_signals.botl.spih_ot_sd_o_2     = spih_ot_sd_o_s[2];
  assign st_soc2pad_signals.botl.spih_ot_sd_o_3     = spih_ot_sd_o_s[3];
  assign st_soc2pad_signals.botl.spih_ot_sd_oen_i_0 = spih_ot_sd_en_o_s[0];
  assign st_soc2pad_signals.botl.spih_ot_sd_oen_i_1 = spih_ot_sd_en_o_s[1];
  assign st_soc2pad_signals.botl.spih_ot_sd_oen_i_2 = spih_ot_sd_en_o_s[2];
  assign st_soc2pad_signals.botl.spih_ot_sd_oen_i_3 = spih_ot_sd_en_o_s[3];
  // can0 -- carfield itf
  // ethernet
  logic [3:0] eth_txd_o_s;
  // assign soc2pad_port_signals.periph.ethernet.eth_txd_0_o = eth_txd_o_s[0];
  // assign soc2pad_port_signals.periph.ethernet.eth_txd_1_o = eth_txd_o_s[1];
  // assign soc2pad_port_signals.periph.ethernet.eth_txd_2_o = eth_txd_o_s[2];
  // assign soc2pad_port_signals.periph.ethernet.eth_txd_3_o = eth_txd_o_s[3];

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
  logic[carfield_pkg::NumFll-1:0] clk_fll_out;
  logic[carfield_pkg::NumFll-1:0] clk_fll_e;
  logic[carfield_pkg::NumFll-1:0] fll_lock;
  logic[carfield_pkg::NumFll-1:0] fll_pwd;
  logic[carfield_pkg::NumFll-1:0] fll_ret;
  logic[carfield_pkg::NumFll-1:0] fll_test_mode;
  logic[carfield_pkg::NumFll-1:0] fll_scan_e;
  logic[carfield_pkg::NumFll-1:0] fll_scan_in;
  logic[carfield_pkg::NumFll-1:0] fll_scan_out;
  logic[carfield_pkg::NumFll-1:0] fll_scan_jtag_in;
  logic[carfield_pkg::NumFll-1:0] fll_scan_jtag_out;
  logic[carfield_pkg::NumFll-1:0] domain_clk;

  // ref_clk
  assign ref_clk      = st_pad2soc_signals.botl.ref_clk_i;
  // power on reset
  assign pwr_on_rst_n = st_pad2soc_signals.botl.pwr_on_rst_ni;

  assign clk_fll_e   = '{default: 1'b1};

  clk_int_div_static #(
    .DIV_VALUE            ( 100  ),
    .ENABLE_CLOCK_IN_RESET( 1'b1 )
  ) i_rt_clk_div (
    .clk_i          ( clk_fll_out[carfield_pkg::RtClockIdx]),
    .rst_ni         ( pwr_on_rst_n                         ),
    .en_i           ( 1'b1                                 ),
    .test_mode_en_i ( 1'b0                                 ),
    .clk_o          ( domain_clk[carfield_pkg::RtClockIdx] )
  );

  for (genvar i = 1; i < carfield_pkg::NumFll; i++)
    assign domain_clk[i] = clk_fll_out[i];

  assign fll_pwd          = '{default: 1'b0};
  assign fll_ret          = '{default: 1'b0};
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

`ifdef GF22_FLL
  fll_wrap #(
    .NUM_FLL        ( carfield_pkg::NumFll ),
    // Addresses are double-word aligned (0x2002_0000, 0x2002_0008, ...)
    .FLL_REG_OFFSET ( 3                    ),
    .reg_req_t      ( carfield_reg_req_t   ),
    .reg_rsp_t      ( carfield_reg_rsp_t   )
  ) i_fll_wrap (
    .clk_ref_i           ( ref_clk                                ),
    .rst_n_i             ( ref_clk_pwr_on_rst_n                   ),
    .clk_bypass_i        ( st_pad2soc_signals.botl.ref_clk_i      ),
    .bypass_i            ( st_pad2soc_signals.botl.fll_bypass_i   ),
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
    .fll_ret_i           ( fll_ret                                ),
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

  // soc2pad
  // clocks
  //assign st_soc2pad_signals.botl.fll_rt_clk_o     = clk_fll_out[carfield_pkg::RtClockIdx];
  assign st_soc2pad_signals.botl.fll_host_clk_o   = clk_fll_out[carfield_pkg::HostClockIdx];
  //assign st_soc2pad_signals.botl.fll_alt_clk_o    = clk_fll_out[carfield_pkg::CarfieldClockIdx.AltClockIdx];
  //assign st_soc2pad_signals.botl.fll_periph_clk_o = clk_fll_out[carfield_pkg::CarfieldClockIdx.PeriphClockIdx];
  assign st_soc2pad_signals.botl.fll_secd_clk_o   = clk_fll_out[carfield_pkg::CarfieldClockIdx.SecureClockIdx];

  //////////////////
  // Carfield SoC //
  //////////////////
  wire pad_config_tc_pad_internal_signals_0;
  wire pad_config_tc_pad_internal_signals_1;
  wire pad_config_tc_pad_internal_signals_2;
  wire pad_config_tc_pad_internal_signals_3;

  carfield      #(
    .Cfg         ( Cfg ),
    .reg_req_t   ( carfield_reg_req_t ),
    .reg_rsp_t   ( carfield_reg_rsp_t )
  ) i_dut (
    .domain_clk_i               ( domain_clk[carfield_pkg::NumFll-1:0]              ),
    .pwr_on_rst_ni              ( pwr_on_rst_n                                      ),
    .test_mode_i                ( '0                                                ),
    .boot_mode_i                ( bootmode_host_s[1:0]                              ),
    .fll_lock_i                 ( fll_lock                                          ),
    .jtag_tck_i                 ( st_pad2soc_signals.botl.jtag_tclk_i               ),
    .jtag_trst_ni               ( st_pad2soc_signals.botl.jtag_trst_ni              ),
    .jtag_tms_i                 ( st_pad2soc_signals.botl.jtag_tms_i                ),
    .jtag_tdi_i                 ( st_pad2soc_signals.botl.jtag_tdi_i                ),
    .jtag_tdo_o                 ( st_soc2pad_signals.botl.jtag_tdo_o                ),
    .jtag_tdo_oe_o              (                                                   ),
    .jtag_ot_tck_i              ( st_pad2soc_signals.botl.jtag_ot_tclk_i            ),
    .jtag_ot_trst_ni            ( st_pad2soc_signals.botl.jtag_ot_trst_ni           ),
    .jtag_ot_tms_i              ( st_pad2soc_signals.botl.jtag_ot_tms_i             ),
    .jtag_ot_tdi_i              ( st_pad2soc_signals.botl.jtag_ot_tdi_i             ),
    .jtag_ot_tdo_o              ( st_soc2pad_signals.botl.jtag_ot_tdo_o             ),
    .jtag_ot_tdo_oe_o           (                                                   ),
    .bootmode_ot_i              ( bootmode_sec_isln_s                               ),
    .jtag_safety_island_tck_i   ( '0                                                ),
    .jtag_safety_island_trst_ni ( '0                                                ),
    .jtag_safety_island_tms_i   ( '0                                                ),
    .jtag_safety_island_tdi_i   ( '0                                                ),
    .jtag_safety_island_tdo_o   (                                                   ),
    .bootmode_safe_isln_i       ( bootmode_safe_isln_s                              ),
    .secure_boot_i              ( secure_boot                                       ),
    .uart_tx_o                  ( st_soc2pad_signals.botl.uart_tx_o                 ),
    .uart_rx_i                  ( st_pad2soc_signals.botl.uart_rx_i                 ),
    .uart_ot_tx_o               ( st_soc2pad_signals.botl.ot_uart_tx_o              ),
    .uart_ot_rx_i               ( st_pad2soc_signals.botl.ot_uart_rx_i              ),
    .i2c_sda_o                  (                                                   ),
    .i2c_sda_i                  ( '0                                                ),
    .i2c_sda_en_o               (                                                   ),
    .i2c_scl_o                  (                                                   ),
    .i2c_scl_i                  ( '0                                                ),
    .i2c_scl_en_o               (                                                   ),
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
    .eth_rxck_i                 ( '0                                                ),
    .eth_rxctl_i                ( '0                                                ),
    .eth_rxd_i                  ( eth_rxd_i_s                                       ),
    .eth_md_i                   ( '0                                                ),
    .eth_txck_o                 (                                                   ),
    .eth_txctl_o                (                                                   ),
    .eth_txd_o                  ( eth_txd_o_s                                       ),
    .eth_md_o                   (                                                   ),
    .eth_md_oe                  (                                                   ),
    .eth_mdc_o                  (                                                   ),
    .eth_rst_n_o                (                                                   ),
    // can bus
    .can_rx_i                   ( '0                                                ),
    .can_tx_o                   (                                                   ),
    // gpios
    .gpio_i                     ( gpio_in_s                                         ),
    .gpio_o                     ( gpio_out_s                                        ),
    .gpio_en_o                  ( gpio_tx_en_s                                      ),
    // serial link
    .slink_rcv_clk_i            ( '0                                                ),
    .slink_rcv_clk_o            (                                                   ),
    .slink_i                    ( serial_link_data_in_s                             ),
    .slink_o                    ( serial_link_data_out_s                            ),
    // hyperbus
    .pad_config_tc_pad_internal_signals_0(pad_config_tc_pad_internal_signals_0),
    .pad_config_tc_pad_internal_signals_1(pad_config_tc_pad_internal_signals_1),
    .pad_config_tc_pad_internal_signals_2(pad_config_tc_pad_internal_signals_2),
    .pad_config_tc_pad_internal_signals_3(pad_config_tc_pad_internal_signals_3),

    .pad_hyper_phy0_cs_n_0_pad(pad_botl_hyper_0_cs_0_n_pad),
    .pad_hyper_phy0_cs_n_1_pad(pad_botl_hyper_0_cs_1_n_pad),
    .pad_hyper_phy0_ck_pad     (pad_botl_hyper_0_ck_pad),
    .pad_hyper_phy0_ck_n_pad   (pad_botl_hyper_0_ck_n_pad),
    .pad_hyper_phy0_rwds_pad   (pad_botl_hyper_0_rwds_pad),
    .pad_hyper_phy0_dq_b0_pad  (pad_botl_hyper_0_dq_0_pad),
    .pad_hyper_phy0_dq_b1_pad  (pad_botl_hyper_0_dq_1_pad),
    .pad_hyper_phy0_dq_b2_pad  (pad_botl_hyper_0_dq_2_pad),
    .pad_hyper_phy0_dq_b3_pad  (pad_botl_hyper_0_dq_3_pad),
    .pad_hyper_phy0_dq_b4_pad  (pad_botl_hyper_0_dq_4_pad),
    .pad_hyper_phy0_dq_b5_pad  (pad_botl_hyper_0_dq_5_pad),
    .pad_hyper_phy0_dq_b6_pad  (pad_botl_hyper_0_dq_6_pad),
    .pad_hyper_phy0_dq_b7_pad  (pad_botl_hyper_0_dq_7_pad),
    .pad_hyper_phy0_reset_n_pad(pad_botl_hyper_0_reset_n_pad),

    .pad_hyper_phy1_cs_n_0_pad(pad_botl_hyper_1_cs_0_n_pad),
    .pad_hyper_phy1_cs_n_1_pad(pad_botl_hyper_1_cs_1_n_pad),
    .pad_hyper_phy1_ck_pad     (pad_botl_hyper_1_ck_pad),
    .pad_hyper_phy1_ck_n_pad   (pad_botl_hyper_1_ck_n_pad),
    .pad_hyper_phy1_rwds_pad   (pad_botl_hyper_1_rwds_pad),
    .pad_hyper_phy1_dq_b0_pad  (pad_botl_hyper_1_dq_0_pad),
    .pad_hyper_phy1_dq_b1_pad  (pad_botl_hyper_1_dq_1_pad),
    .pad_hyper_phy1_dq_b2_pad  (pad_botl_hyper_1_dq_2_pad),
    .pad_hyper_phy1_dq_b3_pad  (pad_botl_hyper_1_dq_3_pad),
    .pad_hyper_phy1_dq_b4_pad  (pad_botl_hyper_1_dq_4_pad),
    .pad_hyper_phy1_dq_b5_pad  (pad_botl_hyper_1_dq_5_pad),
    .pad_hyper_phy1_dq_b6_pad  (pad_botl_hyper_1_dq_6_pad),
    .pad_hyper_phy1_dq_b7_pad  (pad_botl_hyper_1_dq_7_pad),
    .pad_hyper_phy1_reset_n_pad(pad_botl_hyper_1_reset_n_pad),

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

  //TODO: TO ASK is ref_clk the correct clock for pads?

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
    //.port_signals_pad2soc ( pad2soc_port_signals ),
    //.port_signals_soc2pad ( soc2pad_port_signals ),
    // Landing Pads
    .pad_botl_config_tc_pad_internal_signals_0 (pad_config_tc_pad_internal_signals_0),
    .pad_botl_config_tc_pad_internal_signals_1 (pad_config_tc_pad_internal_signals_1),
    .pad_botl_config_tc_pad_internal_signals_2 (pad_config_tc_pad_internal_signals_2),
    .pad_botl_config_tc_pad_internal_signals_3 (pad_config_tc_pad_internal_signals_3),
    .pad_botl_ot_boot_mode_pad    (pad_botl_ot_boot_mode_pad),
    .pad_botl_jtag_ot_tclk_pad    (pad_botl_jtag_ot_tclk_pad),
    .pad_botl_jtag_ot_trst_n_pad  (pad_botl_jtag_ot_trst_n_pad),
    .pad_botl_jtag_ot_tms_pad     (pad_botl_jtag_ot_tms_pad),
    .pad_botl_jtag_ot_tdi_pad     (pad_botl_jtag_ot_tdi_pad),
    .pad_botl_jtag_ot_tdo_pad     (pad_botl_jtag_ot_tdo_pad),
    .pad_botl_ot_uart_tx_pad      (pad_botl_ot_uart_tx_pad),
    .pad_botl_ot_uart_rx_pad      (pad_botl_ot_uart_rx_pad),
    .pad_botl_spih_sck_pad        (pad_botl_spih_sck_pad),
    .pad_botl_spih_csb_pad        (pad_botl_spih_csb_pad),
    .pad_botl_spih_sd_0_pad       (pad_botl_spih_sd_0_pad),
    .pad_botl_spih_sd_1_pad       (pad_botl_spih_sd_1_pad),
    .pad_botl_spih_sd_2_pad       (pad_botl_spih_sd_2_pad),
    .pad_botl_spih_sd_3_pad       (pad_botl_spih_sd_3_pad),
    .pad_botl_gpio_2_pad          (pad_botl_gpio_2_pad),
    .pad_botl_gpio_3_pad          (pad_botl_gpio_3_pad),
    .pad_botl_spih_ot_sd_1_pad    (pad_botl_spih_ot_sd_1_pad),
    .pad_botl_spih_ot_sd_2_pad    (pad_botl_spih_ot_sd_2_pad),
    .pad_botl_spih_ot_sd_3_pad    (pad_botl_spih_ot_sd_3_pad),
    .pad_botl_ref_clk_pad         (pad_botl_ref_clk_pad),
    .pad_botl_fll_host_pad        (pad_botl_fll_host_pad),
    .pad_botl_fll_secd_pad        (pad_botl_fll_secd_pad),
    .pad_botl_fll_bypass_pad      (pad_botl_fll_bypass_pad),
    .pad_botl_pwr_on_rst_n_pad    (pad_botl_pwr_on_rst_n_pad),
    .pad_botl_boot_mode_0_pad     (pad_botl_boot_mode_0_pad),
    .pad_botl_boot_mode_1_pad     (pad_botl_boot_mode_1_pad),
    .pad_botl_secure_boot_pad     (pad_botl_secure_boot_pad),
    .pad_botl_jtag_tclk_pad       (pad_botl_jtag_tclk_pad),
    .pad_botl_jtag_trst_n_pad     (pad_botl_jtag_trst_n_pad),
    .pad_botl_jtag_tms_pad        (pad_botl_jtag_tms_pad),
    .pad_botl_jtag_tdi_pad        (pad_botl_jtag_tdi_pad),
    .pad_botl_jtag_tdo_pad        (pad_botl_jtag_tdo_pad),
    .pad_botl_uart_tx_pad         (pad_botl_uart_tx_pad),
    .pad_botl_uart_rx_pad         (pad_botl_uart_rx_pad),
    .pad_botl_gpio_0_pad          (pad_botl_gpio_0_pad),
    .pad_botl_gpio_1_pad          (pad_botl_gpio_1_pad),
    .pad_botl_spih_ot_sck_pad     (pad_botl_spih_ot_sck_pad),
    .pad_botl_spih_ot_csb_pad     (pad_botl_spih_ot_csb_pad),
    .pad_botl_spih_ot_sd_0_pad    (pad_botl_spih_ot_sd_0_pad),
    .pad_botl_hyper_1_cs_0_n_pad  (),
    .pad_botl_hyper_1_cs_1_n_pad  (),
    .pad_botl_hyper_1_ck_pad      (),
    .pad_botl_hyper_1_ck_n_pad    (),
    .pad_botl_hyper_1_rwds_pad    (),
    .pad_botl_hyper_1_reset_n_pad (),
    .pad_botl_hyper_1_dq_0_pad    (),
    .pad_botl_hyper_1_dq_1_pad    (),
    .pad_botl_hyper_1_dq_2_pad    (),
    .pad_botl_hyper_1_dq_3_pad    (),
    .pad_botl_hyper_1_dq_4_pad    (),
    .pad_botl_hyper_1_dq_5_pad    (),
    .pad_botl_hyper_1_dq_6_pad    (),
    .pad_botl_hyper_1_dq_7_pad    (),
    .pad_botl_hyper_0_cs_0_n_pad  (),
    .pad_botl_hyper_0_cs_1_n_pad  (),
    .pad_botl_hyper_0_ck_pad      (),
    .pad_botl_hyper_0_ck_n_pad    (),
    .pad_botl_hyper_0_rwds_pad    (),
    .pad_botl_hyper_0_reset_n_pad (),
    .pad_botl_hyper_0_dq_0_pad    (),
    .pad_botl_hyper_0_dq_1_pad    (),
    .pad_botl_hyper_0_dq_2_pad    (),
    .pad_botl_hyper_0_dq_3_pad    (),
    .pad_botl_hyper_0_dq_4_pad    (),
    .pad_botl_hyper_0_dq_5_pad    (),
    .pad_botl_hyper_0_dq_6_pad    (),
    .pad_botl_hyper_0_dq_7_pad    (),
  // Config Interface
    .config_req_i ( padframe_refclk_cfg_reg_req ),
    .config_rsp_o ( padframe_refclk_cfg_reg_rsp )
  );

endmodule: astral_wrap
