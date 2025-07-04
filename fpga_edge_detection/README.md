# High-Speed FPGA-Based Real-Time Edge Detection Using Hybrid Sobel-Canny Algorithm

## Project Overview

This project implements a high-performance, real-time edge detection system on FPGA using a hybrid Sobel-Canny algorithm optimized for embedded vision applications. The design combines the computational efficiency of the Sobel operator with the accuracy of the Canny edge detector to achieve superior edge detection performance.

## Features

- **Real-time Processing**: Optimized pipeline architecture for high-speed image processing
- **Hybrid Algorithm**: Combines Sobel and Canny algorithms for enhanced edge detection
- **Configurable Parameters**: Adjustable image dimensions, data width, and thresholds
- **Memory Efficient**: Optimized line buffer usage for minimal memory footprint
- **Pipeline Architecture**: Multi-stage pipeline for maximum throughput
- **FPGA Optimized**: Hardware-specific optimizations for FPGA deployment

## Architecture

### System Block Diagram

```
Input Image → Image Buffer → Gaussian Filter → Sobel Operator → Gradient Magnitude
                                ↓
Edge Output ← Hysteresis Threshold ← Non-Max Suppression ←─────────┘
```

### Key Components

1. **Edge Detection Top (`edge_detection_top.v`)**
   - Main module integrating all components
   - Parameter configuration and signal routing
   - Pipeline coordination

2. **Control Unit (`control_unit.v`)**
   - State machine for pipeline control
   - Stage coordination and timing management
   - Processing flow control

3. **Image Buffer (`image_buffer.v`)**
   - Memory interface management
   - Input data buffering
   - Address generation

4. **Gaussian Filter (`gaussian_filter.v`)**
   - 3×3 Gaussian convolution
   - Noise reduction preprocessing
   - Pipeline-optimized implementation

5. **Sobel Operator (`sobel_operator.v`)**
   - Gradient calculation in X and Y directions
   - 3×3 Sobel kernel convolution
   - Real-time gradient computation

6. **Gradient Magnitude (`gradient_magnitude.v`)**
   - Magnitude and direction calculation
   - 8-direction approximation
   - Hardware-optimized arctangent

7. **Non-Maximum Suppression (`nonmax_suppression.v`)**
   - Edge thinning algorithm
   - Direction-based neighbor selection
   - Local maximum detection

8. **Hysteresis Thresholding (`hysteresis_threshold.v`)**
   - Dual-threshold edge classification
   - Connectivity analysis
   - Final edge determination

## Technical Specifications

### Default Parameters
- **Image Resolution**: 640×480 (configurable)
- **Data Width**: 8-bit (configurable)
- **High Threshold**: 100 (configurable)
- **Low Threshold**: 50 (configurable)
- **Pipeline Stages**: 7 stages
- **Memory Interface**: External RAM support

### Performance Characteristics
- **Throughput**: ~1 pixel per clock cycle (after pipeline fill)
- **Latency**: ~40 clock cycles (pipeline depth)
- **Resource Utilization**: Optimized for modern FPGAs
- **Power Consumption**: Low-power design considerations

## File Structure

```
fpga_edge_detection/
├── edge_detection_top.v      # Top-level module
├── control_unit.v            # Pipeline control state machine
├── image_buffer.v            # Memory interface and buffering
├── gaussian_filter.v         # Gaussian blur preprocessing
├── sobel_operator.v          # Sobel gradient calculation
├── gradient_magnitude.v      # Magnitude and direction computation
├── nonmax_suppression.v      # Non-maximum suppression
├── hysteresis_threshold.v    # Hysteresis thresholding
├── testbench.v              # Comprehensive testbench
└── README.md                # This documentation file
```

## Algorithm Details

### 1. Gaussian Filtering
- **Kernel**: 3×3 Gaussian kernel with σ≈0.8
- **Weights**: [1,2,1; 2,4,2; 1,2,1] / 16
- **Purpose**: Noise reduction and smoothing

### 2. Sobel Gradient Calculation
- **Gx Kernel**: [-1,0,1; -2,0,2; -1,0,1]
- **Gy Kernel**: [-1,-2,-1; 0,0,0; 1,2,1]
- **Output**: Gradient magnitudes in X and Y directions

### 3. Gradient Magnitude and Direction
- **Magnitude**: |Gx| + |Gy| (Manhattan distance approximation)
- **Direction**: 8-direction quantization (0°, 45°, 90°, 135°, etc.)
- **Optimization**: Hardware-friendly approximations

### 4. Non-Maximum Suppression
- **Method**: Local maximum detection along gradient direction
- **Window**: 3×3 neighborhood analysis
- **Result**: Thin, single-pixel-wide edges

### 5. Hysteresis Thresholding
- **High Threshold**: Strong edge classification
- **Low Threshold**: Weak edge classification
- **Connectivity**: Weak edges connected to strong edges are preserved

## Usage Instructions

### 1. Simulation
```bash
# Compile all Verilog files
iverilog -o edge_detection_sim *.v

# Run simulation
./edge_detection_sim

# View waveforms (if VCD dumping enabled)
gtkwave edge_detection_tb.vcd
```

