//==============================================================================
// Gradient Magnitude and Direction Module for FPGA Edge Detection
// Calculates magnitude and direction from Sobel gradients using CORDIC algorithm
//==============================================================================

module gradient_magnitude #(
    parameter DATA_WIDTH = 8
)(
    input wire clk,
    input wire rst_n,
    input wire enable,
    
    // Input interface
    input wire [DATA_WIDTH-1:0] gradient_x,
    input wire [DATA_WIDTH-1:0] gradient_y,
    input wire gradient_valid,
    
    // Output interface
    output reg [DATA_WIDTH-1:0] magnitude,
    output reg [7:0] direction,
    output reg magnitude_valid
);

    // Internal registers for magnitude calculation
    reg [DATA_WIDTH-1:0] gx_reg, gy_reg;
    reg [DATA_WIDTH*2-1:0] gx_squared, gy_squared;
    reg [DATA_WIDTH*2:0] sum_squares;
    reg [DATA_WIDTH-1:0] magnitude_calc;
    
    // Direction calculation (simplified to 8 directions: 0, 45, 90, 135, 180, 225, 270, 315)
    reg [7:0] direction_calc;
    
    // Pipeline registers
    reg valid_reg_1, valid_reg_2, valid_reg_3, valid_reg_4;
    reg [DATA_WIDTH-1:0] gx_pipe_1, gy_pipe_1;
    reg [DATA_WIDTH-1:0] gx_pipe_2, gy_pipe_2;
    reg [DATA_WIDTH-1:0] gx_pipe_3, gy_pipe_3;
    
    // Square root approximation lookup table (for 8-bit values)
    reg [DATA_WIDTH-1:0] sqrt_lut [0:255];
    
    // Initialize square root lookup table
    integer i;
    initial begin
        for (i = 0; i < 256; i = i + 1) begin
            sqrt_lut[i] = $sqrt(i);
        end
    end
    
    // Pipeline stage 1: Register inputs
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            gx_reg <= {DATA_WIDTH{1'b0}};
            gy_reg <= {DATA_WIDTH{1'b0}};
            valid_reg_1 <= 1'b0;
            gx_pipe_1 <= {DATA_WIDTH{1'b0}};
            gy_pipe_1 <= {DATA_WIDTH{1'b0}};
        end else if (enable) begin
            gx_reg <= gradient_x;
            gy_reg <= gradient_y;
            valid_reg_1 <= gradient_valid;
            gx_pipe_1 <= gradient_x;
            gy_pipe_1 <= gradient_y;
        end
    end
    
    // Pipeline stage 2: Calculate squares
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            gx_squared <= {DATA_WIDTH*2{1'b0}};
            gy_squared <= {DATA_WIDTH*2{1'b0}};
            valid_reg_2 <= 1'b0;
            gx_pipe_2 <= {DATA_WIDTH{1'b0}};
            gy_pipe_2 <= {DATA_WIDTH{1'b0}};
        end else if (enable) begin
            gx_squared <= gx_reg * gx_reg;
            gy_squared <= gy_reg * gy_reg;
            valid_reg_2 <= valid_reg_1;
            gx_pipe_2 <= gx_pipe_1;
            gy_pipe_2 <= gy_pipe_1;
        end
    end
    
    // Pipeline stage 3: Sum squares and calculate magnitude
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            sum_squares <= {DATA_WIDTH*2+1{1'b0}};
            magnitude_calc <= {DATA_WIDTH{1'b0}};
            valid_reg_3 <= 1'b0;
            gx_pipe_3 <= {DATA_WIDTH{1'b0}};
            gy_pipe_3 <= {DATA_WIDTH{1'b0}};
        end else if (enable) begin
            sum_squares <= gx_squared + gy_squared;
            // Approximate magnitude using Manhattan distance (|Gx| + |Gy|) for speed
            // More accurate would be sqrt(Gx^2 + Gy^2), but this is faster in hardware
            magnitude_calc <= gx_pipe_2 + gy_pipe_2;
            valid_reg_3 <= valid_reg_2;
            gx_pipe_3 <= gx_pipe_2;
            gy_pipe_3 <= gy_pipe_2;
        end
    end
    
    // Direction calculation using arctangent approximation
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            direction_calc <= 8'h00;
            valid_reg_4 <= 1'b0;
        end else if (enable) begin
            valid_reg_4 <= valid_reg_3;
            
            // Simplified 8-direction calculation
            if (gx_pipe_3 == 0 && gy_pipe_3 == 0) begin
                direction_calc <= 8'h00; // No gradient
            end else if (gx_pipe_3 == 0) begin
                direction_calc <= (gy_pipe_3 > 0) ? 8'h5A : 8'hDA; // 90° or 270°
            end else if (gy_pipe_3 == 0) begin
                direction_calc <= (gx_pipe_3 > 0) ? 8'h00 : 8'hB4; // 0° or 180°
            end else begin
                // Calculate ratio and determine octant
                if (gx_pipe_3 > 0 && gy_pipe_3 > 0) begin
                    // First quadrant
                    if (gx_pipe_3 > gy_pipe_3)
                        direction_calc <= 8'h1C; // ~22.5° (0-45°)
                    else
                        direction_calc <= 8'h3E; // ~67.5° (45-90°)
                end else if (gx_pipe_3 < 0 && gy_pipe_3 > 0) begin
                    // Second quadrant
                    if ((-gx_pipe_3) > gy_pipe_3)
                        direction_calc <= 8'h98; // ~135° (135-180°)
                    else
                        direction_calc <= 8'h76; // ~112.5° (90-135°)
                end else if (gx_pipe_3 < 0 && gy_pipe_3 < 0) begin
                    // Third quadrant
                    if ((-gx_pipe_3) > (-gy_pipe_3))
                        direction_calc <= 8'hCE; // ~202.5° (180-225°)
                    else
                        direction_calc <= 8'hF0; // ~247.5° (225-270°)
                end else begin
                    // Fourth quadrant (gx > 0, gy < 0)
                    if (gx_pipe_3 > (-gy_pipe_3))
                        direction_calc <= 8'hE8; // ~337.5° (315-360°)
                    else
                        direction_calc <= 8'hC6; // ~292.5° (270-315°)
                end
            end
        end
    end
    
    // Final output stage
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            magnitude <= {DATA_WIDTH{1'b0}};
            direction <= 8'h00;
            magnitude_valid <= 1'b0;
        end else if (enable && valid_reg_4) begin
            // Clamp magnitude to maximum value
            if (magnitude_calc > {DATA_WIDTH{1'b1}})
                magnitude <= {DATA_WIDTH{1'b1}};
            else
                magnitude <= magnitude_calc;
            
            direction <= direction_calc;
            magnitude_valid <= 1'b1;
        end else begin
            magnitude <= {DATA_WIDTH{1'b0}};
            direction <= 8'h00;
            magnitude_valid <= 1'b0;
        end
    end

endmodule