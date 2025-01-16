# Copyright 2024 ETH Zurich and University of Bologna.
# Solderpad Hardware License, Version 0.51, see LICENSE for details.
# SPDX-License-Identifier: SHL-0.51

set partNumber $::env(XILINX_PART)
set boardName  $::env(XILINX_BOARD_LONG)

set ipName xilinx_rom_bank_1024x22

create_project $ipName . -force -part $partNumber
set_property board_part $boardName [current_project]

# Add coefficient_file
# import_files -fileset sources_1 otp.coe

create_ip -name dist_mem_gen -vendor xilinx.com -library ip -version 8.0 -module_name $ipName
set_property -dict [list CONFIG.depth {1024} \
                         CONFIG.data_width {22} \
                         CONFIG.memory_type {rom} \
                         CONFIG.input_options {registered} \
                         CONFIG.output_options {non_registered} \
                         CONFIG.single_port_output_clock_enable {false} \
                         CONFIG.default_data {00000000} \
                         CONFIG.coefficient_file {../../../../otp.coe} \
                    ] [get_ips  $ipName]

# exec cp otp.coe $ipName.srcs/sources_1/ip/otp.coe
# set_property -dict [list CONFIG.coefficient_file {../otp.coe}] [get_ips $ipName]

generate_target {instantiation_template} [get_files ./$ipName.srcs/sources_1/ip/$ipName/$ipName.xci]
generate_target all [get_files ./$ipName.srcs/sources_1/ip/$ipName/$ipName.xci]
create_ip_run [get_files -of_objects [get_fileset sources_1] ./$ipName.srcs/sources_1/ip/$ipName/$ipName.xci]
launch_run -jobs 8 ${ipName}_synth_1
wait_on_run ${ipName}_synth_1
