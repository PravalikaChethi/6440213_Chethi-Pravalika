# TCL Synthesis Script for FPGA Edge Detection System
# Compatible with Xilinx Vivado and Intel Quartus (modify as needed)

# Project configuration
set project_name "edge_detection_fpga"
set top_module "edge_detection_top"
set target_part "xc7a35tcpg236-1"  # Adjust for your target FPGA

# Source file list
set source_files {
    "edge_detection_top.v"
    "control_unit.v"
    "image_buffer.v"
    "gaussian_filter.v"
    "sobel_operator.v"
    "gradient_magnitude.v"
    "nonmax_suppression.v"
    "hysteresis_threshold.v"
}

# Constraint files (create if needed)
set constraint_files {
    "constraints.xdc"  # Create timing and pin constraints
}

# For Xilinx Vivado
proc run_vivado_synthesis {} {
    global project_name top_module target_part source_files constraint_files
    
    # Create project
    create_project $project_name ./$project_name -part $target_part -force
    
    # Add source files
    foreach file $source_files {
        if {[file exists $file]} {
            add_files $file
        } else {
            puts "Warning: Source file $file not found"
        }
    }
    
    # Add constraints (if they exist)
    foreach file $constraint_files {
        if {[file exists $file]} {
            add_files -fileset constrs_1 $file
        }
    }
    
    # Set top module
    set_property top $top_module [current_fileset]
    
    # Synthesis settings
    set_property strategy "Vivado Synthesis Defaults" [get_runs synth_1]
    set_property steps.synth_design.args.flatten_hierarchy "rebuilt" [get_runs synth_1]
    
    # Run synthesis
    launch_runs synth_1 -jobs 4
    wait_on_run synth_1
    
    # Report synthesis results
    open_run synth_1 -name synth_1
    report_utilization -file utilization_synth.rpt
    report_timing_summary -file timing_synth.rpt
    
    # Implementation settings
    set_property strategy "Vivado Implementation Defaults" [get_runs impl_1]
    
    # Run implementation
    launch_runs impl_1 -jobs 4
    wait_on_run impl_1
    
    # Report implementation results
    open_run impl_1
    report_utilization -file utilization_impl.rpt
    report_timing_summary -file timing_impl.rpt
    report_power -file power.rpt
    
    # Generate bitstream
    launch_runs impl_1 -to_step write_bitstream -jobs 4
    wait_on_run impl_1
    
    puts "Synthesis and implementation completed successfully!"
    puts "Check reports in: utilization_*.rpt, timing_*.rpt, power.rpt"
}

# For Intel Quartus (basic example)
proc run_quartus_synthesis {} {
    global project_name top_module source_files
    
    # Create Quartus project file (.qpf)
    set qpf_content "# Quartus Project File\nDATE = \"[clock format [clock seconds]]\"\nREVISION = \"$project_name\"\nPROJECT = \"$project_name\""
    set qpf_file [open "$project_name.qpf" w]
    puts $qpf_file $qpf_content
    close $qpf_file
    
    # Create Quartus settings file (.qsf)
    set qsf_file [open "$project_name.qsf" w]
    puts $qsf_file "set_global_assignment -name FAMILY \"Cyclone V\""
    puts $qsf_file "set_global_assignment -name DEVICE 5CSEMA5F31C6"
    puts $qsf_file "set_global_assignment -name TOP_LEVEL_ENTITY $top_module"
    
    foreach file $source_files {
        if {[file exists $file]} {
            puts $qsf_file "set_global_assignment -name VERILOG_FILE $file"
        }
    }
    
    puts $qsf_file "set_global_assignment -name PARTITION_NETLIST_TYPE SOURCE -section_id Top"
    puts $qsf_file "set_global_assignment -name PARTITION_FITTER_PRESERVATION_LEVEL PLACEMENT_AND_ROUTING -section_id Top"
    puts $qsf_file "set_global_assignment -name PARTITION_COLOR 16764057 -section_id Top"
    puts $qsf_file "set_instance_assignment -name PARTITION_HIERARCHY root_partition -to | -section_id Top"
    close $qsf_file
    
    puts "Quartus project files created: $project_name.qpf, $project_name.qsf"
    puts "Run synthesis with: quartus_sh --flow compile $project_name"
}

