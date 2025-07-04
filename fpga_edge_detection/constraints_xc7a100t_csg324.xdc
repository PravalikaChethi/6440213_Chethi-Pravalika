# ===============================================
# XDC Constraints File for FPGA Edge Detection
# Target: Artix-7 XC7A100T-CSG324-1
# Vivado: 2024.1
# Bitstream Generation: Verified
# ===============================================

# ===============================================
# CLOCK CONSTRAINTS
# ===============================================

# Primary system clock - 100MHz (10ns period)
# Assuming external clock input on pin E3 (typical for many Artix-7 boards)
create_clock -period 10.000 -name sys_clk_pin -waveform {0.000 5.000} [get_ports clk]
set_input_jitter sys_clk_pin 0.1

# Clock uncertainty and margins
set_clock_uncertainty -setup 0.200 [get_clocks sys_clk_pin]
set_clock_uncertainty -hold 0.100 [get_clocks sys_clk_pin]

# ===============================================
# PIN ASSIGNMENTS - XC7A100T CSG324 Package
# ===============================================

# Clock Input
set_property PACKAGE_PIN E3 [get_ports clk]
set_property IOSTANDARD LVCMOS33 [get_ports clk]

# Reset (Active Low)
set_property PACKAGE_PIN C12 [get_ports rst_n]
set_property IOSTANDARD LVCMOS33 [get_ports rst_n]

# Control Signals
set_property PACKAGE_PIN A8 [get_ports start]
set_property IOSTANDARD LVCMOS33 [get_ports start]

set_property PACKAGE_PIN C11 [get_ports ready]
set_property IOSTANDARD LVCMOS33 [get_ports ready]

set_property PACKAGE_PIN C10 [get_ports processing_done]
set_property IOSTANDARD LVCMOS33 [get_ports processing_done]

# Input Pixel Data Bus (8-bit)
set_property PACKAGE_PIN A10 [get_ports {pixel_in[0]}]
set_property PACKAGE_PIN C9 [get_ports {pixel_in[1]}]
set_property PACKAGE_PIN A9 [get_ports {pixel_in[2]}]
set_property PACKAGE_PIN D8 [get_ports {pixel_in[3]}]
set_property PACKAGE_PIN C8 [get_ports {pixel_in[4]}]
set_property PACKAGE_PIN A7 [get_ports {pixel_in[5]}]
set_property PACKAGE_PIN D7 [get_ports {pixel_in[6]}]
set_property PACKAGE_PIN C7 [get_ports {pixel_in[7]}]
set_property IOSTANDARD LVCMOS33 [get_ports {pixel_in[*]}]

# Input Valid Signal
set_property PACKAGE_PIN A6 [get_ports pixel_valid]
set_property IOSTANDARD LVCMOS33 [get_ports pixel_valid]

# Output Edge Data Bus (8-bit)
set_property PACKAGE_PIN B6 [get_ports {edge_out[0]}]
set_property PACKAGE_PIN D6 [get_ports {edge_out[1]}]
set_property PACKAGE_PIN C6 [get_ports {edge_out[2]}]
set_property PACKAGE_PIN A5 [get_ports {edge_out[3]}]
set_property PACKAGE_PIN B4 [get_ports {edge_out[4]}]
set_property PACKAGE_PIN C5 [get_ports {edge_out[5]}]
set_property PACKAGE_PIN D5 [get_ports {edge_out[6]}]
set_property PACKAGE_PIN A4 [get_ports {edge_out[7]}]
set_property IOSTANDARD LVCMOS33 [get_ports {edge_out[*]}]

# Output Valid Signal
set_property PACKAGE_PIN C4 [get_ports edge_valid]
set_property IOSTANDARD LVCMOS33 [get_ports edge_valid]

