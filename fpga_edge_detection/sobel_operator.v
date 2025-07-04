//==============================================================================
// Sobel Operator Module for FPGA Edge Detection
// Calculates gradients in X and Y directions using 3x3 Sobel kernels
//==============================================================================

module sobel_operator #(
    parameter IMAGE_WIDTH = 640,
    parameter DATA_WIDTH = 8
)(
    input wire clk,
    input wire rst_n,
    input wire enable,
    
    // Input interface
    input wire [DATA_WIDTH-1:0] pixel_in,
    input wire pixel_valid,
    
    // Output interface
    output reg [DATA_WIDTH-1:0] gradient_x,
    output reg [DATA_WIDTH-1:0] gradient_y,
    output reg gradient_valid
);

    // Sobel kernels:
    // Gx (horizontal):     Gy (vertical):
    // [-1  0  1]          [-1 -2 -1]
    // [-2  0  2]          [ 0  0  0]
    // [-1  0  1]          [ 1  2  1]
    
    // Line buffers for 3x3 window
    reg [DATA_WIDTH-1:0] line_buffer_1 [0:IMAGE_WIDTH-1];
    reg [DATA_WIDTH-1:0] line_buffer_2 [0:IMAGE_WIDTH-1];
    
    // 3x3 window registers
    reg [DATA_WIDTH-1:0] window [0:2][0:2];
    
    // Address counters
    reg [15:0] x_counter;
    reg [15:0] y_counter;
    reg [15:0] buffer_addr;
    
    // Gradient calculation registers
    reg signed [DATA_WIDTH+3:0] gx_sum, gy_sum;
    reg signed [DATA_WIDTH+3:0] gx_abs, gy_abs;
    
    // Pipeline registers
    reg valid_reg_1, valid_reg_2, valid_reg_3;
    
    // Initialize line buffers
    integer i;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (i = 0; i < IMAGE_WIDTH; i = i + 1) begin
                line_buffer_1[i] <= {DATA_WIDTH{1'b0}};
                line_buffer_2[i] <= {DATA_WIDTH{1'b0}};
            end
        end
    end
    
    // Address generation
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            x_counter <= 16'h0000;
            y_counter <= 16'h0000;
            buffer_addr <= 16'h0000;
        end else if (enable && pixel_valid) begin
            if (x_counter < IMAGE_WIDTH - 1) begin
                x_counter <= x_counter + 1;
                buffer_addr <= buffer_addr + 1;
            end else begin
                x_counter <= 16'h0000;
                buffer_addr <= 16'h0000;
                if (y_counter < IMAGE_HEIGHT - 1)
                    y_counter <= y_counter + 1;
                else
                    y_counter <= 16'h0000;
            end
        end
    end
    
    // Shift line buffers and update window
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Initialize window
            window[0][0] <= {DATA_WIDTH{1'b0}};
            window[0][1] <= {DATA_WIDTH{1'b0}};
            window[0][2] <= {DATA_WIDTH{1'b0}};
            window[1][0] <= {DATA_WIDTH{1'b0}};
            window[1][1] <= {DATA_WIDTH{1'b0}};
            window[1][2] <= {DATA_WIDTH{1'b0}};
            window[2][0] <= {DATA_WIDTH{1'b0}};
            window[2][1] <= {DATA_WIDTH{1'b0}};
            window[2][2] <= {DATA_WIDTH{1'b0}};
        end else if (enable && pixel_valid) begin
            // Shift line buffers
            line_buffer_2[buffer_addr] <= line_buffer_1[buffer_addr];
            line_buffer_1[buffer_addr] <= pixel_in;
            
            // Update 3x3 window
            window[0][0] <= window[0][1];
            window[0][1] <= window[0][2];
            window[0][2] <= line_buffer_2[buffer_addr];
            
            window[1][0] <= window[1][1];
            window[1][1] <= window[1][2];
            window[1][2] <= line_buffer_1[buffer_addr];
            
            window[2][0] <= window[2][1];
            window[2][1] <= window[2][2];
            window[2][2] <= pixel_in;
        end
    end
    
    // Sobel convolution calculation
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            gx_sum <= {DATA_WIDTH+4{1'b0}};
            gy_sum <= {DATA_WIDTH+4{1'b0}};
            gx_abs <= {DATA_WIDTH+4{1'b0}};
            gy_abs <= {DATA_WIDTH+4{1'b0}};
        end else if (enable) begin
            // Sobel Gx calculation (horizontal gradient)
            gx_sum <= (-1 * $signed({1'b0, window[0][0]})) + (0 * $signed({1'b0, window[0][1]})) + (1 * $signed({1'b0, window[0][2]})) +
                      (-2 * $signed({1'b0, window[1][0]})) + (0 * $signed({1'b0, window[1][1]})) + (2 * $signed({1'b0, window[1][2]})) +
                      (-1 * $signed({1'b0, window[2][0]})) + (0 * $signed({1'b0, window[2][1]})) + (1 * $signed({1'b0, window[2][2]}));
            
            // Sobel Gy calculation (vertical gradient)
            gy_sum <= (-1 * $signed({1'b0, window[0][0]})) + (-2 * $signed({1'b0, window[0][1]})) + (-1 * $signed({1'b0, window[0][2]})) +
                      (0  * $signed({1'b0, window[1][0]})) + (0  * $signed({1'b0, window[1][1]})) + (0  * $signed({1'b0, window[1][2]})) +
                      (1  * $signed({1'b0, window[2][0]})) + (2  * $signed({1'b0, window[2][1]})) + (1  * $signed({1'b0, window[2][2]}));
            
            // Calculate absolute values
            gx_abs <= (gx_sum < 0) ? -gx_sum : gx_sum;
            gy_abs <= (gy_sum < 0) ? -gy_sum : gy_sum;
        end
    end
    
    // Pipeline delay management
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            valid_reg_1 <= 1'b0;
            valid_reg_2 <= 1'b0;
            valid_reg_3 <= 1'b0;
        end else begin
            valid_reg_1 <= enable && pixel_valid;
            valid_reg_2 <= valid_reg_1;
            valid_reg_3 <= valid_reg_2;
        end
    end
    
    // Output generation
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            gradient_x <= {DATA_WIDTH{1'b0}};
            gradient_y <= {DATA_WIDTH{1'b0}};
            gradient_valid <= 1'b0;
        end else if (enable && valid_reg_3 && (x_counter >= 2) && (y_counter >= 2)) begin
            // Clamp to DATA_WIDTH range and output
            gradient_x <= (gx_abs > {DATA_WIDTH{1'b1}}) ? {DATA_WIDTH{1'b1}} : gx_abs[DATA_WIDTH-1:0];
            gradient_y <= (gy_abs > {DATA_WIDTH{1'b1}}) ? {DATA_WIDTH{1'b1}} : gy_abs[DATA_WIDTH-1:0];
            gradient_valid <= 1'b1;
        end else begin
            gradient_x <= {DATA_WIDTH{1'b0}};
            gradient_y <= {DATA_WIDTH{1'b0}};
            gradient_valid <= 1'b0;
        end
    end

endmodule