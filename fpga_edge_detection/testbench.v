//==============================================================================
// Testbench for FPGA-Based Real-Time Edge Detection System
// Tests the complete hybrid Sobel-Canny algorithm implementation
//==============================================================================

`timescale 1ns / 1ps

module testbench();

    // Parameters
    parameter IMAGE_WIDTH = 64;   // Reduced for simulation
    parameter IMAGE_HEIGHT = 48;  // Reduced for simulation
    parameter DATA_WIDTH = 8;
    parameter ADDR_WIDTH = 12;    // log2(64*48)
    parameter CLK_PERIOD = 10;    // 100MHz clock

    // Test signals
    reg clk;
    reg rst_n;
    reg start;
    reg [DATA_WIDTH-1:0] pixel_in;
    reg pixel_valid;
    
    wire ready;
    wire [DATA_WIDTH-1:0] edge_out;
    wire edge_valid;
    wire processing_done;
    wire [ADDR_WIDTH-1:0] mem_addr;
    wire [DATA_WIDTH-1:0] mem_data_out;
    reg [DATA_WIDTH-1:0] mem_data_in;
    wire mem_we;
    wire mem_oe;
    wire [3:0] current_stage;
    wire [15:0] processed_pixels;

    // Memory model
    reg [DATA_WIDTH-1:0] memory [0:(1<<ADDR_WIDTH)-1];
    
    // Test data
    reg [DATA_WIDTH-1:0] test_image [0:(IMAGE_WIDTH*IMAGE_HEIGHT)-1];
    integer pixel_count;
    integer output_count;
    
    // File handles for I/O
    integer input_file, output_file;
    integer i, j, k;

    // Clock generation
    initial begin
        clk = 0;
        forever #(CLK_PERIOD/2) clk = ~clk;
    end

    // Device Under Test (DUT)
    edge_detection_top #(
        .IMAGE_WIDTH(IMAGE_WIDTH),
        .IMAGE_HEIGHT(IMAGE_HEIGHT),
        .DATA_WIDTH(DATA_WIDTH),
        .ADDR_WIDTH(ADDR_WIDTH)
    ) dut (
        .clk(clk),
        .rst_n(rst_n),
        .start(start),
        .pixel_in(pixel_in),
        .pixel_valid(pixel_valid),
        .ready(ready),
        .edge_out(edge_out),
        .edge_valid(edge_valid),
        .processing_done(processing_done),
        .mem_addr(mem_addr),
        .mem_data_out(mem_data_out),
        .mem_data_in(mem_data_in),
        .mem_we(mem_we),
        .mem_oe(mem_oe),
        .current_stage(current_stage),
        .processed_pixels(processed_pixels)
    );

    // Memory model behavior
    always @(posedge clk) begin
        if (mem_we && !mem_oe) begin
            memory[mem_addr] <= mem_data_out;
        end
        if (mem_oe && !mem_we) begin
            mem_data_in <= memory[mem_addr];
        end
    end

    // Initialize test image (create a simple test pattern)
    task generate_test_image;
        integer x, y, idx;
        begin
            // Generate a test image with geometric shapes for edge detection
            for (y = 0; y < IMAGE_HEIGHT; y = y + 1) begin
                for (x = 0; x < IMAGE_WIDTH; x = x + 1) begin
                    idx = y * IMAGE_WIDTH + x;
                    
                    // Create a rectangular pattern
                    if ((x >= 10 && x <= 30 && y >= 10 && y <= 25) ||
                        (x >= 40 && x <= 55 && y >= 20 && y <= 35)) begin
                        test_image[idx] = 8'd255; // White rectangles
                    end else if (x == 32 && y >= 5 && y <= 40) begin
                        test_image[idx] = 8'd128; // Vertical line
                    end else if (y == 15 && x >= 5 && x <= 60) begin
                        test_image[idx] = 8'd192; // Horizontal line
                    end else begin
                        test_image[idx] = 8'd0;   // Black background
                    end
                end
            end
            $display("Test image generated with geometric patterns");
        end
    endtask

    // Feed pixels to the edge detection system
    task feed_image;
        begin
            pixel_count = 0;
            pixel_valid = 0;
            pixel_in = 0;
            
            // Wait for ready signal
            wait (ready);
            
            // Start processing
            start = 1;
            #(CLK_PERIOD);
            start = 0;
            
            // Feed all pixels
            for (i = 0; i < IMAGE_WIDTH * IMAGE_HEIGHT; i = i + 1) begin
                @(posedge clk);
                pixel_in = test_image[i];
                pixel_valid = 1;
                pixel_count = pixel_count + 1;
                
                // Add some random gaps to test pipeline robustness
                if (i % 17 == 0) begin
                    @(posedge clk);
                    pixel_valid = 0;
                    @(posedge clk);
                end
            end
            
            @(posedge clk);
            pixel_valid = 0;
            pixel_in = 0;
            
            $display("Finished feeding %d pixels", pixel_count);
        end
    endtask

    // Collect output data
    task collect_output;
        reg [DATA_WIDTH-1:0] output_image [0:(IMAGE_WIDTH*IMAGE_HEIGHT)-1];
        begin
            output_count = 0;
            
            // Collect edge detection results
            while (!processing_done || edge_valid) begin
                @(posedge clk);
                if (edge_valid) begin
                    output_image[output_count] = edge_out;
                    output_count = output_count + 1;
                    $display("Output pixel %d: %d", output_count, edge_out);
                end
            end
            
            $display("Collected %d output pixels", output_count);
            
            // Save results to file (optional)
            output_file = $fopen("edge_detection_output.txt", "w");
            if (output_file) begin
                for (i = 0; i < output_count; i = i + 1) begin
                    $fwrite(output_file, "%d\n", output_image[i]);
                end
                $fclose(output_file);
                $display("Output saved to edge_detection_output.txt");
            end
        end
    endtask

    // Monitor pipeline stages
    task monitor_pipeline;
        begin
            forever begin
                @(posedge clk);
                case (current_stage)
                    4'h0: $display("Stage: IDLE");
                    4'h1: $display("Stage: INIT");
                    4'h2: $display("Stage: GAUSSIAN");
                    4'h3: $display("Stage: SOBEL");
                    4'h4: $display("Stage: MAGNITUDE");
                    4'h5: $display("Stage: NONMAX");
                    4'h6: $display("Stage: HYSTERESIS");
                    4'h7: $display("Stage: DONE");
                    default: $display("Stage: UNKNOWN");
                endcase
                
                if (processing_done) begin
                    $display("Processing completed!");
                    break;
                end
            end
        end
    endtask

    // Performance monitoring
    reg [31:0] start_time, end_time;
    task performance_monitor;
        begin
            start_time = $time;
            wait (processing_done);
            end_time = $time;
            
            $display("Performance Results:");
            $display("Total processing time: %d ns", end_time - start_time);
            $display("Clock cycles: %d", (end_time - start_time) / CLK_PERIOD);
            $display("Pixels processed: %d", processed_pixels);
            $display("Throughput: %f pixels/cycle", 
                     $itor(processed_pixels) / ($itor(end_time - start_time) / CLK_PERIOD));
        end
    endtask

    // Main test sequence
    initial begin
        $display("Starting FPGA Edge Detection Testbench");
        
        // Initialize signals
        rst_n = 0;
        start = 0;
        pixel_in = 0;
        pixel_valid = 0;
        mem_data_in = 0;
        
        // Initialize memory
        for (i = 0; i < (1<<ADDR_WIDTH); i = i + 1) begin
            memory[i] = 0;
        end
        
        // Reset sequence
        #(CLK_PERIOD * 5);
        rst_n = 1;
        #(CLK_PERIOD * 2);
        
        // Generate test data
        generate_test_image();
        
        // Start concurrent tasks
        fork
            feed_image();
            collect_output();
            monitor_pipeline();
            performance_monitor();
        join
        
        // Wait for completion
        wait (processing_done);
        #(CLK_PERIOD * 10);
        
        // Final checks
        if (output_count > 0) begin
            $display("SUCCESS: Edge detection completed successfully!");
            $display("Input pixels: %d", IMAGE_WIDTH * IMAGE_HEIGHT);
            $display("Output pixels: %d", output_count);
        end else begin
            $display("ERROR: No output pixels generated!");
        end
        
        $display("Testbench completed");
        $finish;
    end

    // Timeout watchdog
    initial begin
        #(CLK_PERIOD * 100000); // 100k clock cycles timeout
        $display("ERROR: Testbench timeout!");
        $finish;
    end

    // VCD dump for waveform analysis
    initial begin
        $dumpfile("edge_detection_tb.vcd");
        $dumpvars(0, testbench);
    end

endmodule