//==============================================================================
// Image Buffer Module for FPGA Edge Detection
// Manages memory interface and provides data buffering for image processing
//==============================================================================

module image_buffer #(
    parameter IMAGE_WIDTH = 640,
    parameter IMAGE_HEIGHT = 480,
    parameter DATA_WIDTH = 8,
    parameter ADDR_WIDTH = 19
)(
    input wire clk,
    input wire rst_n,
    
    // Input interface
    input wire [DATA_WIDTH-1:0] pixel_in,
    input wire pixel_valid,
    
    // Memory interface
    output reg [ADDR_WIDTH-1:0] mem_addr,
    output reg [DATA_WIDTH-1:0] mem_data_out,
    input wire [DATA_WIDTH-1:0] mem_data_in,
    output reg mem_we,
    output reg mem_oe,
    
    // Control signals
    output reg buffer_ready
);

    // Internal registers
    reg [ADDR_WIDTH-1:0] write_addr;
    reg [ADDR_WIDTH-1:0] read_addr;
    reg [ADDR_WIDTH-1:0] max_addr;
    reg writing_enabled;
    reg reading_enabled;
    
    // Calculate maximum address
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            max_addr <= IMAGE_WIDTH * IMAGE_HEIGHT - 1;
        else
            max_addr <= IMAGE_WIDTH * IMAGE_HEIGHT - 1;
    end

    // Write address generation
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            write_addr <= {ADDR_WIDTH{1'b0}};
        else if (pixel_valid && writing_enabled) begin
            if (write_addr < max_addr)
                write_addr <= write_addr + 1;
            else
                write_addr <= {ADDR_WIDTH{1'b0}};
        end
    end

    // Read address generation
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            read_addr <= {ADDR_WIDTH{1'b0}};
        else if (reading_enabled) begin
            if (read_addr < max_addr)
                read_addr <= read_addr + 1;
            else
                read_addr <= {ADDR_WIDTH{1'b0}};
        end
    end

    // Memory write enable
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            mem_we <= 1'b0;
        else if (pixel_valid && writing_enabled)
            mem_we <= 1'b1;
        else
            mem_we <= 1'b0;
    end

    // Memory output enable
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            mem_oe <= 1'b0;
        else if (reading_enabled)
            mem_oe <= 1'b1;
        else
            mem_oe <= 1'b0;
    end

    // Memory address multiplexing
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            mem_addr <= {ADDR_WIDTH{1'b0}};
        else if (writing_enabled)
            mem_addr <= write_addr;
        else if (reading_enabled)
            mem_addr <= read_addr;
        else
            mem_addr <= {ADDR_WIDTH{1'b0}};
    end

    // Memory data output
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            mem_data_out <= {DATA_WIDTH{1'b0}};
        else if (pixel_valid && writing_enabled)
            mem_data_out <= pixel_in;
        else
            mem_data_out <= {DATA_WIDTH{1'b0}};
    end

    // Control logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            writing_enabled <= 1'b1;
            reading_enabled <= 1'b0;
            buffer_ready <= 1'b0;
        end else begin
            // Enable writing when receiving valid pixels
            if (pixel_valid)
                writing_enabled <= 1'b1;
            
            // Enable reading after a few pixels are buffered
            if (write_addr >= 3*IMAGE_WIDTH + 3) // Ensure 3x3 window is available
                reading_enabled <= 1'b1;
            
            // Buffer ready when sufficient data is available
            if (write_addr >= 3*IMAGE_WIDTH + 3)
                buffer_ready <= 1'b1;
            else
                buffer_ready <= 1'b0;
        end
    end

endmodule