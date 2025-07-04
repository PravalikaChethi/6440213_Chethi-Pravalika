# High-Speed FPGA-Based Real-Time Edge Detection Using Hybrid Sobel–Canny Algorithm

## Overview

This project implements a high-performance, real-time edge detection system on FPGA using a novel hybrid approach that combines the speed of the Sobel operator with the accuracy of the Canny edge detector. The system is designed for embedded vision applications requiring real-time processing capabilities.

## Key Features

- **Hybrid Algorithm**: Combines Sobel and Canny edge detection for optimal speed-accuracy tradeoff
- **Real-time Processing**: Capable of processing 640x480 video streams at 100+ FPS
- **Configurable Modes**: Pure Sobel, pure Canny, or hybrid operation
- **Pipelined Architecture**: Multi-stage pipeline for maximum throughput
- **Resource Efficient**: Optimized for modern FPGA architectures

## System Architecture

### Top-Level Block Diagram

```
┌─────────────────────────────────────────────────────────────┐
│                    Edge Detection Top                       │
├─────────────────────────────────────────────────────────────┤
│  ┌─────────────┐  ┌──────────────┐  ┌─────────────────────┐ │
│  │ Line Buffer │→ │ Sobel        │→ │ Canny Detector      │ │
│  │             │  │ Operator     │  │                     │ │
│  └─────────────┘  └──────────────┘  └─────────────────────┘ │
│                                                             │
│  ┌─────────────────────────────────────────────────────────┐ │
│  │              Hybrid Algorithm Selector                 │ │
│  └─────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────┘
```

### Component Hierarchy

1. **`edge_detection_top.vhd`** - Top-level entity with configuration interface
2. **`line_buffer.vhd`** - Line buffering for 3x3 convolution windows
3. **`sobel_operator.vhd`** - Sobel edge detection with gradient calculation
4. **`convolution_3x3.vhd`** - 3x3 convolution window generator
5. **`canny_detector.vhd`** - Complete Canny edge detection pipeline
6. **`non_max_suppression.vhd`** - Non-maximum suppression for edge thinning
7. **`magnitude_window_3x3.vhd`** - Window generator for magnitude processing
8. **`hysteresis_threshold.vhd`** - Hysteresis thresholding for edge linking
9. **`hysteresis_window_3x3.vhd`** - Window generator for hysteresis processing

## Algorithm Details

### Hybrid Sobel-Canny Approach

The hybrid algorithm leverages the strengths of both methods:

1. **Sobel Operator**: Fast gradient computation for initial edge detection
2. **Canny Detector**: Precise edge localization with non-maximum suppression and hysteresis
3. **Hybrid Mode**: Uses Sobel for rapid screening, applies Canny refinement selectively

### Processing Pipeline

```
Input Image → Line Buffer → Sobel Gradients → Canny Processing → Hybrid Selection → Edge Output
     ↓             ↓              ↓                ↓                  ↓             ↓
  Pixel Stream  3x3 Windows   Magnitude &      NMS & Hysteresis   Algorithm     Binary Edge
   640x480       Real-time     Direction        Edge Linking       Selection      Image
```

### Performance Characteristics

| Mode   | Throughput | Latency | Resource Usage | Edge Quality |
|--------|------------|---------|----------------|--------------|
| Sobel  | Highest    | Lowest  | Minimal        | Good         |
| Canny  | High       | Medium  | Moderate       | Excellent    |
| Hybrid | High       | Medium  | Moderate       | Very Good    |

## Hardware Requirements

### Target FPGA Families
- Xilinx 7-series (Artix-7, Kintex-7, Virtex-7)
- Xilinx UltraScale/UltraScale+
- Intel Cyclone V/10
- Intel Arria 10/Stratix 10

### Resource Utilization (Artix-7)
- **LUTs**: ~2,500 (for 640x480 processing)
- **FFs**: ~3,000
- **BRAMs**: 4-6 (for line buffers)
- **DSPs**: 8-12 (for multiplications)
- **Clock Frequency**: 100-150 MHz

### Memory Requirements
- Line Buffer Memory: ~5KB (640 pixels × 8 bits × 3 lines)
- Configuration Registers: <1KB
- Total On-chip Memory: ~6KB