# Timing constraints template
proc create_timing_constraints {} {
    set xdc_file [open "constraints.xdc" w]
    
    puts $xdc_file "# Clock constraints"
    puts $xdc_file "create_clock -period 10.000 -name sys_clk \[get_ports clk\]"
    puts $xdc_file "set_input_delay -clock sys_clk -max 2.000 \[get_ports {pixel_in\[\*\] pixel_valid start}\]"
    puts $xdc_file "set_output_delay -clock sys_clk -max 2.000 \[get_ports {edge_out\[\*\] edge_valid ready processing_done}\]"
    puts $xdc_file ""
    puts $xdc_file "# Reset constraints"
    puts $xdc_file "set_false_path -from \[get_ports rst_n\]"
    puts $xdc_file ""
    puts $xdc_file "# Memory interface constraints"
    puts $xdc_file "set_output_delay -clock sys_clk -max 3.000 \[get_ports {mem_addr\[\*\] mem_data_out\[\*\] mem_we mem_oe}\]"
    puts $xdc_file "set_input_delay -clock sys_clk -max 3.000 \[get_ports {mem_data_in\[\*\]}\]"
    puts $xdc_file ""
    puts $xdc_file "# Additional timing constraints"
    puts $xdc_file "set_max_delay -from \[get_pins {*gaussian_filter*/line_buffer*}\] -to \[get_pins {*sobel_operator*/window*}\] 5.000"
    
    close $xdc_file
    puts "Timing constraints created: constraints.xdc"
}

# Resource utilization estimation
proc estimate_resources {} {
    puts "Estimated Resource Utilization:"
    puts "================================"
    puts "LUTs (approximate):"
    puts "  - Gaussian Filter:      ~500 LUTs"
    puts "  - Sobel Operator:       ~800 LUTs"  
    puts "  - Gradient Magnitude:   ~400 LUTs"
    puts "  - Non-max Suppression: ~600 LUTs"
    puts "  - Hysteresis Threshold: ~300 LUTs"
    puts "  - Control Logic:        ~200 LUTs"
    puts "  - Total:               ~2800 LUTs"
    puts ""
    puts "Memory (BRAM):"
    puts "  - Line Buffers:         ~6-12 BRAMs (depending on image width)"
    puts "  - Image Buffer:         External RAM or additional BRAMs"
    puts ""
    puts "DSP Slices:"
    puts "  - Multipliers:          ~8-12 DSP48 slices"
    puts ""
    puts "Note: Actual utilization depends on synthesis optimizations and target device"
}

# Performance analysis
proc analyze_performance {} {
    puts "Performance Analysis:"
    puts "===================="
    puts "Target Clock Frequency: 100 MHz (10ns period)"
    puts "Expected Throughput: ~1 pixel/cycle (after pipeline fill)"
    puts "Pipeline Latency: ~40-50 clock cycles"
    puts "For 640x480 image @ 100MHz:"
    puts "  - Processing time: ~3.07ms per frame"
    puts "  - Maximum frame rate: ~325 FPS"
    puts ""
    puts "Critical Path Components:"
    puts "  - Gaussian convolution multiplication"
    puts "  - Sobel gradient calculation"
    puts "  - Magnitude computation"
    puts "  - Memory access timing"
}

# Main execution
if {[llength $argv] == 0} {
    puts "FPGA Edge Detection Synthesis Script"
    puts "===================================="
    puts "Usage: vivado -mode tcl -source synthesis_script.tcl -tclargs <command>"
    puts ""
    puts "Commands:"
    puts "  vivado     - Run Vivado synthesis flow"
    puts "  quartus    - Create Quartus project files"  
    puts "  constraints- Create timing constraints file"
    puts "  estimate   - Show resource estimation"
    puts "  analyze    - Show performance analysis"
    puts ""
    puts "Example: vivado -mode tcl -source synthesis_script.tcl -tclargs vivado"
} else {
    set command [lindex $argv 0]
    
    switch $command {
        "vivado" {
            run_vivado_synthesis
        }
        "quartus" {
            run_quartus_synthesis
        }
        "constraints" {
            create_timing_constraints
        }
        "estimate" {
            estimate_resources
        }
        "analyze" {
            analyze_performance
        }
        default {
            puts "Error: Unknown command '$command'"
            puts "Valid commands: vivado, quartus, constraints, estimate, analyze"
        }
    }
}