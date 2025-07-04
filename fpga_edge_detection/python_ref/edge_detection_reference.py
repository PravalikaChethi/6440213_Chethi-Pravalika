#!/usr/bin/env python3
"""
Reference Implementation of Hybrid Sobel-Canny Edge Detection
for FPGA validation and algorithm comparison.

This implementation mirrors the VHDL design for bit-accurate validation.
"""

import numpy as np
import cv2
import matplotlib.pyplot as plt
from scipy import ndimage
from typing import Tuple, Optional
import argparse

class EdgeDetectionReference:
    """
    Reference implementation of the hybrid Sobel-Canny edge detection algorithm.
    Matches the FPGA implementation for validation purposes.
    """
    
    def __init__(self, image_width: int = 640, image_height: int = 480):
        self.image_width = image_width
        self.image_height = image_height
        
        # Sobel kernels (matching FPGA implementation)
        self.sobel_x = np.array([[-1, 0, 1],
                                [-2, 0, 2],
                                [-1, 0, 1]], dtype=np.float32)
        
        self.sobel_y = np.array([[-1, -2, -1],
                                [ 0,  0,  0],
                                [ 1,  2,  1]], dtype=np.float32)
    
    def apply_sobel(self, image: np.ndarray, threshold: int = 50) -> Tuple[np.ndarray, np.ndarray, np.ndarray]:
        """
        Apply Sobel edge detection operator.
        
        Args:
            image: Input grayscale image (uint8)
            threshold: Edge threshold value
            
        Returns:
            tuple: (binary_edges, gradient_magnitude, gradient_direction)
        """
        # Convert to float for calculations
        img_float = image.astype(np.float32)
        
        # Apply Sobel kernels
        gx = ndimage.convolve(img_float, self.sobel_x, mode='constant', cval=0)
        gy = ndimage.convolve(img_float, self.sobel_y, mode='constant', cval=0)
        
        # Calculate magnitude using Manhattan distance (matching FPGA)
        # This is faster than Euclidean distance and close enough for edge detection
        gradient_magnitude = np.abs(gx) + np.abs(gy)
        
        # Calculate gradient direction (in degrees)
        gradient_direction = np.arctan2(gy, gx) * 180 / np.pi
        gradient_direction[gradient_direction < 0] += 360
        
        # Quantize to 4 directions (matching FPGA implementation)
        quantized_direction = self._quantize_direction(gradient_direction)
        
        # Apply threshold for binary edge detection
        binary_edges = (gradient_magnitude > threshold).astype(np.uint8) * 255
        
        # Clamp magnitude to 8-bit range
        gradient_magnitude = np.clip(gradient_magnitude, 0, 255).astype(np.uint8)
        
        return binary_edges, gradient_magnitude, quantized_direction
    
    def _quantize_direction(self, direction: np.ndarray) -> np.ndarray:
        """
        Quantize gradient directions to 4 categories: 0, 45, 90, 135 degrees.
        Matches the FPGA implementation.
        """
        quantized = np.zeros_like(direction, dtype=np.uint8)
        
        # 0 degrees (horizontal)
        mask_0 = (direction < 22.5) | (direction >= 337.5)
        quantized[mask_0] = 0
        
        # 45 degrees (diagonal)
        mask_45 = (direction >= 22.5) & (direction < 67.5)
        quantized[mask_45] = 45
        
        # 90 degrees (vertical)
        mask_90 = (direction >= 67.5) & (direction < 112.5)
        quantized[mask_90] = 90
        
        # 135 degrees (diagonal)
        mask_135 = (direction >= 112.5) & (direction < 337.5)
        quantized[mask_135] = 135
        
        return quantized
    
    def non_maximum_suppression(self, gradient_mag: np.ndarray, 
                               gradient_dir: np.ndarray) -> np.ndarray:
        """
        Apply non-maximum suppression to thin edges.
        
        Args:
            gradient_mag: Gradient magnitude image
            gradient_dir: Quantized gradient direction image
            
        Returns:
            np.ndarray: Non-maximum suppressed magnitude image
        """
        rows, cols = gradient_mag.shape
        suppressed = np.zeros_like(gradient_mag)
        
        # Pad the image for boundary handling
        padded_mag = np.pad(gradient_mag, 1, mode='constant', constant_values=0)
        
        for i in range(1, rows + 1):
            for j in range(1, cols + 1):
                direction = gradient_dir[i-1, j-1]
                current_mag = padded_mag[i, j]
                
                # Select neighbors based on gradient direction
                if direction == 0:  # Horizontal
                    neighbor1 = padded_mag[i, j-1]  # Left
                    neighbor2 = padded_mag[i, j+1]  # Right
                elif direction == 45:  # Diagonal (NE-SW)
                    neighbor1 = padded_mag[i-1, j+1]  # Top-right
                    neighbor2 = padded_mag[i+1, j-1]  # Bottom-left
                elif direction == 90:  # Vertical
                    neighbor1 = padded_mag[i-1, j]  # Top
                    neighbor2 = padded_mag[i+1, j]  # Bottom
                else:  # direction == 135, Diagonal (NW-SE)
                    neighbor1 = padded_mag[i-1, j-1]  # Top-left
                    neighbor2 = padded_mag[i+1, j+1]  # Bottom-right
                
                # Keep pixel if it's a local maximum
                if current_mag >= neighbor1 and current_mag >= neighbor2:
                    suppressed[i-1, j-1] = current_mag
        
        return suppressed
    
    def hysteresis_threshold(self, nms_image: np.ndarray, 
                           low_threshold: int, high_threshold: int) -> np.ndarray:
        """
        Apply hysteresis thresholding for edge linking.
        
        Args:
            nms_image: Non-maximum suppressed image
            low_threshold: Low threshold value
            high_threshold: High threshold value
            
        Returns:
            np.ndarray: Final edge image
        """
        rows, cols = nms_image.shape
        
        # Initialize edge map
        edge_map = np.zeros_like(nms_image)
        
        # Strong edges (above high threshold)
        strong_edges = nms_image >= high_threshold
        edge_map[strong_edges] = 255
        
        # Weak edges (between low and high thresholds)
        weak_edges = (nms_image >= low_threshold) & (nms_image < high_threshold)
        
        # Connect weak edges to strong edges
        padded_edge = np.pad(edge_map, 1, mode='constant', constant_values=0)
        
        for i in range(rows):
            for j in range(cols):
                if weak_edges[i, j]:
                    # Check 8-connected neighborhood for strong edges
                    neighborhood = padded_edge[i:i+3, j:j+3]
                    if np.any(neighborhood == 255):
                        edge_map[i, j] = 255
        
        return edge_map
    
    def apply_canny(self, image: np.ndarray, 
                   low_threshold: int = 50, high_threshold: int = 150) -> np.ndarray:
        """
        Apply Canny edge detection.
        
        Args:
            image: Input grayscale image
            low_threshold: Low threshold for hysteresis
            high_threshold: High threshold for hysteresis
            
        Returns:
            np.ndarray: Canny edge image
        """
        # Get Sobel gradients
        _, gradient_mag, gradient_dir = self.apply_sobel(image, 0)
        
        # Apply non-maximum suppression
        nms_image = self.non_maximum_suppression(gradient_mag, gradient_dir)
        
        # Apply hysteresis thresholding
        canny_edges = self.hysteresis_threshold(nms_image, low_threshold, high_threshold)
        
        return canny_edges
    
    def apply_hybrid(self, image: np.ndarray, 
                    sobel_threshold: int = 50,
                    canny_low: int = 30, canny_high: int = 100) -> np.ndarray:
        """
        Apply hybrid Sobel-Canny edge detection.
        Uses Sobel for fast detection and Canny for refinement.
        
        Args:
            image: Input grayscale image
            sobel_threshold: Threshold for Sobel detection
            canny_low: Low threshold for Canny
            canny_high: High threshold for Canny
            
        Returns:
            np.ndarray: Hybrid edge image
        """
        # Get Sobel edges for fast detection
        sobel_edges, gradient_mag, gradient_dir = self.apply_sobel(image, sobel_threshold)
        
        # Apply Canny processing where Sobel detected edges
        nms_image = self.non_maximum_suppression(gradient_mag, gradient_dir)
        canny_edges = self.hysteresis_threshold(nms_image, canny_low, canny_high)
        
        # Hybrid decision: use Canny result where Sobel detected edges
        hybrid_edges = np.zeros_like(image)
        hybrid_edges[sobel_edges > 0] = canny_edges[sobel_edges > 0]
        
        return hybrid_edges
    
    def generate_test_image(self, pattern_type: str = "mixed") -> np.ndarray:
        """
        Generate test images with various edge patterns.
        
        Args:
            pattern_type: Type of pattern ("gradient", "checkerboard", "mixed")
            
        Returns:
            np.ndarray: Test image
        """
        image = np.zeros((self.image_height, self.image_width), dtype=np.uint8)
        
        if pattern_type == "gradient":
            # Horizontal and vertical gradients
            for i in range(self.image_height):
                for j in range(self.image_width):
                    if i < self.image_height // 2:
                        # Horizontal gradient
                        image[i, j] = int((j / self.image_width) * 255)
                    else:
                        # Vertical gradient
                        image[i, j] = int(((i - self.image_height//2) / (self.image_height//2)) * 255)
        
        elif pattern_type == "checkerboard":
            # Checkerboard pattern
            square_size = 16
            for i in range(self.image_height):
                for j in range(self.image_width):
                    if ((i // square_size) % 2) == ((j // square_size) % 2):
                        image[i, j] = 200
                    else:
                        image[i, j] = 50
        
        elif pattern_type == "mixed":
            # Mixed patterns in different regions
            h4 = self.image_height // 4
            w4 = self.image_width // 4
            
            # Horizontal gradient (top-left)
            for i in range(h4):
                for j in range(w4):
                    image[i, j] = int((j / w4) * 255)
            
            # Vertical gradient (top-right)
            for i in range(h4):
                for j in range(w4, 2*w4):
                    image[i, j] = int((i / h4) * 255)
            
            # Checkerboard (bottom-left)
            for i in range(h4, 2*h4):
                for j in range(w4):
                    if ((i // 8) % 2) == ((j // 8) % 2):
                        image[i, j] = 255
                    else:
                        image[i, j] = 0
            
            # Diagonal lines (bottom-right)
            for i in range(h4, 2*h4):
                for j in range(w4, 2*w4):
                    if (i + j) % 16 < 8:
                        image[i, j] = 255
                    else:
                        image[i, j] = 0
        
        return image
    
    def compare_algorithms(self, image: np.ndarray, 
                          sobel_th: int = 50, canny_low: int = 30, canny_high: int = 100):
        """
        Compare all three edge detection methods.
        
        Args:
            image: Input image
            sobel_th: Sobel threshold
            canny_low: Canny low threshold
            canny_high: Canny high threshold
        """
        # Apply all algorithms
        sobel_edges, _, _ = self.apply_sobel(image, sobel_th)
        canny_edges = self.apply_canny(image, canny_low, canny_high)
        hybrid_edges = self.apply_hybrid(image, sobel_th, canny_low, canny_high)
        
        # Display results
        fig, axes = plt.subplots(2, 2, figsize=(12, 10))
        
        axes[0, 0].imshow(image, cmap='gray')
        axes[0, 0].set_title('Original Image')
        axes[0, 0].axis('off')
        
        axes[0, 1].imshow(sobel_edges, cmap='gray')
        axes[0, 1].set_title(f'Sobel Edges (threshold={sobel_th})')
        axes[0, 1].axis('off')
        
        axes[1, 0].imshow(canny_edges, cmap='gray')
        axes[1, 0].set_title(f'Canny Edges (low={canny_low}, high={canny_high})')
        axes[1, 0].axis('off')
        
        axes[1, 1].imshow(hybrid_edges, cmap='gray')
        axes[1, 1].set_title('Hybrid Sobel-Canny Edges')
        axes[1, 1].axis('off')
        
        plt.tight_layout()
        plt.savefig('edge_detection_comparison.png', dpi=300, bbox_inches='tight')
        plt.show()
        
        return sobel_edges, canny_edges, hybrid_edges

def main():
    """Main function for testing the reference implementation."""
    parser = argparse.ArgumentParser(description='Edge Detection Reference Implementation')
    parser.add_argument('--input', '-i', type=str, help='Input image path')
    parser.add_argument('--width', '-w', type=int, default=640, help='Image width for test pattern')
    parser.add_argument('--height', '-h', type=int, default=480, help='Image height for test pattern')
    parser.add_argument('--pattern', '-p', type=str, default='mixed', 
                       choices=['gradient', 'checkerboard', 'mixed'],
                       help='Test pattern type')
    parser.add_argument('--sobel_th', type=int, default=50, help='Sobel threshold')
    parser.add_argument('--canny_low', type=int, default=30, help='Canny low threshold')
    parser.add_argument('--canny_high', type=int, default=100, help='Canny high threshold')
    
    args = parser.parse_args()
    
    # Initialize edge detection
    edge_detector = EdgeDetectionReference(args.width, args.height)
    
    # Load or generate test image
    if args.input:
        image = cv2.imread(args.input, cv2.IMREAD_GRAYSCALE)
        if image is None:
            print(f"Error: Could not load image {args.input}")
            return
        # Resize to target dimensions
        image = cv2.resize(image, (args.width, args.height))
    else:
        print(f"Generating {args.pattern} test pattern...")
        image = edge_detector.generate_test_image(args.pattern)
    
    # Compare algorithms
    print("Comparing edge detection algorithms...")
    sobel_edges, canny_edges, hybrid_edges = edge_detector.compare_algorithms(
        image, args.sobel_th, args.canny_low, args.canny_high)
    
    # Performance metrics
    print("\nPerformance Metrics:")
    print(f"Original image size: {image.shape}")
    print(f"Sobel edges detected: {np.sum(sobel_edges > 0)} pixels")
    print(f"Canny edges detected: {np.sum(canny_edges > 0)} pixels")
    print(f"Hybrid edges detected: {np.sum(hybrid_edges > 0)} pixels")
    
    # Save results
    cv2.imwrite('original_image.png', image)
    cv2.imwrite('sobel_edges.png', sobel_edges)
    cv2.imwrite('canny_edges.png', canny_edges)
    cv2.imwrite('hybrid_edges.png', hybrid_edges)
    print("\nResults saved to PNG files.")

if __name__ == "__main__":
    main()