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

endmodule