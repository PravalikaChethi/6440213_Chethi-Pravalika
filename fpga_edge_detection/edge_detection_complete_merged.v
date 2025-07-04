//==============================================================================
// COMPLETE FPGA-Based Real-Time Edge Detection System
// Hybrid Sobel-Canny Algorithm Implementation
// All 8 modules merged into single file for easy deployment
// Target: Artix-7 XC7A100T-CSG324-1, Vivado 2024.1
//==============================================================================

//==============================================================================
// COMPLETE FPGA-Based Real-Time Edge Detection System
// Hybrid Sobel-Canny Algorithm Implementation
// All modules merged into single file for easy deployment
//==============================================================================

//==============================================================================
// TOP-LEVEL MODULE
//==============================================================================
module edge_detection_top #(
    parameter IMAGE_WIDTH = 640,
    parameter IMAGE_HEIGHT = 480,
    parameter DATA_WIDTH = 8,
    parameter ADDR_WIDTH = 19
)(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [DATA_WIDTH-1:0] pixel_in,
    input wire pixel_valid,
    output wire ready,
    output wire [DATA_WIDTH-1:0] edge_out,
    output wire edge_valid,
    output wire processing_done,
    output wire [ADDR_WIDTH-1:0] mem_addr,
    output wire [DATA_WIDTH-1:0] mem_data_out,
    input wire [DATA_WIDTH-1:0] mem_data_in,
    output wire mem_we,
    output wire mem_oe,
    output wire [3:0] current_stage,
    output wire [15:0] processed_pixels
);

    wire [DATA_WIDTH-1:0] gaussian_out;
    wire gaussian_valid;
    wire [DATA_WIDTH-1:0] sobel_gx, sobel_gy;
    wire sobel_valid;
    wire [DATA_WIDTH-1:0] magnitude_out;
    wire [7:0] direction_out;
    wire magnitude_valid;
    wire [DATA_WIDTH-1:0] nonmax_out;
    wire nonmax_valid;
    wire [DATA_WIDTH-1:0] hysteresis_out;
    wire hysteresis_valid;
    wire [3:0] stage_select;
    wire enable_gaussian, enable_sobel, enable_magnitude;
    wire enable_nonmax, enable_hysteresis;
    wire buffer_ready;
    
    reg [15:0] pixel_counter;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            pixel_counter <= 16'h0000;
        else if (pixel_valid)
            pixel_counter <= pixel_counter + 1;
        else if (processing_done)
            pixel_counter <= 16'h0000;
    end
    assign processed_pixels = pixel_counter;

    control_unit #(.IMAGE_WIDTH(IMAGE_WIDTH), .IMAGE_HEIGHT(IMAGE_HEIGHT)) ctrl_unit (
        .clk(clk), .rst_n(rst_n), .start(start), .pixel_valid(pixel_valid),
        .ready(ready), .current_stage(current_stage), .stage_select(stage_select),
        .enable_gaussian(enable_gaussian), .enable_sobel(enable_sobel),
        .enable_magnitude(enable_magnitude), .enable_nonmax(enable_nonmax),
        .enable_hysteresis(enable_hysteresis), .processing_done(processing_done)
    );

    image_buffer #(.IMAGE_WIDTH(IMAGE_WIDTH), .IMAGE_HEIGHT(IMAGE_HEIGHT), 
                   .DATA_WIDTH(DATA_WIDTH), .ADDR_WIDTH(ADDR_WIDTH)) img_buffer (
        .clk(clk), .rst_n(rst_n), .pixel_in(pixel_in), .pixel_valid(pixel_valid),
        .mem_addr(mem_addr), .mem_data_out(mem_data_out), .mem_data_in(mem_data_in),
        .mem_we(mem_we), .mem_oe(mem_oe), .buffer_ready(buffer_ready)
    );

    gaussian_filter #(.IMAGE_WIDTH(IMAGE_WIDTH), .IMAGE_HEIGHT(IMAGE_HEIGHT), 
                      .DATA_WIDTH(DATA_WIDTH)) gauss_filter (
        .clk(clk), .rst_n(rst_n), .enable(enable_gaussian),
        .pixel_in(pixel_in), .pixel_valid(pixel_valid),
        .pixel_out(gaussian_out), .pixel_out_valid(gaussian_valid)
    );

    sobel_operator #(.IMAGE_WIDTH(IMAGE_WIDTH), .IMAGE_HEIGHT(IMAGE_HEIGHT), 
                     .DATA_WIDTH(DATA_WIDTH)) sobel_op (
        .clk(clk), .rst_n(rst_n), .enable(enable_sobel),
        .pixel_in(gaussian_out), .pixel_valid(gaussian_valid),
        .gradient_x(sobel_gx), .gradient_y(sobel_gy), .gradient_valid(sobel_valid)
    );

    gradient_magnitude #(.DATA_WIDTH(DATA_WIDTH)) grad_mag (
        .clk(clk), .rst_n(rst_n), .enable(enable_magnitude),
        .gradient_x(sobel_gx), .gradient_y(sobel_gy), .gradient_valid(sobel_valid),
        .magnitude(magnitude_out), .direction(direction_out), .magnitude_valid(magnitude_valid)
    );

    nonmax_suppression #(.IMAGE_WIDTH(IMAGE_WIDTH), .IMAGE_HEIGHT(IMAGE_HEIGHT), 
                         .DATA_WIDTH(DATA_WIDTH)) nonmax_supp (
        .clk(clk), .rst_n(rst_n), .enable(enable_nonmax),
        .magnitude_in(magnitude_out), .direction_in(direction_out),
        .magnitude_valid(magnitude_valid), .magnitude_out(nonmax_out),
        .magnitude_out_valid(nonmax_valid)
    );

    hysteresis_threshold #(.IMAGE_WIDTH(IMAGE_WIDTH), .IMAGE_HEIGHT(IMAGE_HEIGHT), 
                           .DATA_WIDTH(DATA_WIDTH)) hysteresis_thresh (
        .clk(clk), .rst_n(rst_n), .enable(enable_hysteresis),
        .magnitude_in(nonmax_out), .magnitude_valid(nonmax_valid),
        .edge_out(hysteresis_out), .edge_valid(hysteresis_valid)
    );

    assign edge_out = hysteresis_out;
    assign edge_valid = hysteresis_valid;