## Interface Specifications

### Input Ports
| Signal | Width | Description |
|--------|-------|-------------|
| `clk` | 1 | System clock (100 MHz) |
| `reset` | 1 | Asynchronous reset (active high) |
| `enable` | 1 | System enable |
| `pixel_in` | 8 | Input pixel data (grayscale) |
| `pixel_valid_in` | 1 | Input pixel valid signal |
| `sobel_threshold` | 8 | Sobel edge threshold |
| `canny_low_th` | 8 | Canny low threshold |
| `canny_high_th` | 8 | Canny high threshold |
| `hybrid_mode` | 2 | Algorithm selection (00=Sobel, 01=Canny, 10=Hybrid) |
| `edge_ready_in` | 1 | Downstream ready signal |

### Output Ports
| Signal | Width | Description |
|--------|-------|-------------|
| `edge_out` | 8 | Output edge image |
| `edge_valid_out` | 1 | Output valid signal |
| `pixel_ready_out` | 1 | Input ready signal |
| `processing_done` | 1 | Frame processing complete |
| `frame_count` | 16 | Processed frame counter |

## Configuration Parameters

### Generic Parameters
```vhdl
generic (
    IMAGE_WIDTH  : integer := 640;  -- Image width in pixels
    IMAGE_HEIGHT : integer := 480;  -- Image height in pixels
    DATA_WIDTH   : integer := 8;    -- Pixel data width
    ADDR_WIDTH   : integer := 19    -- Address width (log2(WIDTH*HEIGHT))
);
```

### Threshold Settings
- **Sobel Threshold** (0-255): Higher values = fewer edges, lower noise
- **Canny Low Threshold** (0-255): Lower bound for edge candidates
- **Canny High Threshold** (0-255): Upper bound for strong edges

### Recommended Settings
| Application | Sobel Th | Canny Low | Canny High | Mode |
|-------------|----------|-----------|------------|------|
| General Purpose | 50 | 30 | 100 | Hybrid |
| High Sensitivity | 30 | 20 | 60 | Canny |
| Fast Processing | 70 | N/A | N/A | Sobel |
| Noise Suppression | 80 | 40 | 120 | Canny |

## Getting Started

### Prerequisites
- FPGA development tools (Vivado, Quartus, etc.)
- VHDL simulator (GHDL, ModelSim, or Vivado Simulator)
- Python 3.x with OpenCV and NumPy (for reference implementation)
- GTKWave (for waveform viewing)

### Quick Start
1. **Clone the repository**:
   ```bash
   git clone <repository_url>
   cd fpga_edge_detection
   ```

2. **Run Python reference**:
   ```bash
   cd python_ref
   python edge_detection_reference.py --pattern mixed
   ```

3. **Simulate VHDL design**:
   ```bash
   cd sim
   make all
   make view  # View waveforms
   ```

4. **Synthesize for FPGA**:
   - Open Vivado/Quartus
   - Create new project
   - Add source files from `src/` directory
   - Add constraints from `constraints/` directory
   - Run synthesis and implementation

### Simulation Instructions

#### Using GHDL
```bash
cd sim
make compile    # Compile VHDL sources
make elaborate  # Elaborate testbench
make run        # Run simulation
make view       # View waveforms with GTKWave
```

#### Using ModelSim
```bash
cd sim
make modelsim-compile
make modelsim-gui
```

#### Using Vivado Simulator
```bash
cd sim
make vivado-create
```

## File Structure

```
fpga_edge_detection/
├── src/                          # VHDL source files
│   ├── edge_detection_top.vhd    # Top-level module
│   ├── line_buffer.vhd           # Line buffering
│   ├── sobel_operator.vhd        # Sobel edge detection
│   ├── convolution_3x3.vhd       # 3x3 convolution
│   ├── canny_detector.vhd        # Canny edge detection
│   ├── non_max_suppression.vhd   # Non-maximum suppression
│   ├── magnitude_window_3x3.vhd  # Magnitude windowing
│   ├── hysteresis_threshold.vhd  # Hysteresis thresholding
│   └── hysteresis_window_3x3.vhd # Hysteresis windowing
├── tb/                           # Testbenches
│   └── edge_detection_tb.vhd     # Main testbench
├── constraints/                  # FPGA constraints
│   └── edge_detection_constraints.xdc
├── sim/                          # Simulation files
│   └── Makefile                  # Simulation makefile
├── python_ref/                   # Python reference
│   └── edge_detection_reference.py
└── docs/                         # Documentation
    └── README.md                 # This file
```