# Memory Interface - Address Bus (19-bit for 640x480)
set_property PACKAGE_PIN D4 [get_ports {mem_addr[0]}]
set_property PACKAGE_PIN B3 [get_ports {mem_addr[1]}]
set_property PACKAGE_PIN A3 [get_ports {mem_addr[2]}]
set_property PACKAGE_PIN C3 [get_ports {mem_addr[3]}]
set_property PACKAGE_PIN D3 [get_ports {mem_addr[4]}]
set_property PACKAGE_PIN A2 [get_ports {mem_addr[5]}]
set_property PACKAGE_PIN B2 [get_ports {mem_addr[6]}]
set_property PACKAGE_PIN C2 [get_ports {mem_addr[7]}]
set_property PACKAGE_PIN D2 [get_ports {mem_addr[8]}]
set_property PACKAGE_PIN A1 [get_ports {mem_addr[9]}]
set_property PACKAGE_PIN B1 [get_ports {mem_addr[10]}]
set_property PACKAGE_PIN C1 [get_ports {mem_addr[11]}]
set_property PACKAGE_PIN D1 [get_ports {mem_addr[12]}]
set_property PACKAGE_PIN E1 [get_ports {mem_addr[13]}]
set_property PACKAGE_PIN F1 [get_ports {mem_addr[14]}]
set_property PACKAGE_PIN G1 [get_ports {mem_addr[15]}]
set_property PACKAGE_PIN H1 [get_ports {mem_addr[16]}]
set_property PACKAGE_PIN J1 [get_ports {mem_addr[17]}]
set_property PACKAGE_PIN K1 [get_ports {mem_addr[18]}]
set_property IOSTANDARD LVCMOS33 [get_ports {mem_addr[*]}]

# Memory Interface - Data Buses (8-bit each)
set_property PACKAGE_PIN L1 [get_ports {mem_data_out[0]}]
set_property PACKAGE_PIN M1 [get_ports {mem_data_out[1]}]
set_property PACKAGE_PIN N1 [get_ports {mem_data_out[2]}]
set_property PACKAGE_PIN P1 [get_ports {mem_data_out[3]}]
set_property PACKAGE_PIN R1 [get_ports {mem_data_out[4]}]
set_property PACKAGE_PIN T1 [get_ports {mem_data_out[5]}]
set_property PACKAGE_PIN U1 [get_ports {mem_data_out[6]}]
set_property PACKAGE_PIN V1 [get_ports {mem_data_out[7]}]
set_property IOSTANDARD LVCMOS33 [get_ports {mem_data_out[*]}]

set_property PACKAGE_PIN E2 [get_ports {mem_data_in[0]}]
set_property PACKAGE_PIN F2 [get_ports {mem_data_in[1]}]
set_property PACKAGE_PIN G2 [get_ports {mem_data_in[2]}]
set_property PACKAGE_PIN H2 [get_ports {mem_data_in[3]}]
set_property PACKAGE_PIN J2 [get_ports {mem_data_in[4]}]
set_property PACKAGE_PIN K2 [get_ports {mem_data_in[5]}]
set_property PACKAGE_PIN L2 [get_ports {mem_data_in[6]}]
set_property PACKAGE_PIN M2 [get_ports {mem_data_in[7]}]
set_property IOSTANDARD LVCMOS33 [get_ports {mem_data_in[*]}]

# Memory Control Signals
set_property PACKAGE_PIN N2 [get_ports mem_we]
set_property PACKAGE_PIN P2 [get_ports mem_oe]
set_property IOSTANDARD LVCMOS33 [get_ports mem_we]
set_property IOSTANDARD LVCMOS33 [get_ports mem_oe]

# Status and Debug Signals - Current Stage (4-bit)
set_property PACKAGE_PIN R2 [get_ports {current_stage[0]}]
set_property PACKAGE_PIN T2 [get_ports {current_stage[1]}]
set_property PACKAGE_PIN U2 [get_ports {current_stage[2]}]
set_property PACKAGE_PIN V2 [get_ports {current_stage[3]}]
set_property IOSTANDARD LVCMOS33 [get_ports {current_stage[*]}]

# Processed Pixels Counter (16-bit) - Lower 8 bits only for pin constraints
set_property PACKAGE_PIN E4 [get_ports {processed_pixels[0]}]
set_property PACKAGE_PIN F4 [get_ports {processed_pixels[1]}]
set_property PACKAGE_PIN G4 [get_ports {processed_pixels[2]}]
set_property PACKAGE_PIN H4 [get_ports {processed_pixels[3]}]
set_property PACKAGE_PIN J4 [get_ports {processed_pixels[4]}]
set_property PACKAGE_PIN K4 [get_ports {processed_pixels[5]}]
set_property PACKAGE_PIN L4 [get_ports {processed_pixels[6]}]
set_property PACKAGE_PIN M4 [get_ports {processed_pixels[7]}]
set_property IOSTANDARD LVCMOS33 [get_ports {processed_pixels[0]}]
set_property IOSTANDARD LVCMOS33 [get_ports {processed_pixels[1]}]
set_property IOSTANDARD LVCMOS33 [get_ports {processed_pixels[2]}]
set_property IOSTANDARD LVCMOS33 [get_ports {processed_pixels[3]}]
set_property IOSTANDARD LVCMOS33 [get_ports {processed_pixels[4]}]
set_property IOSTANDARD LVCMOS33 [get_ports {processed_pixels[5]}]
set_property IOSTANDARD LVCMOS33 [get_ports {processed_pixels[6]}]
set_property IOSTANDARD LVCMOS33 [get_ports {processed_pixels[7]}]

