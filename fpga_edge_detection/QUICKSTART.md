# Quick Start Guide - FPGA Edge Detection System

## Prerequisites

1. **Xilinx Vivado** (2019.1 or later recommended)
2. **Source files** - All Verilog files in this directory
3. **Target FPGA** - Default: Artix-7 XC7A35T (modify in script if different)

## Step-by-Step Instructions

### 1. Validate Your Setup

First, check that all files are present and your environment is ready:

```bash
# Navigate to the project directory
cd fpga_edge_detection

# Run validation (this doesn't require Vivado)
vivado -mode tcl -source synthesis_script.tcl -tclargs validate
```

### 2. Create Timing Constraints (Optional but Recommended)

Generate the timing constraints file for your target frequency:

```bash
vivado -mode tcl -source synthesis_script.tcl -tclargs constraints
```

This creates `constraints.xdc` with timing constraints for 100MHz operation.

### 3. Run Synthesis Only (Fast Test)

For quick validation and resource estimation:

```bash
vivado -mode tcl -source synthesis_script.tcl -tclargs synth_only
```

This will:
- Create a Vivado project
- Add all source files
- Run synthesis
- Generate resource utilization reports
- Complete in ~2-5 minutes

### 4. Run Full Implementation (Complete Flow)

For bitstream generation and full timing analysis:

```bash
vivado -mode tcl -source synthesis_script.tcl -tclargs vivado
```

This will:
- Run synthesis
- Run place and route
- Generate timing reports
- Create bitstream
- Complete in ~10-30 minutes depending on your machine

### 5. Batch Mode (Non-Interactive)

For automated builds or CI/CD:

```bash
# Synthesis only
vivado -mode batch -source synthesis_script.tcl -tclargs synth_only

# Full flow
vivado -mode batch -source synthesis_script.tcl -tclargs vivado
```

## Output Files

After successful synthesis/implementation, you'll find:

### Reports
- `utilization_synth.rpt` - Synthesis resource usage
- `timing_synth.rpt` - Synthesis timing analysis
- `utilization_impl.rpt` - Implementation resource usage  
- `timing_impl.rpt` - Implementation timing analysis
- `power.rpt` - Power consumption analysis

### Project Files
- `edge_detection_fpga/` - Complete Vivado project directory
- `edge_detection_fpga/edge_detection_fpga.runs/impl_1/edge_detection_top.bit` - Bitstream file

### Constraint Files
- `constraints.xdc` - Timing constraints (if generated)

## Customization

### Change Target FPGA

Edit `synthesis_script.tcl` and modify:
```tcl
set target_part "xc7a35tcpg236-1"  # Change to your FPGA part number
```

Common alternatives:
- Artix-7: `xc7a100tcsg324-1`, `xc7a200tsbg484-1`
- Kintex-7: `xc7k325tffg676-1`
- Zynq-7000: `xc7z020clg484-1`, `xc7z045ffg900-2`

### Modify Image Resolution

Edit the parameters in `edge_detection_top.v`:
```verilog
parameter IMAGE_WIDTH = 1280,    // Change from default 640
parameter IMAGE_HEIGHT = 720,    // Change from default 480
```

### Adjust Clock Frequency

Modify `constraints.xdc`:
```tcl
create_clock -period 8.000 -name sys_clk [get_ports clk]  # 125MHz
# or
create_clock -period 5.000 -name sys_clk [get_ports clk]  # 200MHz
```

## Troubleshooting

### Common Errors and Solutions

**Error: "File not found"**
```
Solution: Ensure all .v files are in the same directory as synthesis_script.tcl
```

**Error: "Synthesis failed"**
```
Solution: Check utilization_synth.rpt for resource overflow
- Reduce IMAGE_WIDTH/IMAGE_HEIGHT parameters
- Use larger FPGA part
```

**Error: "Timing not met"**
```
Solution: Check timing_impl.rpt for critical paths
- Reduce clock frequency in constraints.xdc
- Add pipeline stages if needed
```

**Error: "No devices found"**
```
Solution: 
- Install correct device family in Vivado
- Check target_part in synthesis_script.tcl
```

### Performance Optimization

**For Higher Clock Speeds:**
1. Review timing reports for critical paths
2. Consider adding more pipeline stages
3. Use faster speed grade FPGA parts (-2, -3)

**For Lower Resource Usage:**
1. Reduce image dimensions
2. Decrease data width from 8 to 6 bits
3. Simplify filter kernels

**For Power Optimization:**
1. Use clock gating for unused modules
2. Reduce operating frequency
3. Consider low-power FPGA families

## Getting Help

### View Resource Estimates
```bash
vivado -mode tcl -source synthesis_script.tcl -tclargs estimate
```

### View Performance Analysis
```bash
vivado -mode tcl -source synthesis_script.tcl -tclargs analyze
```

### Check All Available Commands
```bash
vivado -mode tcl -source synthesis_script.tcl
```

## Intel Quartus Support

For Intel FPGAs, create project files:
```bash
vivado -mode tcl -source synthesis_script.tcl -tclargs quartus
```

Then compile with:
```bash
quartus_sh --flow compile edge_detection_fpga
```

## Simulation

Before synthesis, verify functionality with simulation:
```bash
# Using the provided Makefile
make sim

# Or manually with iverilog
iverilog -o edge_sim *.v
./edge_sim
```

---

**Success Indicators:**
- ✅ Synthesis completes without errors
- ✅ Timing is met (check timing reports)
- ✅ Resource utilization < 80% for each type
- ✅ Bitstream generation successful

**Next Steps:**
1. Load bitstream to FPGA
2. Connect to image sensor/camera
3. Verify edge detection results
4. Optimize for your specific application