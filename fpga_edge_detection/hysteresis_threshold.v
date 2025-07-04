//==============================================================================
// Hysteresis Thresholding Module for FPGA Edge Detection
// Final edge detection using dual thresholds and connectivity analysis
//==============================================================================

module hysteresis_threshold #(
    parameter IMAGE_WIDTH = 640,
    parameter IMAGE_HEIGHT = 480,
    parameter DATA_WIDTH = 8,
    parameter HIGH_THRESHOLD = 8'd100,
    parameter LOW_THRESHOLD = 8'd50
)(
    input wire clk,
    input wire rst_n,
    input wire enable,
    
    // Input interface
    input wire [DATA_WIDTH-1:0] magnitude_in,
    input wire magnitude_valid,
    
    // Output interface
    output reg [DATA_WIDTH-1:0] edge_out,
    output reg edge_valid
);

    // Threshold classification
    localparam [1:0] 
        WEAK_EDGE = 2'b01,
        STRONG_EDGE = 2'b10,
        NON_EDGE = 2'b00;
    
    // Line buffers for 3x3 window
    reg [1:0] edge_line_buffer_1 [0:IMAGE_WIDTH-1];
    reg [1:0] edge_line_buffer_2 [0:IMAGE_WIDTH-1];
    
    // 3x3 window for edge classification
    reg [1:0] edge_window [0:2][0:2];
    
    // Address counters
    reg [15:0] x_counter;
    reg [15:0] y_counter;
    reg [15:0] buffer_addr;
    
    // Pipeline registers
    reg valid_reg_1, valid_reg_2, valid_reg_3;
    
    // Edge classification
    reg [1:0] current_classification;
    reg [1:0] center_edge_type;
    reg has_strong_neighbor;
    reg [DATA_WIDTH-1:0] final_edge_value;
    
    // Initialize line buffers
    integer i;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (i = 0; i < IMAGE_WIDTH; i = i + 1) begin
                edge_line_buffer_1[i] <= NON_EDGE;
                edge_line_buffer_2[i] <= NON_EDGE;
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
    
    // Threshold classification stage
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            current_classification <= NON_EDGE;
        end else if (enable && magnitude_valid) begin
            if (magnitude_in >= HIGH_THRESHOLD)
                current_classification <= STRONG_EDGE;
            else if (magnitude_in >= LOW_THRESHOLD)
                current_classification <= WEAK_EDGE;
            else
                current_classification <= NON_EDGE;
        end
    end
    
    // Shift line buffers and update window
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Initialize edge window
            edge_window[0][0] <= NON_EDGE;
            edge_window[0][1] <= NON_EDGE;
            edge_window[0][2] <= NON_EDGE;
            edge_window[1][0] <= NON_EDGE;
            edge_window[1][1] <= NON_EDGE;
            edge_window[1][2] <= NON_EDGE;
            edge_window[2][0] <= NON_EDGE;
            edge_window[2][1] <= NON_EDGE;
            edge_window[2][2] <= NON_EDGE;
        end else if (enable && magnitude_valid) begin
            // Shift line buffers
            edge_line_buffer_2[buffer_addr] <= edge_line_buffer_1[buffer_addr];
            edge_line_buffer_1[buffer_addr] <= current_classification;
            
            // Update 3x3 window
            edge_window[0][0] <= edge_window[0][1];
            edge_window[0][1] <= edge_window[0][2];
            edge_window[0][2] <= edge_line_buffer_2[buffer_addr];
            
            edge_window[1][0] <= edge_window[1][1];
            edge_window[1][1] <= edge_window[1][2];
            edge_window[1][2] <= edge_line_buffer_1[buffer_addr];
            
            edge_window[2][0] <= edge_window[2][1];
            edge_window[2][1] <= edge_window[2][2];
            edge_window[2][2] <= current_classification;
        end
    end
    
    // Hysteresis connectivity analysis
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            center_edge_type <= NON_EDGE;
            has_strong_neighbor <= 1'b0;
            final_edge_value <= {DATA_WIDTH{1'b0}};
        end else if (enable) begin
            center_edge_type <= edge_window[1][1];
            
            // Check if any neighbor is a strong edge
            has_strong_neighbor <= (edge_window[0][0] == STRONG_EDGE) ||
                                  (edge_window[0][1] == STRONG_EDGE) ||
                                  (edge_window[0][2] == STRONG_EDGE) ||
                                  (edge_window[1][0] == STRONG_EDGE) ||
                                  (edge_window[1][2] == STRONG_EDGE) ||
                                  (edge_window[2][0] == STRONG_EDGE) ||
                                  (edge_window[2][1] == STRONG_EDGE) ||
                                  (edge_window[2][2] == STRONG_EDGE);
            
            // Final edge decision
            case (center_edge_type)
                STRONG_EDGE: begin
                    final_edge_value <= {DATA_WIDTH{1'b1}}; // Maximum value for strong edge
                end
                WEAK_EDGE: begin
                    if (has_strong_neighbor)
                        final_edge_value <= {DATA_WIDTH{1'b1}}; // Promote weak edge to strong
                    else
                        final_edge_value <= {DATA_WIDTH{1'b0}}; // Suppress weak edge
                end
                default: begin
                    final_edge_value <= {DATA_WIDTH{1'b0}}; // Non-edge
                end
            endcase
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
            edge_out <= {DATA_WIDTH{1'b0}};
            edge_valid <= 1'b0;
        end else if (enable && valid_reg_3 && (x_counter >= 2) && (y_counter >= 2)) begin
            edge_out <= final_edge_value;
            edge_valid <= 1'b1;
        end else begin
            edge_out <= {DATA_WIDTH{1'b0}};
            edge_valid <= 1'b0;
        end
    end

endmodule