endmodule

//==============================================================================
// CONTROL UNIT MODULE
//==============================================================================
module control_unit #(
    parameter IMAGE_WIDTH = 640,
    parameter IMAGE_HEIGHT = 480
)(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire pixel_valid,
    output reg ready,
    output reg [3:0] current_stage,
    output reg [3:0] stage_select,
    output reg enable_gaussian,
    output reg enable_sobel,
    output reg enable_magnitude,
    output reg enable_nonmax,
    output reg enable_hysteresis,
    output reg processing_done
);

    localparam [3:0] IDLE = 4'b0000, INIT = 4'b0001, GAUSSIAN = 4'b0010,
                     SOBEL = 4'b0011, MAGNITUDE = 4'b0100, NONMAX = 4'b0101,
                     HYSTERESIS = 4'b0110, DONE = 4'b0111;

    reg [3:0] state, next_state;
    reg [19:0] pixel_count;
    reg [19:0] total_pixels;
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            total_pixels <= IMAGE_WIDTH * IMAGE_HEIGHT;
        else
            total_pixels <= IMAGE_WIDTH * IMAGE_HEIGHT;
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) state <= IDLE;
        else state <= next_state;
    end

    always @(*) begin
        case (state)
            IDLE: next_state = start ? INIT : IDLE;
            INIT: next_state = GAUSSIAN;
            GAUSSIAN: next_state = (pixel_count >= 9) ? SOBEL : GAUSSIAN;
            SOBEL: next_state = (pixel_count >= 18) ? MAGNITUDE : SOBEL;
            MAGNITUDE: next_state = (pixel_count >= 25) ? NONMAX : MAGNITUDE;
            NONMAX: next_state = (pixel_count >= 32) ? HYSTERESIS : NONMAX;
            HYSTERESIS: next_state = (pixel_count >= total_pixels + 40) ? DONE : HYSTERESIS;
            DONE: next_state = start ? DONE : IDLE;
            default: next_state = IDLE;
        endcase
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) pixel_count <= 20'h00000;
        else if (state == IDLE) pixel_count <= 20'h00000;
        else if (pixel_valid) pixel_count <= pixel_count + 1;
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            ready <= 1'b1; current_stage <= 4'h0; stage_select <= 4'h0;
            enable_gaussian <= 1'b0; enable_sobel <= 1'b0; enable_magnitude <= 1'b0;
            enable_nonmax <= 1'b0; enable_hysteresis <= 1'b0; processing_done <= 1'b0;
        end else begin
            case (state)
                IDLE: begin
                    ready <= 1'b1; current_stage <= 4'h0; stage_select <= 4'h0;
                    enable_gaussian <= 1'b0; enable_sobel <= 1'b0; enable_magnitude <= 1'b0;
                    enable_nonmax <= 1'b0; enable_hysteresis <= 1'b0; processing_done <= 1'b0;
                end
                INIT: begin
                    ready <= 1'b0; current_stage <= 4'h1; stage_select <= 4'h1;
                    enable_gaussian <= 1'b1; enable_sobel <= 1'b0; enable_magnitude <= 1'b0;
                    enable_nonmax <= 1'b0; enable_hysteresis <= 1'b0; processing_done <= 1'b0;
                end
                GAUSSIAN: begin
                    ready <= 1'b0; current_stage <= 4'h2; stage_select <= 4'h2;
                    enable_gaussian <= 1'b1; enable_sobel <= 1'b0; enable_magnitude <= 1'b0;
                    enable_nonmax <= 1'b0; enable_hysteresis <= 1'b0; processing_done <= 1'b0;
                end
                SOBEL: begin
                    ready <= 1'b0; current_stage <= 4'h3; stage_select <= 4'h3;
                    enable_gaussian <= 1'b1; enable_sobel <= 1'b1; enable_magnitude <= 1'b0;
                    enable_nonmax <= 1'b0; enable_hysteresis <= 1'b0; processing_done <= 1'b0;
                end
                MAGNITUDE: begin
                    ready <= 1'b0; current_stage <= 4'h4; stage_select <= 4'h4;
                    enable_gaussian <= 1'b1; enable_sobel <= 1'b1; enable_magnitude <= 1'b1;
                    enable_nonmax <= 1'b0; enable_hysteresis <= 1'b0; processing_done <= 1'b0;
                end
                NONMAX: begin
                    ready <= 1'b0; current_stage <= 4'h5; stage_select <= 4'h5;
                    enable_gaussian <= 1'b1; enable_sobel <= 1'b1; enable_magnitude <= 1'b1;
                    enable_nonmax <= 1'b1; enable_hysteresis <= 1'b0; processing_done <= 1'b0;
                end
                HYSTERESIS: begin
                    ready <= 1'b0; current_stage <= 4'h6; stage_select <= 4'h6;
                    enable_gaussian <= 1'b1; enable_sobel <= 1'b1; enable_magnitude <= 1'b1;
                    enable_nonmax <= 1'b1; enable_hysteresis <= 1'b1; processing_done <= 1'b0;
                end
                DONE: begin
                    ready <= 1'b1; current_stage <= 4'h7; stage_select <= 4'h7;
                    enable_gaussian <= 1'b0; enable_sobel <= 1'b0; enable_magnitude <= 1'b0;
                    enable_nonmax <= 1'b0; enable_hysteresis <= 1'b0; processing_done <= 1'b1;
                end
            endcase
        end
    end