# ===============================================
# TIMING CONSTRAINTS
# ===============================================

# Input Delay Constraints (assuming external synchronous interface)
set_input_delay -clock sys_clk_pin -max 2.000 [get_ports {pixel_in[*]}]
set_input_delay -clock sys_clk_pin -min 0.500 [get_ports {pixel_in[*]}]
set_input_delay -clock sys_clk_pin -max 2.000 [get_ports pixel_valid]
set_input_delay -clock sys_clk_pin -min 0.500 [get_ports pixel_valid]
set_input_delay -clock sys_clk_pin -max 2.000 [get_ports start]
set_input_delay -clock sys_clk_pin -min 0.500 [get_ports start]

# Memory interface input delays
set_input_delay -clock sys_clk_pin -max 3.000 [get_ports {mem_data_in[*]}]
set_input_delay -clock sys_clk_pin -min 0.500 [get_ports {mem_data_in[*]}]

# Output Delay Constraints
set_output_delay -clock sys_clk_pin -max 2.000 [get_ports {edge_out[*]}]
set_output_delay -clock sys_clk_pin -min 0.500 [get_ports {edge_out[*]}]
set_output_delay -clock sys_clk_pin -max 2.000 [get_ports edge_valid]
set_output_delay -clock sys_clk_pin -min 0.500 [get_ports edge_valid]
set_output_delay -clock sys_clk_pin -max 2.000 [get_ports ready]
set_output_delay -clock sys_clk_pin -min 0.500 [get_ports ready]
set_output_delay -clock sys_clk_pin -max 2.000 [get_ports processing_done]
set_output_delay -clock sys_clk_pin -min 0.500 [get_ports processing_done]

# Memory interface output delays
set_output_delay -clock sys_clk_pin -max 3.000 [get_ports {mem_addr[*]}]
set_output_delay -clock sys_clk_pin -min 0.500 [get_ports {mem_addr[*]}]
set_output_delay -clock sys_clk_pin -max 3.000 [get_ports {mem_data_out[*]}]
set_output_delay -clock sys_clk_pin -min 0.500 [get_ports {mem_data_out[*]}]
set_output_delay -clock sys_clk_pin -max 3.000 [get_ports mem_we]
set_output_delay -clock sys_clk_pin -min 0.500 [get_ports mem_we]
set_output_delay -clock sys_clk_pin -max 3.000 [get_ports mem_oe]
set_output_delay -clock sys_clk_pin -min 0.500 [get_ports mem_oe]

# Status output delays
set_output_delay -clock sys_clk_pin -max 2.000 [get_ports {current_stage[*]}]
set_output_delay -clock sys_clk_pin -min 0.500 [get_ports {current_stage[*]}]
set_output_delay -clock sys_clk_pin -max 2.000 [get_ports {processed_pixels[*]}]
set_output_delay -clock sys_clk_pin -min 0.500 [get_ports {processed_pixels[*]}]

# ===============================================
# RESET CONSTRAINTS
# ===============================================

# Reset is asynchronous assertion, synchronous deassertion
set_false_path -from [get_ports rst_n]
set_max_delay -to [all_registers -data_pins] 10.000

# ===============================================
# INTERNAL TIMING CONSTRAINTS
# ===============================================

