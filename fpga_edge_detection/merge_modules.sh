#!/bin/bash

# Merge all edge detection modules into single file
echo "Merging FPGA Edge Detection modules..."

# Create the complete merged file
cat > edge_detection_complete_merged.v << 'EOF'
//==============================================================================
// COMPLETE FPGA-Based Real-Time Edge Detection System
// Hybrid Sobel-Canny Algorithm Implementation
// All 8 modules merged into single file for easy deployment
// Target: Artix-7 XC7A100T-CSG324-1, Vivado 2024.1
//==============================================================================

EOF

# Append part 1 (top-level, control, image buffer)
cat edge_detection_complete.v >> edge_detection_complete_merged.v

# Append part 2 (gaussian, sobel)  
cat edge_detection_complete_part2.v >> edge_detection_complete_merged.v

# Append part 3 (gradient magnitude, nonmax, hysteresis)
cat edge_detection_complete_part3.v >> edge_detection_complete_merged.v

echo "Merged file created: edge_detection_complete_merged.v"
echo "File size: $(wc -l < edge_detection_complete_merged.v) lines"
echo "Ready for synthesis!"