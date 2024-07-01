# VDD, and GND are directly wired on VCU118
# set_property PACKAGE_PIN P29     [get_ports jtag_trst_ni] ;# P29 (PMOD1_4_LS) - J53.2 - GND
# set_property IOSTANDARD LVCMOS12 [get_ports jtag_trst_ni] ;

set_property PACKAGE_PIN N30     [get_ports jtag_tdo_o] ;# N30 (PMOD1_2_LS) - J53.5 - TDO
set_property IOSTANDARD LVCMOS12 [get_ports jtag_tdo_o]

set_property PACKAGE_PIN P30     [get_ports jtag_tck_i] ;# P30 (PMOD1_3_LS) - J53.7 - TCK
set_property IOSTANDARD LVCMOS12 [get_ports jtag_tck_i] ;

set_property PACKAGE_PIN N28     [get_ports jtag_tms_i] ;# N28 (PMOD1_0_LS) - J53.1 - TMS
set_property IOSTANDARD LVCMOS12 [get_ports jtag_tms_i] ;

set_property PACKAGE_PIN M30     [get_ports jtag_tdi_i] ;# M30 (PMOD1_1_LS) - J53.3 - TDI
set_property IOSTANDARD LVCMOS12 [get_ports jtag_tdi_i]

#############################
# Classic connection to J52 #
#############################
# set_property PACKAGE_PIN AV16    [get_ports jtag_trst_ni] ;# AV16 (PMOD0_4_LS) - J52.2 - GND
# set_property IOSTANDARD LVCMOS18 [get_ports jtag_trst_ni] ;

# set_property PACKAGE_PIN AW15    [get_ports jtag_tdo_o] ;# AW15 (PMOD0_2_LS) - J52.5 - TDO
# set_property IOSTANDARD LVCMOS18 [get_ports jtag_tdo_o]

# set_property PACKAGE_PIN AV15    [get_ports jtag_tck_i] ;# AV15 (PMOD0_3_LS) - J52.7 - TCK
# set_property IOSTANDARD LVCMOS18 [get_ports jtag_tck_i] ;

# set_property PACKAGE_PIN AY14    [get_ports jtag_tms_i] ;# AY14 (PMOD0_0_LS) - J52.1 - TMS
# set_property IOSTANDARD LVCMOS18 [get_ports jtag_tms_i] ;

# set_property PACKAGE_PIN AY15    [get_ports jtag_tdi_i] ;# AY15 (PMOD0_1_LS) - J52.3 - TDI
# set_property IOSTANDARD LVCMOS18 [get_ports jtag_tdi_i] ;