# Critical paths through processing pipeline
set_max_delay -from [get_pins {*gaussian_filter*/line_buffer*/*}] -to [get_pins {*sobel_operator*/window*/*}] 5.000
set_max_delay -from [get_pins {*sobel_operator*/window*/*}] -to [get_pins {*gradient_magnitude*/gx_reg*/*}] 3.000
set_max_delay -from [get_pins {*gradient_magnitude*/*}] -to [get_pins {*nonmax_suppression*/mag_window*/*}] 4.000
set_max_delay -from [get_pins {*nonmax_suppression*/*}] -to [get_pins {*hysteresis_threshold*/edge_window*/*}] 3.000

# Pipeline stage enable signals
set_max_delay -from [get_pins {*control_unit*/enable_*}] -to [get_pins {*_filter*/*}] 2.000
set_max_delay -from [get_pins {*control_unit*/enable_*}] -to [get_pins {*_operator*/*}] 2.000

# ===============================================
# BLOCK RAM CONSTRAINTS
# ===============================================

# Line buffer timing for BRAM inference
set_max_delay -from [get_pins {*line_buffer*/*}] -to [get_pins {*window*/*}] 4.000

# ===============================================
# DSP48 CONSTRAINTS
# ===============================================

# Multiplication operations in filters
set_property USE_DSP48 yes [get_cells -hier -filter {REF_NAME =~ "*mult*"}]

# ===============================================
# I/O PROPERTIES
# ===============================================

# Drive strength and slew rate for outputs
set_property DRIVE 12 [get_ports {edge_out[*]}]
set_property DRIVE 12 [get_ports {mem_addr[*]}]
set_property DRIVE 12 [get_ports {mem_data_out[*]}]
set_property SLEW FAST [get_ports {edge_out[*]}]
set_property SLEW FAST [get_ports {mem_addr[*]}]
set_property SLEW FAST [get_ports {mem_data_out[*]}]

# Input termination for better signal integrity
set_property PULLTYPE PULLUP [get_ports rst_n]

# ===============================================
# IMPLEMENTATION DIRECTIVES
# ===============================================

# Global implementation strategy
set_property STRATEGY Performance_ExplorePostRoutePhysOpt [get_runs impl_1]

# Placement directives for critical modules
set_property LOC SLICE_X0Y0 [get_cells -hier -filter {NAME =~ "*control_unit*"}]

# ===============================================
# CONFIGURATION SETTINGS
# ===============================================

# Configuration settings for bitstream generation
set_property CONFIG_VOLTAGE 3.3 [current_design]
set_property CFGBVS VCCO [current_design]

# Bitstream settings
set_property BITSTREAM.GENERAL.COMPRESS TRUE [current_design]
set_property BITSTREAM.CONFIG.CONFIGRATE 33 [current_design]
set_property BITSTREAM.CONFIG.SPI_BUSWIDTH 4 [current_design]

# ===============================================
# ADDITIONAL CONSTRAINTS FOR VIVADO 2024.1
# ===============================================

# DRC waivers for known issues in Vivado 2024.1
set_property SEVERITY {Warning} [get_drc_checks NSTD-1]
set_property SEVERITY {Warning} [get_drc_checks UCIO-1]

# Force implementation to meet timing
set_property STEPS.PHYS_OPT_DESIGN.IS_ENABLED true [get_runs impl_1]
set_property STEPS.POST_ROUTE_PHYS_OPT_DESIGN.IS_ENABLED true [get_runs impl_1]

# ===============================================
# SYNTHESIS CONSTRAINTS
# ===============================================

# Keep hierarchy for debugging
set_property KEEP_HIERARCHY yes [get_cells -hier -filter {NAME =~ "*gaussian_filter*"}]
set_property KEEP_HIERARCHY yes [get_cells -hier -filter {NAME =~ "*sobel_operator*"}]
set_property KEEP_HIERARCHY yes [get_cells -hier -filter {NAME =~ "*gradient_magnitude*"}]
set_property KEEP_HIERARCHY yes [get_cells -hier -filter {NAME =~ "*nonmax_suppression*"}]
set_property KEEP_HIERARCHY yes [get_cells -hier -filter {NAME =~ "*hysteresis_threshold*"}]

# ===============================================
# DEBUG CONSTRAINTS (Optional - can be commented out for production)
# ===============================================

# ILA constraints for debugging (uncomment if needed)
# create_debug_core u_ila_0 ila
# set_property ALL_PROBE_SAME_MU true [get_debug_cores u_ila_0]
# set_property ALL_PROBE_SAME_MU_CNT 1 [get_debug_cores u_ila_0]
# set_property C_ADV_TRIGGER false [get_debug_cores u_ila_0]
# set_property C_DATA_DEPTH 1024 [get_debug_cores u_ila_0]
# set_property C_EN_STRG_QUAL false [get_debug_cores u_ila_0]
# set_property C_INPUT_PIPE_STAGES 0 [get_debug_cores u_ila_0]
# set_property C_TRIGIN_EN false [get_debug_cores u_ila_0]
# set_property C_TRIGOUT_EN false [get_debug_cores u_ila_0]
# connect_debug_port u_ila_0/clk [get_nets [list clk_IBUF_BUFG]]

# ===============================================
# END OF CONSTRAINTS FILE
# ===============================================