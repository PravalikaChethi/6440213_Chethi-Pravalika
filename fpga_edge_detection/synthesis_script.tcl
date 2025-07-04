# TCL Synthesis Script for FPGA Edge Detection System
# Compatible with Xilinx Vivado and Intel Quartus (modify as needed)

# Project configuration
set project_name "edge_detection_fpga"
set top_module "edge_detection_top"
set target_part "xc7a35tcpg236-1"  # Adjust for your target FPGA

# Source file list
set source_files [list \
    "edge_detection_top.v" \
    "control_unit.v" \
    "image_buffer.v" \
    "gaussian_filter.v" \
    "sobel_operator.v" \
    "gradient_magnitude.v" \
    "nonmax_suppression.v" \
    "hysteresis_threshold.v" \
]

# Constraint files (create if needed)
set constraint_files [list \
    "constraints.xdc" \
]

# Error handling procedure
proc handle_error {msg} {
    puts "ERROR: $msg"
    return -code error $msg
}

# Check if file exists and is readable
proc check_file {filename} {
    if {![file exists $filename]} {
        handle_error "File not found: $filename"
    }
    if {![file readable $filename]} {
        handle_error "File not readable: $filename"
    }
    return true
}

# For Xilinx Vivado
proc run_vivado_synthesis {} {
    global project_name top_module target_part source_files constraint_files
    
    puts "Starting Vivado synthesis flow..."
    
    # Close any existing project
    if {[get_projects -quiet] != ""} {
        close_project
    }
    
    # Clean up existing project directory
    if {[file exists $project_name]} {
        puts "Removing existing project directory..."
        file delete -force $project_name
    }
    
    # Validate source files exist
    puts "Validating source files..."
    set missing_files {}
    foreach file $source_files {
        if {![file exists $file]} {
            lappend missing_files $file
        }
    }
    
    if {[llength $missing_files] > 0} {
        puts "ERROR: Missing source files:"
        foreach file $missing_files {
            puts "  - $file"
        }
        handle_error "Cannot proceed without all source files"
    }
    
    # Create project
    puts "Creating Vivado project..."
    if {[catch {create_project $project_name ./$project_name -part $target_part -force} result]} {
        handle_error "Failed to create project: $result"
    }
    
    # Add source files
    puts "Adding source files..."
    foreach file $source_files {
        puts "  Adding: $file"
        if {[catch {add_files $file} result]} {
            handle_error "Failed to add file $file: $result"
        }
    }
    
    # Update compile order
    puts "Updating compile order..."
    update_compile_order -fileset sources_1
    
    # Add constraints (if they exist)
    foreach file $constraint_files {
        if {[file exists $file]} {
            puts "Adding constraint file: $file"
            if {[catch {add_files -fileset constrs_1 $file} result]} {
                puts "Warning: Failed to add constraint file $file: $result"
            }
        } else {
            puts "Note: Constraint file $file not found (will run without constraints)"
        }
    }
    
    # Set top module
    puts "Setting top module to: $top_module"
    if {[catch {set_property top $top_module [current_fileset]} result]} {
        handle_error "Failed to set top module: $result"
    }
    
    # Validate design
    puts "Validating design..."
    if {[catch {check_syntax} result]} {
        puts "Warning: Syntax check issues found: $result"
    }
    
    # Reset synthesis run if it exists
    if {[get_runs synth_1 -quiet] != ""} {
        reset_run synth_1
    }
    
    # Synthesis settings
    puts "Configuring synthesis settings..."
    set_property strategy "Vivado Synthesis Defaults" [get_runs synth_1]
    set_property steps.synth_design.args.flatten_hierarchy "rebuilt" [get_runs synth_1]
    set_property steps.synth_design.args.keep_equivalent_registers true [get_runs synth_1]
    
    # Run synthesis
    puts "Running synthesis..."
    if {[catch {launch_runs synth_1 -jobs 4} result]} {
        handle_error "Failed to launch synthesis: $result"
    }
    
    if {[catch {wait_on_run synth_1} result]} {
        handle_error "Synthesis run failed: $result"
    }
    
    # Check synthesis status
    set synth_status [get_property STATUS [get_runs synth_1]]
    if {$synth_status != "synth_design Complete!"} {
        handle_error "Synthesis failed with status: $synth_status"
    }
    
    puts "Synthesis completed successfully!"
    
    # Generate synthesis reports
    puts "Generating synthesis reports..."
    if {[catch {open_run synth_1} result]} {
        puts "Warning: Could not open synthesis run: $result"
    } else {
        if {[catch {report_utilization -file utilization_synth.rpt} result]} {
            puts "Warning: Could not generate utilization report: $result"
        }
        if {[catch {report_timing_summary -file timing_synth.rpt} result]} {
            puts "Warning: Could not generate timing report: $result"
        }
        puts "Synthesis reports generated"
    }
    
    # Reset implementation run if it exists
    if {[get_runs impl_1 -quiet] != ""} {
        reset_run impl_1
    }
    
    # Implementation settings
    puts "Configuring implementation settings..."
    set_property strategy "Vivado Implementation Defaults" [get_runs impl_1]
    
    # Run implementation
    puts "Running implementation..."
    if {[catch {launch_runs impl_1 -jobs 4} result]} {
        handle_error "Failed to launch implementation: $result"
    }
    
    if {[catch {wait_on_run impl_1} result]} {
        handle_error "Implementation run failed: $result"
    }
    
    # Check implementation status
    set impl_status [get_property STATUS [get_runs impl_1]]
    if {![string match "*Complete!" $impl_status]} {
        handle_error "Implementation failed with status: $impl_status"
    }
    
    puts "Implementation completed successfully!"
    
    # Generate implementation reports
    puts "Generating implementation reports..."
    if {[catch {open_run impl_1} result]} {
        puts "Warning: Could not open implementation run: $result"
    } else {
        if {[catch {report_utilization -file utilization_impl.rpt} result]} {
            puts "Warning: Could not generate utilization report: $result"
        }
        if {[catch {report_timing_summary -file timing_impl.rpt} result]} {
            puts "Warning: Could not generate timing report: $result"
        }
        if {[catch {report_power -file power.rpt} result]} {
            puts "Warning: Could not generate power report: $result"
        }
        puts "Implementation reports generated"
    }
    
    # Generate bitstream
    puts "Generating bitstream..."
    if {[catch {launch_runs impl_1 -to_step write_bitstream -jobs 4} result]} {
        puts "Warning: Failed to launch bitstream generation: $result"
    } else {
        if {[catch {wait_on_run impl_1} result]} {
            puts "Warning: Bitstream generation failed: $result"
        } else {
            puts "Bitstream generated successfully!"
        }
    }
    
    puts ""
    puts "=== SYNTHESIS AND IMPLEMENTATION COMPLETED ==="
    puts "Project location: [pwd]/$project_name"
    puts "Reports generated:"
    if {[file exists "utilization_synth.rpt"]} {puts "  - utilization_synth.rpt"}
    if {[file exists "timing_synth.rpt"]} {puts "  - timing_synth.rpt"}
    if {[file exists "utilization_impl.rpt"]} {puts "  - utilization_impl.rpt"}
    if {[file exists "timing_impl.rpt"]} {puts "  - timing_impl.rpt"}
    if {[file exists "power.rpt"]} {puts "  - power.rpt"}
    
    # Check if bitstream was generated
    set bitstream_file "$project_name/$project_name.runs/impl_1/$top_module.bit"
    if {[file exists $bitstream_file]} {
        puts "  - Bitstream: $bitstream_file"
    }
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

# Synthesis-only flow (faster for testing)
proc run_synthesis_only {} {
    global project_name top_module target_part source_files constraint_files
    
    puts "Starting synthesis-only flow..."
    
    # Close any existing project
    if {[get_projects -quiet] != ""} {
        close_project
    }
    
    # Clean up existing project directory
    if {[file exists $project_name]} {
        puts "Removing existing project directory..."
        file delete -force $project_name
    }
    
    # Validate source files exist
    puts "Validating source files..."
    set missing_files {}
    foreach file $source_files {
        if {![file exists $file]} {
            lappend missing_files $file
        }
    }
    
    if {[llength $missing_files] > 0} {
        puts "ERROR: Missing source files:"
        foreach file $missing_files {
            puts "  - $file"
        }
        handle_error "Cannot proceed without all source files"
    }
    
    # Create project
    puts "Creating Vivado project..."
    if {[catch {create_project $project_name ./$project_name -part $target_part -force} result]} {
        handle_error "Failed to create project: $result"
    }
    
    # Add source files
    puts "Adding source files..."
    foreach file $source_files {
        puts "  Adding: $file"
        if {[catch {add_files $file} result]} {
            handle_error "Failed to add file $file: $result"
        }
    }
    
    # Update compile order
    puts "Updating compile order..."
    update_compile_order -fileset sources_1
    
    # Add constraints (if they exist)
    foreach file $constraint_files {
        if {[file exists $file]} {
            puts "Adding constraint file: $file"
            if {[catch {add_files -fileset constrs_1 $file} result]} {
                puts "Warning: Failed to add constraint file $file: $result"
            }
        } else {
            puts "Note: Constraint file $file not found (will run without constraints)"
        }
    }
    
    # Set top module
    puts "Setting top module to: $top_module"
    if {[catch {set_property top $top_module [current_fileset]} result]} {
        handle_error "Failed to set top module: $result"
    }
    
    # Validate design
    puts "Validating design..."
    if {[catch {check_syntax} result]} {
        puts "Warning: Syntax check issues found: $result"
    }
    
    # Reset synthesis run if it exists
    if {[get_runs synth_1 -quiet] != ""} {
        reset_run synth_1
    }
    
    # Synthesis settings
    puts "Configuring synthesis settings..."
    set_property strategy "Vivado Synthesis Defaults" [get_runs synth_1]
    set_property steps.synth_design.args.flatten_hierarchy "rebuilt" [get_runs synth_1]
    
    # Run synthesis
    puts "Running synthesis..."
    if {[catch {launch_runs synth_1 -jobs 4} result]} {
        handle_error "Failed to launch synthesis: $result"
    }
    
    if {[catch {wait_on_run synth_1} result]} {
        handle_error "Synthesis run failed: $result"
    }
    
    # Check synthesis status
    set synth_status [get_property STATUS [get_runs synth_1]]
    if {$synth_status != "synth_design Complete!"} {
        handle_error "Synthesis failed with status: $synth_status"
    }
    
    puts "Synthesis completed successfully!"
    
    # Generate synthesis reports
    puts "Generating synthesis reports..."
    if {[catch {open_run synth_1} result]} {
        puts "Warning: Could not open synthesis run: $result"
    } else {
        if {[catch {report_utilization -file utilization_synth.rpt} result]} {
            puts "Warning: Could not generate utilization report: $result"
        }
        if {[catch {report_timing_summary -file timing_synth.rpt} result]} {
            puts "Warning: Could not generate timing report: $result"
        }
        puts "Synthesis reports generated"
    }
    
    puts ""
    puts "=== SYNTHESIS COMPLETED ==="
    puts "Project location: [pwd]/$project_name"
    puts "Reports generated:"
    if {[file exists "utilization_synth.rpt"]} {puts "  - utilization_synth.rpt"}
    if {[file exists "timing_synth.rpt"]} {puts "  - timing_synth.rpt"}
}

# Timing constraints template
proc create_timing_constraints {} {
    puts "Creating timing constraints file..."
    
    if {[catch {set xdc_file [open "constraints.xdc" w]} result]} {
        handle_error "Failed to create constraints file: $result"
    }
    
    puts $xdc_file "# ==================================="
    puts $xdc_file "# FPGA Edge Detection Timing Constraints"
    puts $xdc_file "# Generated by synthesis script"
    puts $xdc_file "# ==================================="
    puts $xdc_file ""
    puts $xdc_file "# Clock constraints"
    puts $xdc_file "# Assuming 100MHz system clock (10ns period)"
    puts $xdc_file "create_clock -period 10.000 -name sys_clk \[get_ports clk\]"
    puts $xdc_file ""
    puts $xdc_file "# Input delay constraints"
    puts $xdc_file "set_input_delay -clock sys_clk -max 2.000 \[get_ports {pixel_in\[*\] pixel_valid start}\]"
    puts $xdc_file "set_input_delay -clock sys_clk -min 0.500 \[get_ports {pixel_in\[*\] pixel_valid start}\]"
    puts $xdc_file ""
    puts $xdc_file "# Output delay constraints"
    puts $xdc_file "set_output_delay -clock sys_clk -max 2.000 \[get_ports {edge_out\[*\] edge_valid ready processing_done}\]"
    puts $xdc_file "set_output_delay -clock sys_clk -min 0.500 \[get_ports {edge_out\[*\] edge_valid ready processing_done}\]"
    puts $xdc_file ""
    puts $xdc_file "# Reset constraints"
    puts $xdc_file "set_false_path -from \[get_ports rst_n\]"
    puts $xdc_file ""
    puts $xdc_file "# Memory interface constraints"
    puts $xdc_file "set_output_delay -clock sys_clk -max 3.000 \[get_ports {mem_addr\[*\] mem_data_out\[*\] mem_we mem_oe}\]"
    puts $xdc_file "set_output_delay -clock sys_clk -min 0.500 \[get_ports {mem_addr\[*\] mem_data_out\[*\] mem_we mem_oe}\]"
    puts $xdc_file "set_input_delay -clock sys_clk -max 3.000 \[get_ports {mem_data_in\[*\]}\]"
    puts $xdc_file "set_input_delay -clock sys_clk -min 0.500 \[get_ports {mem_data_in\[*\]}\]"
    puts $xdc_file ""
    puts $xdc_file "# Additional timing constraints for critical paths"
    puts $xdc_file "# Set max delay for line buffer to processing window paths"
    puts $xdc_file "set_max_delay -from \[get_pins {*gaussian_filter*/line_buffer*}\] -to \[get_pins {*sobel_operator*/window*}\] 5.000"
    puts $xdc_file "set_max_delay -from \[get_pins {*sobel_operator*/window*}\] -to \[get_pins {*gradient_magnitude*/gx_reg*}\] 3.000"
    puts $xdc_file ""
    puts $xdc_file "# Clock domain crossing constraints (if any)"
    puts $xdc_file "# set_false_path -from \[get_clocks clk1\] -to \[get_clocks clk2\]"
    puts $xdc_file ""
    puts $xdc_file "# Multi-cycle paths (if any)"
    puts $xdc_file "# set_multicycle_path -setup 2 -from \[get_pins source\] -to \[get_pins dest\]"
    puts $xdc_file "# set_multicycle_path -hold 1 -from \[get_pins source\] -to \[get_pins dest\]"
    
    close $xdc_file
    puts "Timing constraints created: constraints.xdc"
    puts "Note: Modify pin locations in constraints.xdc for your specific board"
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

# Validate environment
proc validate_environment {} {
    # Check if running in Vivado
    if {[catch {version} result]} {
        puts "Warning: Not running in Vivado environment"
        puts "Some commands may not work properly"
        return false
    }
    
    puts "Vivado Version: [version -short]"
    return true
}

# Main execution
if {[llength $argv] == 0} {
    puts "FPGA Edge Detection Synthesis Script"
    puts "===================================="
    puts "Usage: vivado -mode tcl -source synthesis_script.tcl -tclargs <command>"
    puts ""
    puts "Commands:"
    puts "  vivado      - Run full Vivado synthesis and implementation flow"
    puts "  synth_only  - Run synthesis only (faster for testing)"
    puts "  quartus     - Create Quartus project files"  
    puts "  constraints - Create timing constraints file"
    puts "  estimate    - Show resource estimation"
    puts "  analyze     - Show performance analysis"
    puts "  validate    - Validate environment and source files"
    puts ""
    puts "Examples:"
    puts "  vivado -mode tcl -source synthesis_script.tcl -tclargs vivado"
    puts "  vivado -mode tcl -source synthesis_script.tcl -tclargs synth_only"
    puts "  vivado -mode tcl -source synthesis_script.tcl -tclargs constraints"
    puts ""
    puts "For non-interactive use:"
    puts "  vivado -mode batch -source synthesis_script.tcl -tclargs vivado"
} else {
    set command [lindex $argv 0]
    
    # Validate environment for commands that need it
    if {$command == "vivado" || $command == "synth_only"} {
        if {![validate_environment]} {
            puts "Error: Vivado environment required for synthesis commands"
            exit 1
        }
    }
    
    switch $command {
        "vivado" {
            puts "Running full synthesis and implementation flow..."
            run_vivado_synthesis
        }
        "synth_only" {
            puts "Running synthesis-only flow..."
            run_synthesis_only
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
        "validate" {
            puts "Validating environment and source files..."
            validate_environment
            
            puts "\nChecking source files:"
            set all_files_exist true
            foreach file $source_files {
                if {[file exists $file]} {
                    puts "  ✓ $file"
                } else {
                    puts "  ✗ $file (missing)"
                    set all_files_exist false
                }
            }
            
            if {$all_files_exist} {
                puts "\n✓ All source files found"
            } else {
                puts "\n✗ Some source files are missing"
                exit 1
            }
            
            puts "\nValidation completed successfully!"
        }
        default {
            puts "Error: Unknown command '$command'"
            puts "Valid commands: vivado, synth_only, quartus, constraints, estimate, analyze, validate"
            puts "Use without arguments to see full help"
            exit 1
        }
    }
}