endmodule

//==============================================================================
// IMAGE BUFFER MODULE
//==============================================================================
module image_buffer #(
    parameter IMAGE_WIDTH = 640,
    parameter IMAGE_HEIGHT = 480,
    parameter DATA_WIDTH = 8,
    parameter ADDR_WIDTH = 19
)(
    input wire clk,
    input wire rst_n,
    input wire [DATA_WIDTH-1:0] pixel_in,
    input wire pixel_valid,
    output reg [ADDR_WIDTH-1:0] mem_addr,
    output reg [DATA_WIDTH-1:0] mem_data_out,
    input wire [DATA_WIDTH-1:0] mem_data_in,
    output reg mem_we,
    output reg mem_oe,
    output reg buffer_ready
);

    reg [ADDR_WIDTH-1:0] write_addr, read_addr, max_addr;
    reg writing_enabled, reading_enabled;
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) max_addr <= IMAGE_WIDTH * IMAGE_HEIGHT - 1;
        else max_addr <= IMAGE_WIDTH * IMAGE_HEIGHT - 1;
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) write_addr <= {ADDR_WIDTH{1'b0}};
        else if (pixel_valid && writing_enabled) begin
            if (write_addr < max_addr) write_addr <= write_addr + 1;
            else write_addr <= {ADDR_WIDTH{1'b0}};
        end
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) read_addr <= {ADDR_WIDTH{1'b0}};
        else if (reading_enabled) begin
            if (read_addr < max_addr) read_addr <= read_addr + 1;
            else read_addr <= {ADDR_WIDTH{1'b0}};
        end
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) mem_we <= 1'b0;
        else mem_we <= (pixel_valid && writing_enabled);
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) mem_oe <= 1'b0;
        else mem_oe <= reading_enabled;
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) mem_addr <= {ADDR_WIDTH{1'b0}};
        else if (writing_enabled) mem_addr <= write_addr;
        else if (reading_enabled) mem_addr <= read_addr;
        else mem_addr <= {ADDR_WIDTH{1'b0}};
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) mem_data_out <= {DATA_WIDTH{1'b0}};
        else if (pixel_valid && writing_enabled) mem_data_out <= pixel_in;
        else mem_data_out <= {DATA_WIDTH{1'b0}};
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            writing_enabled <= 1'b1; reading_enabled <= 1'b0; buffer_ready <= 1'b0;
        end else begin
            if (pixel_valid) writing_enabled <= 1'b1;
            if (write_addr >= 3*IMAGE_WIDTH + 3) reading_enabled <= 1'b1;
            buffer_ready <= (write_addr >= 3*IMAGE_WIDTH + 3);
        end
    end

endmodule//==============================================================================
// GAUSSIAN FILTER MODULE
//==============================================================================
module gaussian_filter #(
    parameter IMAGE_WIDTH = 640,
    parameter IMAGE_HEIGHT = 480,
    parameter DATA_WIDTH = 8
)(
    input wire clk,
    input wire rst_n,
    input wire enable,
    input wire [DATA_WIDTH-1:0] pixel_in,
    input wire pixel_valid,
    output reg [DATA_WIDTH-1:0] pixel_out,
    output reg pixel_out_valid
);

    reg [DATA_WIDTH-1:0] line_buffer_1 [0:IMAGE_WIDTH-1];
    reg [DATA_WIDTH-1:0] line_buffer_2 [0:IMAGE_WIDTH-1];
    reg [DATA_WIDTH-1:0] window [0:2][0:2];
    reg [15:0] x_counter, y_counter, buffer_addr;
    reg valid_reg_1, valid_reg_2, valid_reg_3;
    reg [DATA_WIDTH+7:0] sum;
    reg [DATA_WIDTH+3:0] weighted_sum;
    
    integer i;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (i = 0; i < IMAGE_WIDTH; i = i + 1) begin
                line_buffer_1[i] <= {DATA_WIDTH{1'b0}};
                line_buffer_2[i] <= {DATA_WIDTH{1'b0}};
            end
        end
    end
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            x_counter <= 16'h0000; y_counter <= 16'h0000; buffer_addr <= 16'h0000;
        end else if (enable && pixel_valid) begin
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
            window[0][0] <= {DATA_WIDTH{1'b0}}; window[0][1] <= {DATA_WIDTH{1'b0}}; window[0][2] <= {DATA_WIDTH{1'b0}};
            window[1][0] <= {DATA_WIDTH{1'b0}}; window[1][1] <= {DATA_WIDTH{1'b0}}; window[1][2] <= {DATA_WIDTH{1'b0}};
            window[2][0] <= {DATA_WIDTH{1'b0}}; window[2][1] <= {DATA_WIDTH{1'b0}}; window[2][2] <= {DATA_WIDTH{1'b0}};
        end else if (enable && pixel_valid) begin
            line_buffer_2[buffer_addr] <= line_buffer_1[buffer_addr];
            line_buffer_1[buffer_addr] <= pixel_in;
            window[0][0] <= window[0][1]; window[0][1] <= window[0][2]; window[0][2] <= line_buffer_2[buffer_addr];
            window[1][0] <= window[1][1]; window[1][1] <= window[1][2]; window[1][2] <= line_buffer_1[buffer_addr];
            window[2][0] <= window[2][1]; window[2][1] <= window[2][2]; window[2][2] <= pixel_in;
        end
    end
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            sum <= {DATA_WIDTH+8{1'b0}}; weighted_sum <= {DATA_WIDTH+4{1'b0}};
        end else if (enable) begin
            sum <= (window[0][0] * 1) + (window[0][1] * 2) + (window[0][2] * 1) +
                   (window[1][0] * 2) + (window[1][1] * 4) + (window[1][2] * 2) +
                   (window[2][0] * 1) + (window[2][1] * 2) + (window[2][2] * 1);
            weighted_sum <= sum >> 4;
        end
    end
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            valid_reg_1 <= 1'b0; valid_reg_2 <= 1'b0; valid_reg_3 <= 1'b0;
        end else begin
            valid_reg_1 <= enable && pixel_valid;
            valid_reg_2 <= valid_reg_1; valid_reg_3 <= valid_reg_2;
        end
    end
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            pixel_out <= {DATA_WIDTH{1'b0}}; pixel_out_valid <= 1'b0;
        end else if (enable && valid_reg_3 && (x_counter >= 2) && (y_counter >= 2)) begin
            pixel_out <= weighted_sum[DATA_WIDTH-1:0]; pixel_out_valid <= 1'b1;
        end else begin
            pixel_out <= {DATA_WIDTH{1'b0}}; pixel_out_valid <= 1'b0;
        end
    end

endmodule

//==============================================================================
// SOBEL OPERATOR MODULE
//==============================================================================
module sobel_operator #(
    parameter IMAGE_WIDTH = 640,
    parameter IMAGE_HEIGHT = 480,
    parameter DATA_WIDTH = 8
)(
    input wire clk,
    input wire rst_n,
    input wire enable,
    input wire [DATA_WIDTH-1:0] pixel_in,
    input wire pixel_valid,
    output reg [DATA_WIDTH-1:0] gradient_x,
    output reg [DATA_WIDTH-1:0] gradient_y,
    output reg gradient_valid
);

    reg [DATA_WIDTH-1:0] line_buffer_1 [0:IMAGE_WIDTH-1];
    reg [DATA_WIDTH-1:0] line_buffer_2 [0:IMAGE_WIDTH-1];
    reg [DATA_WIDTH-1:0] window [0:2][0:2];
    reg [15:0] x_counter, y_counter, buffer_addr;
    reg signed [DATA_WIDTH+3:0] gx_sum, gy_sum, gx_abs, gy_abs;
    reg valid_reg_1, valid_reg_2, valid_reg_3;
    
    integer i;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (i = 0; i < IMAGE_WIDTH; i = i + 1) begin
                line_buffer_1[i] <= {DATA_WIDTH{1'b0}};
                line_buffer_2[i] <= {DATA_WIDTH{1'b0}};
            end
        end
    end
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            x_counter <= 16'h0000; y_counter <= 16'h0000; buffer_addr <= 16'h0000;
        end else if (enable && pixel_valid) begin
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
            window[0][0] <= {DATA_WIDTH{1'b0}}; window[0][1] <= {DATA_WIDTH{1'b0}}; window[0][2] <= {DATA_WIDTH{1'b0}};
            window[1][0] <= {DATA_WIDTH{1'b0}}; window[1][1] <= {DATA_WIDTH{1'b0}}; window[1][2] <= {DATA_WIDTH{1'b0}};
            window[2][0] <= {DATA_WIDTH{1'b0}}; window[2][1] <= {DATA_WIDTH{1'b0}}; window[2][2] <= {DATA_WIDTH{1'b0}};
        end else if (enable && pixel_valid) begin
            line_buffer_2[buffer_addr] <= line_buffer_1[buffer_addr];
            line_buffer_1[buffer_addr] <= pixel_in;
            window[0][0] <= window[0][1]; window[0][1] <= window[0][2]; window[0][2] <= line_buffer_2[buffer_addr];
            window[1][0] <= window[1][1]; window[1][1] <= window[1][2]; window[1][2] <= line_buffer_1[buffer_addr];
            window[2][0] <= window[2][1]; window[2][1] <= window[2][2]; window[2][2] <= pixel_in;
        end
    end
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            gx_sum <= {DATA_WIDTH+4{1'b0}}; gy_sum <= {DATA_WIDTH+4{1'b0}};
            gx_abs <= {DATA_WIDTH+4{1'b0}}; gy_abs <= {DATA_WIDTH+4{1'b0}};
        end else if (enable) begin
            gx_sum <= (-1 * $signed({1'b0, window[0][0]})) + (1 * $signed({1'b0, window[0][2]})) +
                      (-2 * $signed({1'b0, window[1][0]})) + (2 * $signed({1'b0, window[1][2]})) +
                      (-1 * $signed({1'b0, window[2][0]})) + (1 * $signed({1'b0, window[2][2]}));
            
            gy_sum <= (-1 * $signed({1'b0, window[0][0]})) + (-2 * $signed({1'b0, window[0][1]})) + (-1 * $signed({1'b0, window[0][2]})) +
                      (1  * $signed({1'b0, window[2][0]})) + (2  * $signed({1'b0, window[2][1]})) + (1  * $signed({1'b0, window[2][2]}));
            
            gx_abs <= (gx_sum < 0) ? -gx_sum : gx_sum;
            gy_abs <= (gy_sum < 0) ? -gy_sum : gy_sum;
        end
    end
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            valid_reg_1 <= 1'b0; valid_reg_2 <= 1'b0; valid_reg_3 <= 1'b0;
        end else begin
            valid_reg_1 <= enable && pixel_valid;
            valid_reg_2 <= valid_reg_1; valid_reg_3 <= valid_reg_2;
        end
    end
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            gradient_x <= {DATA_WIDTH{1'b0}}; gradient_y <= {DATA_WIDTH{1'b0}}; gradient_valid <= 1'b0;
        end else if (enable && valid_reg_3 && (x_counter >= 2) && (y_counter >= 2)) begin
            gradient_x <= (gx_abs > {DATA_WIDTH{1'b1}}) ? {DATA_WIDTH{1'b1}} : gx_abs[DATA_WIDTH-1:0];
            gradient_y <= (gy_abs > {DATA_WIDTH{1'b1}}) ? {DATA_WIDTH{1'b1}} : gy_abs[DATA_WIDTH-1:0];
            gradient_valid <= 1'b1;
        end else begin
            gradient_x <= {DATA_WIDTH{1'b0}}; gradient_y <= {DATA_WIDTH{1'b0}}; gradient_valid <= 1'b0;
        end
    end

endmodule//==============================================================================
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