# Makefile for FPGA Edge Detection System
# Supports simulation with Icarus Verilog and ModelSim

# Project settings
PROJECT_NAME = edge_detection
TOP_MODULE = edge_detection_top
TESTBENCH = testbench

# Source files
SOURCES = edge_detection_top.v \
          control_unit.v \
          image_buffer.v \
          gaussian_filter.v \
          sobel_operator.v \
          gradient_magnitude.v \
          nonmax_suppression.v \
          hysteresis_threshold.v

# Simulation settings
SIM_TIME = 100us
VCD_FILE = $(PROJECT_NAME)_tb.vcd

# Tools
IVERILOG = iverilog
VVP = vvp
GTKWAVE = gtkwave
VSIM = vsim

# Default target
all: sim

# Icarus Verilog simulation
sim: $(PROJECT_NAME)_sim
	./$(PROJECT_NAME)_sim

$(PROJECT_NAME)_sim: $(SOURCES) $(TESTBENCH).v
	$(IVERILOG) -o $(PROJECT_NAME)_sim $(SOURCES) $(TESTBENCH).v

# Run simulation and open waveforms
sim_wave: sim
	$(GTKWAVE) $(VCD_FILE) &

# ModelSim simulation (if available)
modelsim: $(SOURCES) $(TESTBENCH).v
	vlib work
	vlog $(SOURCES) $(TESTBENCH).v
	$(VSIM) -c $(TESTBENCH) -do "run $(SIM_TIME); quit"

# ModelSim with GUI
modelsim_gui: $(SOURCES) $(TESTBENCH).v
	vlib work
	vlog $(SOURCES) $(TESTBENCH).v
	$(VSIM) $(TESTBENCH) -do "run $(SIM_TIME)"

# Synthesis check (using Yosys if available)
synth:
	@if command -v yosys > /dev/null; then \
		echo "Running synthesis check with Yosys..."; \
		yosys -p "read_verilog $(SOURCES); synth -top $(TOP_MODULE); stat"; \
	else \
		echo "Yosys not found. Skipping synthesis check."; \
	fi

# Lint check (using Verilator if available)
lint:
	@if command -v verilator > /dev/null; then \
		echo "Running lint check with Verilator..."; \
		verilator --lint-only $(SOURCES) --top-module $(TOP_MODULE); \
	else \
		echo "Verilator not found. Skipping lint check."; \
	fi

# Clean generated files
clean:
	rm -f $(PROJECT_NAME)_sim
	rm -f $(VCD_FILE)
	rm -f *.vcd
	rm -f *.out
	rm -f edge_detection_output.txt
	rm -rf work/
	rm -f transcript
	rm -f vsim.wlf

# Show help
help:
	@echo "Available targets:"
	@echo "  all         - Run simulation (default)"
	@echo "  sim         - Run Icarus Verilog simulation"
	@echo "  sim_wave    - Run simulation and open waveforms"
	@echo "  modelsim    - Run ModelSim simulation (command line)"
	@echo "  modelsim_gui- Run ModelSim simulation (GUI)"
	@echo "  synth       - Run synthesis check with Yosys"
	@echo "  lint        - Run lint check with Verilator"
	@echo "  clean       - Clean generated files"
	@echo "  help        - Show this help message"

# Check dependencies
check_deps:
	@echo "Checking tool dependencies..."
	@command -v $(IVERILOG) > /dev/null && echo "✓ Icarus Verilog found" || echo "✗ Icarus Verilog not found"
	@command -v $(GTKWAVE) > /dev/null && echo "✓ GTKWave found" || echo "✗ GTKWave not found"
	@command -v yosys > /dev/null && echo "✓ Yosys found" || echo "✗ Yosys not found"
	@command -v verilator > /dev/null && echo "✓ Verilator found" || echo "✗ Verilator not found"
	@command -v $(VSIM) > /dev/null && echo "✓ ModelSim found" || echo "✗ ModelSim not found"

.PHONY: all sim sim_wave modelsim modelsim_gui synth lint clean help check_deps