### 2. FPGA Implementation
1. **Create Project**: Import all .v files into your FPGA tool
2. **Set Top Module**: `edge_detection_top`
3. **Configure Parameters**: Adjust IMAGE_WIDTH, IMAGE_HEIGHT, etc.
4. **Synthesis**: Run synthesis with timing constraints
5. **Implementation**: Place and route for target FPGA
6. **Generate Bitstream**: Create programming file

### 3. Integration
```verilog
// Example instantiation
edge_detection_top #(
    .IMAGE_WIDTH(640),
    .IMAGE_HEIGHT(480),
    .DATA_WIDTH(8),
    .ADDR_WIDTH(19)
) edge_detector (
    .clk(system_clk),
    .rst_n(reset_n),
    .start(start_processing),
    .pixel_in(input_pixel),
    .pixel_valid(pixel_valid),
    .ready(system_ready),
    .edge_out(detected_edge),
    .edge_valid(edge_pixel_valid),
    .processing_done(processing_complete),
    // Memory interface signals...
);
```

## Interface Signals

### Input Signals
- `clk`: System clock
- `rst_n`: Active-low reset
- `start`: Start processing trigger
- `pixel_in[7:0]`: Input pixel data
- `pixel_valid`: Input pixel valid signal
- `mem_data_in[7:0]`: Memory read data

### Output Signals
- `ready`: System ready for new frame
- `edge_out[7:0]`: Detected edge pixel
- `edge_valid`: Edge pixel valid signal
- `processing_done`: Frame processing complete
- `current_stage[3:0]`: Current pipeline stage
- `processed_pixels[15:0]`: Pixel counter

### Memory Interface
- `mem_addr[18:0]`: Memory address
- `mem_data_out[7:0]`: Memory write data
- `mem_we`: Memory write enable
- `mem_oe`: Memory output enable

## Customization Options

### Parameter Modification
```verilog
// Adjust image dimensions
parameter IMAGE_WIDTH = 1280;
parameter IMAGE_HEIGHT = 720;

// Modify data precision
parameter DATA_WIDTH = 10;

// Tune thresholds
parameter HIGH_THRESHOLD = 8'd120;
parameter LOW_THRESHOLD = 8'd60;
```

### Algorithm Variations
- **Magnitude Calculation**: Switch between Manhattan and Euclidean distance
- **Direction Quantization**: Modify from 8 to 4 or 16 directions
- **Filter Kernels**: Experiment with different Gaussian kernel sizes
- **Threshold Adaptation**: Implement adaptive thresholding

## Performance Optimization

### Resource Optimization
- **Memory Usage**: Line buffers optimized for minimum BRAM usage
- **DSP Utilization**: Efficient use of hardware multipliers
- **Logic Optimization**: Reduced combinational logic depth

### Speed Optimization
- **Pipeline Balancing**: Even stage delays for maximum frequency
- **Critical Path**: Optimized for high-speed operation
- **Parallel Processing**: Independent stage operations

## Testing and Verification

### Testbench Features
- **Synthetic Test Patterns**: Generated geometric shapes
- **Performance Monitoring**: Throughput and latency measurement
- **Pipeline Verification**: Stage-by-stage validation
- **Output Validation**: Edge detection quality assessment

### Test Scenarios
1. **Basic Functionality**: Simple geometric patterns
2. **Noise Robustness**: Noisy input images
3. **Edge Cases**: Boundary conditions and corner cases
4. **Performance**: Maximum throughput testing

## Applications

### Target Applications
- **Autonomous Vehicles**: Lane detection and obstacle recognition
- **Industrial Inspection**: Quality control and defect detection
- **Robotics**: Object recognition and navigation
- **Security Systems**: Motion detection and tracking
- **Medical Imaging**: Feature extraction and analysis

### Integration Examples
- **Camera Interfaces**: Direct connection to image sensors
- **Video Processing**: Real-time video stream processing
- **Embedded Systems**: Low-power vision applications
- **ADAS Systems**: Advanced driver assistance features

## Future Enhancements

### Potential Improvements
1. **Multi-Scale Processing**: Pyramid-based edge detection
2. **Adaptive Thresholds**: Dynamic threshold calculation
3. **Color Support**: RGB and multi-channel processing
4. **Advanced Filters**: Bilateral and anisotropic filtering
5. **Sub-pixel Accuracy**: Enhanced edge localization

### Performance Upgrades
- **Higher Parallelism**: Multiple pixel processing per cycle
- **Advanced Memory**: DDR interface for larger images
- **Floating Point**: Higher precision calculations
- **Machine Learning**: CNN-based edge detection

## License and Citation

This implementation is designed for research and educational purposes. When using this code for academic research, please cite:

```
FPGA-Based Real-Time Edge Detection Using Hybrid Sobel-Canny Algorithm
for Embedded Vision Applications - Research Implementation
```

## Contact and Support

For questions, improvements, or collaboration opportunities, please refer to the project documentation or submit issues through the appropriate channels.

---

**Note**: This implementation prioritizes real-time performance and FPGA optimization while maintaining edge detection quality suitable for embedded vision applications.