//==============================================================================
// Control Unit for FPGA Edge Detection Pipeline
// Manages pipeline stages and coordinates processing flow
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

    // State definitions
    localparam [3:0] 
        IDLE           = 4'b0000,
        INIT           = 4'b0001,
        GAUSSIAN       = 4'b0010,
        SOBEL          = 4'b0011,
        MAGNITUDE      = 4'b0100,
        NONMAX         = 4'b0101,
        HYSTERESIS     = 4'b0110,
        DONE           = 4'b0111;

    // Internal registers
    reg [3:0] state, next_state;
    reg [19:0] pixel_count;
    reg [19:0] total_pixels;
    reg [7:0] pipeline_delay;
    
    // Calculate total pixels
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            total_pixels <= IMAGE_WIDTH * IMAGE_HEIGHT;
        else
            total_pixels <= IMAGE_WIDTH * IMAGE_HEIGHT;
    end

    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            state <= IDLE;
        else
            state <= next_state;
    end

    // Next state logic
    always @(*) begin
        case (state)
            IDLE: begin
                if (start)
                    next_state = INIT;
                else
                    next_state = IDLE;
            end
            
            INIT: begin
                next_state = GAUSSIAN;
            end
            
            GAUSSIAN: begin
                if (pixel_count >= 9) // Wait for 3x3 window to be available
                    next_state = SOBEL;
                else
                    next_state = GAUSSIAN;
            end
            
            SOBEL: begin
                if (pixel_count >= 18) // Additional delay for Sobel processing
                    next_state = MAGNITUDE;
                else
                    next_state = SOBEL;
            end
            
            MAGNITUDE: begin
                if (pixel_count >= 25)
                    next_state = NONMAX;
                else
                    next_state = MAGNITUDE;
            end
            
            NONMAX: begin
                if (pixel_count >= 32)
                    next_state = HYSTERESIS;
                else
                    next_state = NONMAX;
            end
            
            HYSTERESIS: begin
                if (pixel_count >= total_pixels + 40) // All pixels processed plus pipeline delay
                    next_state = DONE;
                else
                    next_state = HYSTERESIS;
            end
            
            DONE: begin
                if (!start)
                    next_state = IDLE;
                else
                    next_state = DONE;
            end
            
            default: next_state = IDLE;
        endcase
    end

    // Pixel counter
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            pixel_count <= 20'h00000;
        else if (state == IDLE)
            pixel_count <= 20'h00000;
        else if (pixel_valid)
            pixel_count <= pixel_count + 1;
    end

    // Pipeline delay counter
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            pipeline_delay <= 8'h00;
        else if (state == IDLE)
            pipeline_delay <= 8'h00;
        else if (pipeline_delay < 8'hFF)
            pipeline_delay <= pipeline_delay + 1;
    end

    // Output control signals
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            ready <= 1'b1;
            current_stage <= 4'h0;
            stage_select <= 4'h0;
            enable_gaussian <= 1'b0;
            enable_sobel <= 1'b0;
            enable_magnitude <= 1'b0;
            enable_nonmax <= 1'b0;
            enable_hysteresis <= 1'b0;
            processing_done <= 1'b0;
        end else begin
            case (state)
                IDLE: begin
                    ready <= 1'b1;
                    current_stage <= 4'h0;
                    stage_select <= 4'h0;
                    enable_gaussian <= 1'b0;
                    enable_sobel <= 1'b0;
                    enable_magnitude <= 1'b0;
                    enable_nonmax <= 1'b0;
                    enable_hysteresis <= 1'b0;
                    processing_done <= 1'b0;
                end
                
                INIT: begin
                    ready <= 1'b0;
                    current_stage <= 4'h1;
                    stage_select <= 4'h1;
                    enable_gaussian <= 1'b1;
                    enable_sobel <= 1'b0;
                    enable_magnitude <= 1'b0;
                    enable_nonmax <= 1'b0;
                    enable_hysteresis <= 1'b0;
                    processing_done <= 1'b0;
                end
                
                GAUSSIAN: begin
                    ready <= 1'b0;
                    current_stage <= 4'h2;
                    stage_select <= 4'h2;
                    enable_gaussian <= 1'b1;
                    enable_sobel <= 1'b0;
                    enable_magnitude <= 1'b0;
                    enable_nonmax <= 1'b0;
                    enable_hysteresis <= 1'b0;
                    processing_done <= 1'b0;
                end
                
                SOBEL: begin
                    ready <= 1'b0;
                    current_stage <= 4'h3;
                    stage_select <= 4'h3;
                    enable_gaussian <= 1'b1;
                    enable_sobel <= 1'b1;
                    enable_magnitude <= 1'b0;
                    enable_nonmax <= 1'b0;
                    enable_hysteresis <= 1'b0;
                    processing_done <= 1'b0;
                end
                
                MAGNITUDE: begin
                    ready <= 1'b0;
                    current_stage <= 4'h4;
                    stage_select <= 4'h4;
                    enable_gaussian <= 1'b1;
                    enable_sobel <= 1'b1;
                    enable_magnitude <= 1'b1;
                    enable_nonmax <= 1'b0;
                    enable_hysteresis <= 1'b0;
                    processing_done <= 1'b0;
                end
                
                NONMAX: begin
                    ready <= 1'b0;
                    current_stage <= 4'h5;
                    stage_select <= 4'h5;
                    enable_gaussian <= 1'b1;
                    enable_sobel <= 1'b1;
                    enable_magnitude <= 1'b1;
                    enable_nonmax <= 1'b1;
                    enable_hysteresis <= 1'b0;
                    processing_done <= 1'b0;
                end
                
                HYSTERESIS: begin
                    ready <= 1'b0;
                    current_stage <= 4'h6;
                    stage_select <= 4'h6;
                    enable_gaussian <= 1'b1;
                    enable_sobel <= 1'b1;
                    enable_magnitude <= 1'b1;
                    enable_nonmax <= 1'b1;
                    enable_hysteresis <= 1'b1;
                    processing_done <= 1'b0;
                end
                
                DONE: begin
                    ready <= 1'b1;
                    current_stage <= 4'h7;
                    stage_select <= 4'h7;
                    enable_gaussian <= 1'b0;
                    enable_sobel <= 1'b0;
                    enable_magnitude <= 1'b0;
                    enable_nonmax <= 1'b0;
                    enable_hysteresis <= 1'b0;
                    processing_done <= 1'b1;
                end
                
                default: begin
                    ready <= 1'b1;
                    current_stage <= 4'h0;
                    stage_select <= 4'h0;
                    enable_gaussian <= 1'b0;
                    enable_sobel <= 1'b0;
                    enable_magnitude <= 1'b0;
                    enable_nonmax <= 1'b0;
                    enable_hysteresis <= 1'b0;
                    processing_done <= 1'b0;
                end
            endcase
        end
    end

endmodule