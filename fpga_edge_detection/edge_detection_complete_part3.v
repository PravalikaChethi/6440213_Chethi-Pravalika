//==============================================================================
// GRADIENT MAGNITUDE MODULE
//==============================================================================
module gradient_magnitude #(
    parameter DATA_WIDTH = 8
)(
    input wire clk,
    input wire rst_n,
    input wire enable,
    input wire [DATA_WIDTH-1:0] gradient_x,
    input wire [DATA_WIDTH-1:0] gradient_y,
    input wire gradient_valid,
    output reg [DATA_WIDTH-1:0] magnitude,
    output reg [7:0] direction,
    output reg magnitude_valid
);

    reg [DATA_WIDTH-1:0] gx_reg, gy_reg;
    reg [DATA_WIDTH-1:0] magnitude_calc;
    reg [7:0] direction_calc;
    reg valid_reg_1, valid_reg_2, valid_reg_3, valid_reg_4;
    reg [DATA_WIDTH-1:0] gx_pipe_1, gy_pipe_1, gx_pipe_2, gy_pipe_2, gx_pipe_3, gy_pipe_3;
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            gx_reg <= {DATA_WIDTH{1'b0}}; gy_reg <= {DATA_WIDTH{1'b0}};
            valid_reg_1 <= 1'b0; gx_pipe_1 <= {DATA_WIDTH{1'b0}}; gy_pipe_1 <= {DATA_WIDTH{1'b0}};
        end else if (enable) begin
            gx_reg <= gradient_x; gy_reg <= gradient_y; valid_reg_1 <= gradient_valid;
            gx_pipe_1 <= gradient_x; gy_pipe_1 <= gradient_y;
        end
    end
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            valid_reg_2 <= 1'b0; gx_pipe_2 <= {DATA_WIDTH{1'b0}}; gy_pipe_2 <= {DATA_WIDTH{1'b0}};
        end else if (enable) begin
            valid_reg_2 <= valid_reg_1; gx_pipe_2 <= gx_pipe_1; gy_pipe_2 <= gy_pipe_1;
        end
    end
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            magnitude_calc <= {DATA_WIDTH{1'b0}}; valid_reg_3 <= 1'b0;
            gx_pipe_3 <= {DATA_WIDTH{1'b0}}; gy_pipe_3 <= {DATA_WIDTH{1'b0}};
        end else if (enable) begin
            magnitude_calc <= gx_pipe_2 + gy_pipe_2; // Manhattan distance
            valid_reg_3 <= valid_reg_2; gx_pipe_3 <= gx_pipe_2; gy_pipe_3 <= gy_pipe_2;
        end
    end
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            direction_calc <= 8'h00; valid_reg_4 <= 1'b0;
        end else if (enable) begin
            valid_reg_4 <= valid_reg_3;
            if (gx_pipe_3 == 0 && gy_pipe_3 == 0) direction_calc <= 8'h00;
            else if (gx_pipe_3 == 0) direction_calc <= (gy_pipe_3 > 0) ? 8'h5A : 8'hDA;
            else if (gy_pipe_3 == 0) direction_calc <= (gx_pipe_3 > 0) ? 8'h00 : 8'hB4;
            else begin
                if (gx_pipe_3 > 0 && gy_pipe_3 > 0) begin
                    direction_calc <= (gx_pipe_3 > gy_pipe_3) ? 8'h1C : 8'h3E;
                end else if (gx_pipe_3 < 0 && gy_pipe_3 > 0) begin
                    direction_calc <= ((-gx_pipe_3) > gy_pipe_3) ? 8'h98 : 8'h76;
                end else if (gx_pipe_3 < 0 && gy_pipe_3 < 0) begin
                    direction_calc <= ((-gx_pipe_3) > (-gy_pipe_3)) ? 8'hCE : 8'hF0;
                end else begin
                    direction_calc <= (gx_pipe_3 > (-gy_pipe_3)) ? 8'hE8 : 8'hC6;
                end
            end
        end
    end
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            magnitude <= {DATA_WIDTH{1'b0}}; direction <= 8'h00; magnitude_valid <= 1'b0;
        end else if (enable && valid_reg_4) begin
            magnitude <= (magnitude_calc > {DATA_WIDTH{1'b1}}) ? {DATA_WIDTH{1'b1}} : magnitude_calc;
            direction <= direction_calc; magnitude_valid <= 1'b1;
        end else begin
            magnitude <= {DATA_WIDTH{1'b0}}; direction <= 8'h00; magnitude_valid <= 1'b0;
        end
    end

endmodule

//==============================================================================
// NON-MAXIMUM SUPPRESSION MODULE
//==============================================================================
module nonmax_suppression #(
    parameter IMAGE_WIDTH = 640,
    parameter IMAGE_HEIGHT = 480,
    parameter DATA_WIDTH = 8
)(
    input wire clk,
    input wire rst_n,
    input wire enable,
    input wire [DATA_WIDTH-1:0] magnitude_in,
    input wire [7:0] direction_in,
    input wire magnitude_valid,
    output reg [DATA_WIDTH-1:0] magnitude_out,
    output reg magnitude_out_valid
);

    reg [DATA_WIDTH-1:0] mag_line_buffer_1 [0:IMAGE_WIDTH-1];
    reg [DATA_WIDTH-1:0] mag_line_buffer_2 [0:IMAGE_WIDTH-1];
    reg [7:0] dir_line_buffer_1 [0:IMAGE_WIDTH-1];
    reg [7:0] dir_line_buffer_2 [0:IMAGE_WIDTH-1];
    reg [DATA_WIDTH-1:0] mag_window [0:2][0:2];
    reg [7:0] dir_window [0:2][0:2];
    reg [15:0] x_counter, y_counter, buffer_addr;
    reg valid_reg_1, valid_reg_2, valid_reg_3;
    reg [DATA_WIDTH-1:0] neighbor_1, neighbor_2, center_magnitude;
    reg [7:0] center_direction;
    reg is_local_maximum;
    
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
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            x_counter <= 16'h0000; y_counter <= 16'h0000; buffer_addr <= 16'h0000;
        end else if (enable && magnitude_valid) begin
            if (x_counter < IMAGE_WIDTH - 1) begin
                x_counter <= x_counter + 1; buffer_addr <= buffer_addr + 1;
            end else begin
                x_counter <= 16'h0000; buffer_addr <= 16'h0000;
                if (y_counter < IMAGE_HEIGHT - 1) y_counter <= y_counter + 1;
                else y_counter <= 16'h0000;
            end
        end
    end
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            mag_window[0][0] <= {DATA_WIDTH{1'b0}}; mag_window[0][1] <= {DATA_WIDTH{1'b0}}; mag_window[0][2] <= {DATA_WIDTH{1'b0}};
            mag_window[1][0] <= {DATA_WIDTH{1'b0}}; mag_window[1][1] <= {DATA_WIDTH{1'b0}}; mag_window[1][2] <= {DATA_WIDTH{1'b0}};
            mag_window[2][0] <= {DATA_WIDTH{1'b0}}; mag_window[2][1] <= {DATA_WIDTH{1'b0}}; mag_window[2][2] <= {DATA_WIDTH{1'b0}};
            dir_window[0][0] <= 8'h00; dir_window[0][1] <= 8'h00; dir_window[0][2] <= 8'h00;
            dir_window[1][0] <= 8'h00; dir_window[1][1] <= 8'h00; dir_window[1][2] <= 8'h00;
            dir_window[2][0] <= 8'h00; dir_window[2][1] <= 8'h00; dir_window[2][2] <= 8'h00;
        end else if (enable && magnitude_valid) begin
            mag_line_buffer_2[buffer_addr] <= mag_line_buffer_1[buffer_addr];
            mag_line_buffer_1[buffer_addr] <= magnitude_in;
            dir_line_buffer_2[buffer_addr] <= dir_line_buffer_1[buffer_addr];
            dir_line_buffer_1[buffer_addr] <= direction_in;
            
            mag_window[0][0] <= mag_window[0][1]; mag_window[0][1] <= mag_window[0][2]; mag_window[0][2] <= mag_line_buffer_2[buffer_addr];
            mag_window[1][0] <= mag_window[1][1]; mag_window[1][1] <= mag_window[1][2]; mag_window[1][2] <= mag_line_buffer_1[buffer_addr];
            mag_window[2][0] <= mag_window[2][1]; mag_window[2][1] <= mag_window[2][2]; mag_window[2][2] <= magnitude_in;
            
            dir_window[0][0] <= dir_window[0][1]; dir_window[0][1] <= dir_window[0][2]; dir_window[0][2] <= dir_line_buffer_2[buffer_addr];
            dir_window[1][0] <= dir_window[1][1]; dir_window[1][1] <= dir_window[1][2]; dir_window[1][2] <= dir_line_buffer_1[buffer_addr];
            dir_window[2][0] <= dir_window[2][1]; dir_window[2][1] <= dir_window[2][2]; dir_window[2][2] <= direction_in;
        end
    end
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            neighbor_1 <= {DATA_WIDTH{1'b0}}; neighbor_2 <= {DATA_WIDTH{1'b0}};
            center_magnitude <= {DATA_WIDTH{1'b0}}; center_direction <= 8'h00; is_local_maximum <= 1'b0;
        end else if (enable) begin
            center_magnitude <= mag_window[1][1]; center_direction <= dir_window[1][1];
            case (center_direction[7:5])
                3'b000: begin neighbor_1 <= mag_window[1][0]; neighbor_2 <= mag_window[1][2]; end
                3'b001: begin neighbor_1 <= mag_window[0][0]; neighbor_2 <= mag_window[2][2]; end
                3'b010: begin neighbor_1 <= mag_window[0][1]; neighbor_2 <= mag_window[2][1]; end
                3'b011: begin neighbor_1 <= mag_window[0][2]; neighbor_2 <= mag_window[2][0]; end
                3'b100: begin neighbor_1 <= mag_window[1][0]; neighbor_2 <= mag_window[1][2]; end
                3'b101: begin neighbor_1 <= mag_window[0][0]; neighbor_2 <= mag_window[2][2]; end
                3'b110: begin neighbor_1 <= mag_window[0][1]; neighbor_2 <= mag_window[2][1]; end
                3'b111: begin neighbor_1 <= mag_window[0][2]; neighbor_2 <= mag_window[2][0]; end
                default: begin neighbor_1 <= {DATA_WIDTH{1'b0}}; neighbor_2 <= {DATA_WIDTH{1'b0}}; end
            endcase
            is_local_maximum <= (center_magnitude >= neighbor_1) && (center_magnitude >= neighbor_2);
        end
    end
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            valid_reg_1 <= 1'b0; valid_reg_2 <= 1'b0; valid_reg_3 <= 1'b0;
        end else begin
            valid_reg_1 <= enable && magnitude_valid;
            valid_reg_2 <= valid_reg_1; valid_reg_3 <= valid_reg_2;
        end
    end
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            magnitude_out <= {DATA_WIDTH{1'b0}}; magnitude_out_valid <= 1'b0;
        end else if (enable && valid_reg_3 && (x_counter >= 2) && (y_counter >= 2)) begin
            magnitude_out <= is_local_maximum ? center_magnitude : {DATA_WIDTH{1'b0}};
            magnitude_out_valid <= 1'b1;
        end else begin
            magnitude_out <= {DATA_WIDTH{1'b0}}; magnitude_out_valid <= 1'b0;
        end
    end

endmodule

//==============================================================================
// HYSTERESIS THRESHOLD MODULE
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
    input wire [DATA_WIDTH-1:0] magnitude_in,
    input wire magnitude_valid,
    output reg [DATA_WIDTH-1:0] edge_out,
    output reg edge_valid
);

    localparam [1:0] WEAK_EDGE = 2'b01, STRONG_EDGE = 2'b10, NON_EDGE = 2'b00;
    
    reg [1:0] edge_line_buffer_1 [0:IMAGE_WIDTH-1];
    reg [1:0] edge_line_buffer_2 [0:IMAGE_WIDTH-1];
    reg [1:0] edge_window [0:2][0:2];
    reg [15:0] x_counter, y_counter, buffer_addr;
    reg valid_reg_1, valid_reg_2, valid_reg_3;
    reg [1:0] current_classification, center_edge_type;
    reg has_strong_neighbor;
    reg [DATA_WIDTH-1:0] final_edge_value;
    
    integer i;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (i = 0; i < IMAGE_WIDTH; i = i + 1) begin
                edge_line_buffer_1[i] <= NON_EDGE;
                edge_line_buffer_2[i] <= NON_EDGE;
            end
        end
    end
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            x_counter <= 16'h0000; y_counter <= 16'h0000; buffer_addr <= 16'h0000;
        end else if (enable && magnitude_valid) begin
            if (x_counter < IMAGE_WIDTH - 1) begin
                x_counter <= x_counter + 1; buffer_addr <= buffer_addr + 1;
            end else begin
                x_counter <= 16'h0000; buffer_addr <= 16'h0000;
                if (y_counter < IMAGE_HEIGHT - 1) y_counter <= y_counter + 1;
                else y_counter <= 16'h0000;
            end
        end
    end
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) current_classification <= NON_EDGE;
        else if (enable && magnitude_valid) begin
            if (magnitude_in >= HIGH_THRESHOLD) current_classification <= STRONG_EDGE;
            else if (magnitude_in >= LOW_THRESHOLD) current_classification <= WEAK_EDGE;
            else current_classification <= NON_EDGE;
        end
    end
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            edge_window[0][0] <= NON_EDGE; edge_window[0][1] <= NON_EDGE; edge_window[0][2] <= NON_EDGE;
            edge_window[1][0] <= NON_EDGE; edge_window[1][1] <= NON_EDGE; edge_window[1][2] <= NON_EDGE;
            edge_window[2][0] <= NON_EDGE; edge_window[2][1] <= NON_EDGE; edge_window[2][2] <= NON_EDGE;
        end else if (enable && magnitude_valid) begin
            edge_line_buffer_2[buffer_addr] <= edge_line_buffer_1[buffer_addr];
            edge_line_buffer_1[buffer_addr] <= current_classification;
            edge_window[0][0] <= edge_window[0][1]; edge_window[0][1] <= edge_window[0][2]; edge_window[0][2] <= edge_line_buffer_2[buffer_addr];
            edge_window[1][0] <= edge_window[1][1]; edge_window[1][1] <= edge_window[1][2]; edge_window[1][2] <= edge_line_buffer_1[buffer_addr];
            edge_window[2][0] <= edge_window[2][1]; edge_window[2][1] <= edge_window[2][2]; edge_window[2][2] <= current_classification;
        end
    end
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            center_edge_type <= NON_EDGE; has_strong_neighbor <= 1'b0; final_edge_value <= {DATA_WIDTH{1'b0}};
        end else if (enable) begin
            center_edge_type <= edge_window[1][1];
            has_strong_neighbor <= (edge_window[0][0] == STRONG_EDGE) || (edge_window[0][1] == STRONG_EDGE) ||
                                  (edge_window[0][2] == STRONG_EDGE) || (edge_window[1][0] == STRONG_EDGE) ||
                                  (edge_window[1][2] == STRONG_EDGE) || (edge_window[2][0] == STRONG_EDGE) ||
                                  (edge_window[2][1] == STRONG_EDGE) || (edge_window[2][2] == STRONG_EDGE);
            case (center_edge_type)
                STRONG_EDGE: final_edge_value <= {DATA_WIDTH{1'b1}};
                WEAK_EDGE: final_edge_value <= has_strong_neighbor ? {DATA_WIDTH{1'b1}} : {DATA_WIDTH{1'b0}};
                default: final_edge_value <= {DATA_WIDTH{1'b0}};
            endcase
        end
    end
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            valid_reg_1 <= 1'b0; valid_reg_2 <= 1'b0; valid_reg_3 <= 1'b0;
        end else begin
            valid_reg_1 <= enable && magnitude_valid;
            valid_reg_2 <= valid_reg_1; valid_reg_3 <= valid_reg_2;
        end
    end
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            edge_out <= {DATA_WIDTH{1'b0}}; edge_valid <= 1'b0;
        end else if (enable && valid_reg_3 && (x_counter >= 2) && (y_counter >= 2)) begin
            edge_out <= final_edge_value; edge_valid <= 1'b1;
        end else begin
            edge_out <= {DATA_WIDTH{1'b0}}; edge_valid <= 1'b0;
        end
    end

endmodule