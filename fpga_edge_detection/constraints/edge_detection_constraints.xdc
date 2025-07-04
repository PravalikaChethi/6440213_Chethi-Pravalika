# Timing Constraints for FPGA Edge Detection System
# Target: Xilinx 7-series FPGAs (Artix-7, Kintex-7, Virtex-7)

# Primary clock constraint - 100 MHz system clock
create_clock -period 10.000 -name sys_clk [get_ports clk]

# Clock domain crossing constraints
set_clock_groups -asynchronous -group [get_clocks sys_clk]

# Input/Output Delay Constraints
# Assuming 2ns setup and 1ns hold times for external interfaces
set_input_delay -clock sys_clk -max 2.000 [get_ports {pixel_in[*]}]
set_input_delay -clock sys_clk -min 1.000 [get_ports {pixel_in[*]}]
set_input_delay -clock sys_clk -max 2.000 [get_ports pixel_valid_in]
set_input_delay -clock sys_clk -min 1.000 [get_ports pixel_valid_in]
set_input_delay -clock sys_clk -max 2.000 [get_ports edge_ready_in]
set_input_delay -clock sys_clk -min 1.000 [get_ports edge_ready_in]

set_output_delay -clock sys_clk -max 2.000 [get_ports {edge_out[*]}]
set_output_delay -clock sys_clk -min 1.000 [get_ports {edge_out[*]}]
set_output_delay -clock sys_clk -max 2.000 [get_ports edge_valid_out]
set_output_delay -clock sys_clk -min 1.000 [get_ports edge_valid_out]
set_output_delay -clock sys_clk -max 2.000 [get_ports pixel_ready_out]
set_output_delay -clock sys_clk -min 1.000 [get_ports pixel_ready_out]

# Configuration input delays
set_input_delay -clock sys_clk -max 2.000 [get_ports {sobel_threshold[*]}]
set_input_delay -clock sys_clk -min 1.000 [get_ports {sobel_threshold[*]}]
set_input_delay -clock sys_clk -max 2.000 [get_ports {canny_low_th[*]}]
set_input_delay -clock sys_clk -min 1.000 [get_ports {canny_low_th[*]}]
set_input_delay -clock sys_clk -max 2.000 [get_ports {canny_high_th[*]}]
set_input_delay -clock sys_clk -min 1.000 [get_ports {canny_high_th[*]}]
set_input_delay -clock sys_clk -max 2.000 [get_ports {hybrid_mode[*]}]
set_input_delay -clock sys_clk -min 1.000 [get_ports {hybrid_mode[*]}]

# Reset and control signals
set_input_delay -clock sys_clk -max 2.000 [get_ports reset]
set_input_delay -clock sys_clk -min 1.000 [get_ports reset]
set_input_delay -clock sys_clk -max 2.000 [get_ports enable]
set_input_delay -clock sys_clk -min 1.000 [get_ports enable]

# Status output delays
set_output_delay -clock sys_clk -max 2.000 [get_ports processing_done]
set_output_delay -clock sys_clk -min 1.000 [get_ports processing_done]
set_output_delay -clock sys_clk -max 2.000 [get_ports {frame_count[*]}]
set_output_delay -clock sys_clk -min 1.000 [get_ports {frame_count[*]}]

# False path constraints for asynchronous reset
set_false_path -from [get_ports reset] -to [all_registers]

# Multicycle path constraints for line buffers
# Line buffer writes can take 2 cycles
set_multicycle_path -setup 2 -from [get_cells -hier -filter {NAME =~ *line_buffer*}] -to [get_cells -hier -filter {NAME =~ *line_buffer*}]
set_multicycle_path -hold 1 -from [get_cells -hier -filter {NAME =~ *line_buffer*}] -to [get_cells -hier -filter {NAME =~ *line_buffer*}]

# Pipeline constraints
# Allow 2 cycles for Sobel gradient calculations
set_multicycle_path -setup 3 -from [get_cells -hier -filter {NAME =~ *sobel_calc*}] -to [get_cells -hier -filter {NAME =~ *mag_calc*}]
set_multicycle_path -hold 2 -from [get_cells -hier -filter {NAME =~ *sobel_calc*}] -to [get_cells -hier -filter {NAME =~ *mag_calc*}]

# Memory placement constraints
# Place line buffers in Block RAM for optimal performance
set_property RAMB_MAX_PERCENTAGE 80 [current_design]

# Critical path optimization
# Prioritize timing on the main processing pipeline
set_max_delay 8.000 -from [get_cells -hier -filter {NAME =~ *sobel_inst*}] -to [get_cells -hier -filter {NAME =~ *canny_inst*}]

# Power optimization
# Enable clock gating for unused modules
set_property CLOCK_GATING_ENABLE true [current_design]

# Placement constraints for optimal routing
# Keep related components close together
create_pblock pblock_sobel
add_cells_to_pblock pblock_sobel [get_cells -hier -filter {NAME =~ *sobel_inst*}]
resize_pblock pblock_sobel -add {SLICE_X0Y0:SLICE_X30Y50}

create_pblock pblock_canny
add_cells_to_pblock pblock_canny [get_cells -hier -filter {NAME =~ *canny_inst*}]
resize_pblock pblock_canny -add {SLICE_X31Y0:SLICE_X60Y50}

create_pblock pblock_line_buffers
add_cells_to_pblock pblock_line_buffers [get_cells -hier -filter {NAME =~ *line_buf_inst*}]
resize_pblock pblock_line_buffers -add {RAMB36_X0Y0:RAMB36_X2Y5}

# IO Standard constraints (assuming LVCMOS25 for general purpose IO)
set_property IOSTANDARD LVCMOS25 [get_ports clk]
set_property IOSTANDARD LVCMOS25 [get_ports reset]
set_property IOSTANDARD LVCMOS25 [get_ports enable]
set_property IOSTANDARD LVCMOS25 [get_ports {pixel_in[*]}]
set_property IOSTANDARD LVCMOS25 [get_ports pixel_valid_in]
set_property IOSTANDARD LVCMOS25 [get_ports pixel_ready_out]
set_property IOSTANDARD LVCMOS25 [get_ports {edge_out[*]}]
set_property IOSTANDARD LVCMOS25 [get_ports edge_valid_out]
set_property IOSTANDARD LVCMOS25 [get_ports edge_ready_in]
set_property IOSTANDARD LVCMOS25 [get_ports {sobel_threshold[*]}]
set_property IOSTANDARD LVCMOS25 [get_ports {canny_low_th[*]}]
set_property IOSTANDARD LVCMOS25 [get_ports {canny_high_th[*]}]
set_property IOSTANDARD LVCMOS25 [get_ports {hybrid_mode[*]}]
set_property IOSTANDARD LVCMOS25 [get_ports processing_done]
set_property IOSTANDARD LVCMOS25 [get_ports {frame_count[*]}]

# Drive strength for outputs
set_property DRIVE 12 [get_ports {edge_out[*]}]
set_property DRIVE 12 [get_ports edge_valid_out]
set_property DRIVE 12 [get_ports pixel_ready_out]
set_property DRIVE 12 [get_ports processing_done]
set_property DRIVE 12 [get_ports {frame_count[*]}]

# Slew rate control for signal integrity
set_property SLEW FAST [get_ports {edge_out[*]}]
set_property SLEW FAST [get_ports edge_valid_out]

# Implementation strategy hints
set_property STRATEGY Performance_ExplorePostRoutePhysOpt [get_runs impl_1]

# Disable timing report on unconstrained paths
set_param general.maxThreads 8