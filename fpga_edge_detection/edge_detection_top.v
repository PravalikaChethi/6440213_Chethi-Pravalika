//==============================================================================
// FPGA-Based Real-Time Edge Detection Using Hybrid Sobel-Canny Algorithm
// Top-Level Module
// Research Project Implementation
//==============================================================================

module edge_detection_top #(
    parameter IMAGE_WIDTH = 640,
    parameter IMAGE_HEIGHT = 480,
    parameter DATA_WIDTH = 8,
    parameter ADDR_WIDTH = 19  // log2(640*480)
)(
    // Clock and Reset
    input wire clk,
    input wire rst_n,
    
    // Input Interface
    input wire start,
    input wire [DATA_WIDTH-1:0] pixel_in,
    input wire pixel_valid,
    output wire ready,
    
    // Output Interface
    output wire [DATA_WIDTH-1:0] edge_out,
    output wire edge_valid,
    output wire processing_done,
    
    // Memory Interface (for external RAM)
    output wire [ADDR_WIDTH-1:0] mem_addr,
    output wire [DATA_WIDTH-1:0] mem_data_out,
    input wire [DATA_WIDTH-1:0] mem_data_in,
    output wire mem_we,
    output wire mem_oe,
    
    // Control and Status
    output wire [3:0] current_stage,
    output wire [15:0] processed_pixels
);

    // Internal signals
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
    
    // Control signals
    wire [3:0] stage_select;
    wire enable_gaussian, enable_sobel, enable_magnitude;
    wire enable_nonmax, enable_hysteresis;
    wire buffer_ready;
    
    // Pipeline stages counter
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

    // Control Unit - manages the entire pipeline
    control_unit #(
        .IMAGE_WIDTH(IMAGE_WIDTH),
        .IMAGE_HEIGHT(IMAGE_HEIGHT)
    ) ctrl_unit (
        .clk(clk),
        .rst_n(rst_n),
        .start(start),
        .pixel_valid(pixel_valid),
        .ready(ready),
        .current_stage(current_stage),
        .stage_select(stage_select),
        .enable_gaussian(enable_gaussian),
        .enable_sobel(enable_sobel),
        .enable_magnitude(enable_magnitude),
        .enable_nonmax(enable_nonmax),
        .enable_hysteresis(enable_hysteresis),
        .processing_done(processing_done)
    );

    // Image Buffer - manages input/output data flow
    image_buffer #(
        .IMAGE_WIDTH(IMAGE_WIDTH),
        .IMAGE_HEIGHT(IMAGE_HEIGHT),
        .DATA_WIDTH(DATA_WIDTH),
        .ADDR_WIDTH(ADDR_WIDTH)
    ) img_buffer (
        .clk(clk),
        .rst_n(rst_n),
        .pixel_in(pixel_in),
        .pixel_valid(pixel_valid),
        .mem_addr(mem_addr),
        .mem_data_out(mem_data_out),
        .mem_data_in(mem_data_in),
        .mem_we(mem_we),
        .mem_oe(mem_oe),
        .buffer_ready(buffer_ready)
    );

    // Gaussian Filter - noise reduction preprocessing
    gaussian_filter #(
        .IMAGE_WIDTH(IMAGE_WIDTH),
        .DATA_WIDTH(DATA_WIDTH)
    ) gauss_filter (
        .clk(clk),
        .rst_n(rst_n),
        .enable(enable_gaussian),
        .pixel_in(pixel_in),
        .pixel_valid(pixel_valid),
        .pixel_out(gaussian_out),
        .pixel_out_valid(gaussian_valid)
    );

    // Sobel Operator - gradient calculation
    sobel_operator #(
        .IMAGE_WIDTH(IMAGE_WIDTH),
        .DATA_WIDTH(DATA_WIDTH)
    ) sobel_op (
        .clk(clk),
        .rst_n(rst_n),
        .enable(enable_sobel),
        .pixel_in(gaussian_out),
        .pixel_valid(gaussian_valid),
        .gradient_x(sobel_gx),
        .gradient_y(sobel_gy),
        .gradient_valid(sobel_valid)
    );

    // Gradient Magnitude and Direction Calculation
    gradient_magnitude #(
        .DATA_WIDTH(DATA_WIDTH)
    ) grad_mag (
        .clk(clk),
        .rst_n(rst_n),
        .enable(enable_magnitude),
        .gradient_x(sobel_gx),
        .gradient_y(sobel_gy),
        .gradient_valid(sobel_valid),
        .magnitude(magnitude_out),
        .direction(direction_out),
        .magnitude_valid(magnitude_valid)
    );

    // Non-Maximum Suppression
    nonmax_suppression #(
        .IMAGE_WIDTH(IMAGE_WIDTH),
        .DATA_WIDTH(DATA_WIDTH)
    ) nonmax_supp (
        .clk(clk),
        .rst_n(rst_n),
        .enable(enable_nonmax),
        .magnitude_in(magnitude_out),
        .direction_in(direction_out),
        .magnitude_valid(magnitude_valid),
        .magnitude_out(nonmax_out),
        .magnitude_out_valid(nonmax_valid)
    );

    // Hysteresis Thresholding - final edge detection
    hysteresis_threshold #(
        .IMAGE_WIDTH(IMAGE_WIDTH),
        .DATA_WIDTH(DATA_WIDTH)
    ) hysteresis_thresh (
        .clk(clk),
        .rst_n(rst_n),
        .enable(enable_hysteresis),
        .magnitude_in(nonmax_out),
        .magnitude_valid(nonmax_valid),
        .edge_out(hysteresis_out),
        .edge_valid(hysteresis_valid)
    );

    // Output assignment
    assign edge_out = hysteresis_out;
    assign edge_valid = hysteresis_valid;

endmodule