# Makefile for FPGA Edge Detection Simulation
# Supports GHDL simulator

# Project configuration
PROJECT = edge_detection
TESTBENCH = edge_detection_tb
SRC_DIR = ../src
TB_DIR = ../tb
WAVE_DIR = waves

# GHDL configuration
GHDL = ghdl
GHDL_FLAGS = --std=08 --workdir=work
GHDL_ELAB_FLAGS = --std=08 --workdir=work
GHDL_RUN_FLAGS = --stop-time=10ms --wave=$(WAVE_DIR)/$(TESTBENCH).ghw

# Source files (order matters for dependencies)
VHDL_SOURCES = \
	$(SRC_DIR)/convolution_3x3.vhd \
	$(SRC_DIR)/line_buffer.vhd \
	$(SRC_DIR)/sobel_operator.vhd \
	$(SRC_DIR)/magnitude_window_3x3.vhd \
	$(SRC_DIR)/non_max_suppression.vhd \
	$(SRC_DIR)/hysteresis_window_3x3.vhd \
	$(SRC_DIR)/hysteresis_threshold.vhd \
	$(SRC_DIR)/canny_detector.vhd \
	$(SRC_DIR)/edge_detection_top.vhd

# Testbench files
TB_SOURCES = \
	$(TB_DIR)/edge_detection_tb.vhd

# All VHDL files
ALL_SOURCES = $(VHDL_SOURCES) $(TB_SOURCES)

# Default target
all: compile elaborate run

# Create work directory
work:
	@mkdir -p work
	@mkdir -p $(WAVE_DIR)

# Clean target
clean:
	@echo "Cleaning up..."
	@rm -rf work
	@rm -rf $(WAVE_DIR)
	@rm -f *.cf
	@rm -f *.lst

# Compile all VHDL sources
compile: work
	@echo "Compiling VHDL sources..."
	@for file in $(ALL_SOURCES); do \
		echo "Compiling $$file"; \
		$(GHDL) -a $(GHDL_FLAGS) $$file; \
	done

# Elaborate testbench
elaborate:
	@echo "Elaborating testbench $(TESTBENCH)..."
	$(GHDL) -e $(GHDL_ELAB_FLAGS) $(TESTBENCH)

# Run simulation
run:
	@echo "Running simulation..."
	@mkdir -p $(WAVE_DIR)
	$(GHDL) -r $(GHDL_ELAB_FLAGS) $(TESTBENCH) $(GHDL_RUN_FLAGS)
	@echo "Simulation complete. Waveform saved to $(WAVE_DIR)/$(TESTBENCH).ghw"

# View waveforms with GTKWave
view:
	@if [ -f $(WAVE_DIR)/$(TESTBENCH).ghw ]; then \
		echo "Opening waveform viewer..."; \
		gtkwave $(WAVE_DIR)/$(TESTBENCH).ghw &; \
	else \
		echo "No waveform file found. Run 'make run' first."; \
	fi

# Syntax check only
syntax:
	@echo "Checking syntax..."
	@for file in $(ALL_SOURCES); do \
		echo "Checking $$file"; \
		$(GHDL) -s $(GHDL_FLAGS) $$file; \
	done

# Analyze dependencies
analyze:
	@echo "Analyzing dependencies..."
	$(GHDL) -a $(GHDL_FLAGS) $(ALL_SOURCES)

# Individual component tests
test-sobel:
	@echo "Testing Sobel operator..."
	$(GHDL) -a $(GHDL_FLAGS) $(SRC_DIR)/convolution_3x3.vhd
	$(GHDL) -a $(GHDL_FLAGS) $(SRC_DIR)/sobel_operator.vhd
	# Add specific sobel testbench here when created

test-canny:
	@echo "Testing Canny detector..."
	$(GHDL) -a $(GHDL_FLAGS) $(SRC_DIR)/magnitude_window_3x3.vhd
	$(GHDL) -a $(GHDL_FLAGS) $(SRC_DIR)/non_max_suppression.vhd
	$(GHDL) -a $(GHDL_FLAGS) $(SRC_DIR)/hysteresis_window_3x3.vhd
	$(GHDL) -a $(GHDL_FLAGS) $(SRC_DIR)/hysteresis_threshold.vhd
	$(GHDL) -a $(GHDL_FLAGS) $(SRC_DIR)/canny_detector.vhd
	# Add specific canny testbench here when created

# Quick test (fast simulation)
quick: compile elaborate
	@echo "Running quick simulation..."
	$(GHDL) -r $(GHDL_ELAB_FLAGS) $(TESTBENCH) --stop-time=1ms

# Full regression test
regression: clean all
	@echo "Running full regression test..."
	@if [ -f $(WAVE_DIR)/$(TESTBENCH).ghw ]; then \
		echo "Regression test PASSED"; \
	else \
		echo "Regression test FAILED"; \
		exit 1; \
	fi

# Generate file list for other tools
filelist:
	@echo "Generating file list..."
	@echo "# VHDL Source Files" > filelist.txt
	@for file in $(VHDL_SOURCES); do \
		echo "$$file" >> filelist.txt; \
	done
	@echo "# Testbench Files" >> filelist.txt
	@for file in $(TB_SOURCES); do \
		echo "$$file" >> filelist.txt; \
	done

# Help target
help:
	@echo "Available targets:"
	@echo "  all        - Compile, elaborate, and run simulation"
	@echo "  compile    - Compile all VHDL sources"
	@echo "  elaborate  - Elaborate testbench"
	@echo "  run        - Run simulation"
	@echo "  view       - Open waveform viewer (GTKWave)"
	@echo "  clean      - Clean up generated files"
	@echo "  syntax     - Check syntax only"
	@echo "  analyze    - Analyze dependencies"
	@echo "  quick      - Quick simulation (1ms)"
	@echo "  regression - Full regression test"
	@echo "  filelist   - Generate file list"
	@echo "  help       - Show this help"

# Alternative simulator support (ModelSim/QuestaSim)
VSIM = vsim
VCOM = vcom
VLIB = vlib
VMAP = vmap

# ModelSim targets
modelsim-setup:
	@echo "Setting up ModelSim environment..."
	$(VLIB) work
	$(VMAP) work work

modelsim-compile: modelsim-setup
	@echo "Compiling with ModelSim..."
	@for file in $(ALL_SOURCES); do \
		echo "Compiling $$file"; \
		$(VCOM) -work work $$file; \
	done

modelsim-run: modelsim-compile
	@echo "Running ModelSim simulation..."
	$(VSIM) -c work.$(TESTBENCH) -do "run -all; quit"

modelsim-gui: modelsim-compile
	@echo "Running ModelSim with GUI..."
	$(VSIM) work.$(TESTBENCH) &

# Vivado simulation targets
vivado-create:
	@echo "Creating Vivado project..."
	@echo "create_project $(PROJECT) ./vivado_project -part xc7a35tcpg236-1" > create_project.tcl
	@echo "add_files [list $(VHDL_SOURCES)]" >> create_project.tcl
	@echo "add_files -fileset sim_1 [list $(TB_SOURCES)]" >> create_project.tcl
	@echo "set_property top $(TESTBENCH) [get_filesets sim_1]" >> create_project.tcl
	@echo "launch_simulation" >> create_project.tcl
	vivado -mode batch -source create_project.tcl

.PHONY: all compile elaborate run view clean syntax analyze test-sobel test-canny quick regression filelist help modelsim-setup modelsim-compile modelsim-run modelsim-gui vivado-create