## Testing and Validation

### Test Patterns
The system includes several built-in test patterns:
- **Gradient**: Horizontal and vertical gradients
- **Checkerboard**: Regular checkerboard pattern
- **Mixed**: Combination of different edge types

### Validation Approach
1. **Python Reference**: Bit-accurate reference implementation
2. **VHDL Testbench**: Comprehensive testbench with multiple test cases
3. **Hardware Validation**: Real-time testing on development boards

### Performance Metrics
- **Throughput**: Frames per second at target resolution
- **Latency**: Clock cycles from input to first output
- **Resource Usage**: LUTs, FFs, BRAMs, DSPs
- **Power Consumption**: Dynamic and static power

## Applications

### Target Applications
- **Autonomous Vehicles**: Real-time road edge detection
- **Industrial Inspection**: Quality control and defect detection
- **Medical Imaging**: Feature extraction and analysis
- **Robotics**: Environment perception and navigation
- **Security Systems**: Motion detection and tracking

### Integration Examples
- Camera interface (MIPI CSI-2, parallel)
- Display output (HDMI, VGA)
- Processing pipelines (stereo vision, object detection)
- Embedded systems (Zynq SoC, NIOS II)

## Optimization Guidelines

### Performance Optimization
1. **Pipeline Depth**: Adjust pipeline stages for clock frequency
2. **Memory Organization**: Optimize line buffer implementation
3. **Parallel Processing**: Implement multiple processing units
4. **Clock Domain**: Use appropriate clock frequencies

### Resource Optimization
1. **Threshold Selection**: Use appropriate bit widths
2. **Memory Usage**: Optimize line buffer size
3. **Logic Sharing**: Share computation resources
4. **DSP Utilization**: Use dedicated multipliers

## Troubleshooting

### Common Issues
1. **Timing Violations**: Reduce clock frequency or add pipeline stages
2. **Memory Issues**: Check line buffer implementation
3. **Functional Errors**: Verify against Python reference
4. **Resource Overflow**: Optimize design or use larger FPGA

### Debug Strategies
1. **Simulation**: Use comprehensive testbenches
2. **ILA/ChipScope**: Insert logic analyzers for hardware debug
3. **Reference Comparison**: Compare with Python implementation
4. **Step-by-step**: Test individual components separately

## Future Enhancements

### Planned Features
- **Color Image Support**: RGB and HSV processing
- **Multiple Scales**: Multi-resolution edge detection
- **Advanced Algorithms**: Laplacian of Gaussian, Prewitt operator
- **Machine Learning**: CNN-based edge detection
- **Optimization**: Further resource and power optimization

### Research Directions
- **Adaptive Thresholding**: Dynamic threshold adjustment
- **Context-aware Processing**: Scene-dependent optimization
- **Power Management**: Dynamic voltage and frequency scaling
- **AI Integration**: Deep learning acceleration

## Contributing

### Development Guidelines
1. Follow VHDL coding standards
2. Maintain bit-accurate Python reference
3. Include comprehensive testbenches
4. Document all interfaces and parameters
5. Verify on hardware when possible

### Code Review Process
1. Functional verification against reference
2. Timing closure verification
3. Resource utilization review
4. Code quality and documentation review

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Citations

### References
1. Canny, J. (1986). "A computational approach to edge detection"
2. Sobel, I. (1968). "Camera Models and Machine Perception"
3. Various FPGA optimization techniques and implementation guides

### Related Work
- Real-time image processing on FPGAs
- Hardware acceleration for computer vision
- Edge detection algorithm comparisons

## Contact Information

For questions, issues, or contributions, please contact:
- **Email**: [your-email@domain.com]
- **GitHub**: [repository-url]
- **Documentation**: [documentation-url]

---

*This project demonstrates state-of-the-art FPGA implementation of hybrid edge detection algorithms for real-time embedded vision applications.*