//==============================================================================
// Non-Maximum Suppression Module for FPGA Edge Detection
// Thins edges to single pixel width based on gradient direction
//==============================================================================

module nonmax_suppression #(
    parameter IMAGE_WIDTH = 640,
    parameter DATA_WIDTH = 8
)(
    input wire clk,
    input wire rst_n,
    input wire enable,
    
    // Input interface
    input wire [DATA_WIDTH-1:0] magnitude_in,
    input wire [7:0] direction_in,
    input wire magnitude_valid,
    
    // Output interface
    output reg [DATA_WIDTH-1:0] magnitude_out,
    output reg magnitude_out_valid
);

    // Line buffers for 3x3 window (magnitude and direction)
    reg [DATA_WIDTH-1:0] mag_line_buffer_1 [0:IMAGE_WIDTH-1];
    reg [DATA_WIDTH-1:0] mag_line_buffer_2 [0:IMAGE_WIDTH-1];
    reg [7:0] dir_line_buffer_1 [0:IMAGE_WIDTH-1];
    reg [7:0] dir_line_buffer_2 [0:IMAGE_WIDTH-1];
    
    // 3x3 window registers for magnitude
    reg [DATA_WIDTH-1:0] mag_window [0:2][0:2];
    reg [7:0] dir_window [0:2][0:2];
    
    // Address counters
    reg [15:0] x_counter;
    reg [15:0] y_counter;
    reg [15:0] buffer_addr;
    
    // Pipeline registers
    reg valid_reg_1, valid_reg_2, valid_reg_3;
    
    // Direction analysis
    reg [DATA_WIDTH-1:0] neighbor_1, neighbor_2;
    reg [DATA_WIDTH-1:0] center_magnitude;
    reg [7:0] center_direction;
    reg is_local_maximum;
    
    // Initialize line buffers
    integer i;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (i = 0; i < IMAGE_WIDTH; i = i + 1) begin
                mag_line_buffer_1[i] <= {DATA_WIDTH{1'b0}};
                mag_line_buffer_2[i] <= {DATA_WIDTH{1'b0}};
                dir_line_buffer_1[i] <= 8'h00;
                dir_line_buffer_2[i] <= 8'h00;
            end
        end
    end
    
    // Address generation
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            x_counter <= 16'h0000;
            y_counter <= 16'h0000;
            buffer_addr <= 16'h0000;
        end else if (enable && magnitude_valid) begin
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
    
    // Shift line buffers and update windows
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Initialize magnitude window
            mag_window[0][0] <= {DATA_WIDTH{1'b0}};
            mag_window[0][1] <= {DATA_WIDTH{1'b0}};
            mag_window[0][2] <= {DATA_WIDTH{1'b0}};
            mag_window[1][0] <= {DATA_WIDTH{1'b0}};
            mag_window[1][1] <= {DATA_WIDTH{1'b0}};
            mag_window[1][2] <= {DATA_WIDTH{1'b0}};
            mag_window[2][0] <= {DATA_WIDTH{1'b0}};
            mag_window[2][1] <= {DATA_WIDTH{1'b0}};
            mag_window[2][2] <= {DATA_WIDTH{1'b0}};
            
            // Initialize direction window
            dir_window[0][0] <= 8'h00;
            dir_window[0][1] <= 8'h00;
            dir_window[0][2] <= 8'h00;
            dir_window[1][0] <= 8'h00;
            dir_window[1][1] <= 8'h00;
            dir_window[1][2] <= 8'h00;
            dir_window[2][0] <= 8'h00;
            dir_window[2][1] <= 8'h00;
            dir_window[2][2] <= 8'h00;
        end else if (enable && magnitude_valid) begin
            // Shift magnitude line buffers
            mag_line_buffer_2[buffer_addr] <= mag_line_buffer_1[buffer_addr];
            mag_line_buffer_1[buffer_addr] <= magnitude_in;
            
            // Shift direction line buffers
            dir_line_buffer_2[buffer_addr] <= dir_line_buffer_1[buffer_addr];
            dir_line_buffer_1[buffer_addr] <= direction_in;
            
            // Update 3x3 magnitude window
            mag_window[0][0] <= mag_window[0][1];
            mag_window[0][1] <= mag_window[0][2];
            mag_window[0][2] <= mag_line_buffer_2[buffer_addr];
            
            mag_window[1][0] <= mag_window[1][1];
            mag_window[1][1] <= mag_window[1][2];
            mag_window[1][2] <= mag_line_buffer_1[buffer_addr];
            
            mag_window[2][0] <= mag_window[2][1];
            mag_window[2][1] <= mag_window[2][2];
            mag_window[2][2] <= magnitude_in;
            
            // Update 3x3 direction window
            dir_window[0][0] <= dir_window[0][1];
            dir_window[0][1] <= dir_window[0][2];
            dir_window[0][2] <= dir_line_buffer_2[buffer_addr];
            
            dir_window[1][0] <= dir_window[1][1];
            dir_window[1][1] <= dir_window[1][2];
            dir_window[1][2] <= dir_line_buffer_1[buffer_addr];
            
            dir_window[2][0] <= dir_window[2][1];
            dir_window[2][1] <= dir_window[2][2];
            dir_window[2][2] <= direction_in;
        end
    end
    
    // Non-maximum suppression logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            neighbor_1 <= {DATA_WIDTH{1'b0}};
            neighbor_2 <= {DATA_WIDTH{1'b0}};
            center_magnitude <= {DATA_WIDTH{1'b0}};
            center_direction <= 8'h00;
            is_local_maximum <= 1'b0;
        end else if (enable) begin
            center_magnitude <= mag_window[1][1];
            center_direction <= dir_window[1][1];
            
            // Determine neighbors based on gradient direction
            case (center_direction[7:5]) // Use upper 3 bits for 8 directions
                3'b000: begin // 0° - horizontal
                    neighbor_1 <= mag_window[1][0]; // Left
                    neighbor_2 <= mag_window[1][2]; // Right
                end
                3'b001: begin // 45° - diagonal
                    neighbor_1 <= mag_window[0][0]; // Top-left
                    neighbor_2 <= mag_window[2][2]; // Bottom-right
                end
                3'b010: begin // 90° - vertical
                    neighbor_1 <= mag_window[0][1]; // Top
                    neighbor_2 <= mag_window[2][1]; // Bottom
                end
                3'b011: begin // 135° - diagonal
                    neighbor_1 <= mag_window[0][2]; // Top-right
                    neighbor_2 <= mag_window[2][0]; // Bottom-left
                end
                3'b100: begin // 180° - horizontal
                    neighbor_1 <= mag_window[1][0]; // Left
                    neighbor_2 <= mag_window[1][2]; // Right
                end
                3'b101: begin // 225° - diagonal
                    neighbor_1 <= mag_window[0][0]; // Top-left
                    neighbor_2 <= mag_window[2][2]; // Bottom-right
                end
                3'b110: begin // 270° - vertical
                    neighbor_1 <= mag_window[0][1]; // Top
                    neighbor_2 <= mag_window[2][1]; // Bottom
                end
                3'b111: begin // 315° - diagonal
                    neighbor_1 <= mag_window[0][2]; // Top-right
                    neighbor_2 <= mag_window[2][0]; // Bottom-left
                end
                default: begin
                    neighbor_1 <= {DATA_WIDTH{1'b0}};
                    neighbor_2 <= {DATA_WIDTH{1'b0}};
                end
            endcase
            
            // Check if center pixel is local maximum
            is_local_maximum <= (center_magnitude >= neighbor_1) && (center_magnitude >= neighbor_2);
        end
    end
    
    // Pipeline delay management
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            valid_reg_1 <= 1'b0;
            valid_reg_2 <= 1'b0;
            valid_reg_3 <= 1'b0;
        end else begin
            valid_reg_1 <= enable && magnitude_valid;
            valid_reg_2 <= valid_reg_1;
            valid_reg_3 <= valid_reg_2;
        end
    end
    
    // Output generation
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            magnitude_out <= {DATA_WIDTH{1'b0}};
            magnitude_out_valid <= 1'b0;
        end else if (enable && valid_reg_3 && (x_counter >= 2) && (y_counter >= 2)) begin
            if (is_local_maximum)
                magnitude_out <= center_magnitude;
            else
                magnitude_out <= {DATA_WIDTH{1'b0}};
            magnitude_out_valid <= 1'b1;
        end else begin
            magnitude_out <= {DATA_WIDTH{1'b0}};
            magnitude_out_valid <= 1'b0;
        end
    end

endmodule