// Asynchronous FIFO/Synchronizer

//   Dual-clock FIFO for clock domain crossing between:
//     - clk1 (10 kHz): Input sampling clock
//     - clk2 (100 MHz): Core processing clock
//   Features:
//     - 64-entry FIFO depth
//     - 16-bit signed data
//     - Gray code pointer synchronization
//     - Follows REGFILE/CMEM design style

`timescale 1ns / 1ps

module fir_fifo #(
    parameter WIDTH = 16,        // Data width (16-bit signed samples)
  parameter DEPTH = 64,        // FIFO depth 
    parameter ADDR_W = 6         // Address width 
) (
    // Write clock domain (clk1 - 10 kHz input sampling)
    input  wire                 clk1,       // Write clock (10 kHz)
    input  wire                 rstn1,      // Async reset for write domain
    input  wire                 wen,        // Write enable
    input  wire signed [WIDTH-1:0] din,     // Write data (signed)
    output reg                  full,       // FIFO full flag
    
    // Read clock domain (clk2 - 100 MHz core clock)
    input  wire                 clk2,       // Read clock (100 MHz)
    input  wire                 rstn2,      // Async reset for read domain
    input  wire                 ren,        // Read enable
    output reg signed [WIDTH-1:0] dout,     // Read data (signed, registered)
    output reg                  empty       // FIFO empty flag
);

    // Internal Signals
    
    // FIFO memory storage
    reg signed [WIDTH-1:0] mem [0:DEPTH-1];
    
    // Write domain pointers (binary)
    reg [ADDR_W:0] wptr_bin;         // Write pointer (binary) - extra bit for full/empty
    reg [ADDR_W:0] wptr_gray;        // Write pointer (Gray code)
    reg [ADDR_W:0] wptr_gray_sync1;  // Synchronized write pointer (stage 1)
    reg [ADDR_W:0] wptr_gray_sync2;  // Synchronized write pointer (stage 2)
    
    // Read domain pointers (binary)
    reg [ADDR_W:0] rptr_bin;         // Read pointer (binary) - extra bit for full/empty
    reg [ADDR_W:0] rptr_gray;        // Read pointer (Gray code)
    reg [ADDR_W:0] rptr_gray_sync1;  // Synchronized read pointer (stage 1)
    reg [ADDR_W:0] rptr_gray_sync2;  // Synchronized read pointer (stage 2)
    
    // Binary to Gray Code Conversion Function
    function [ADDR_W:0] bin2gray;
        input [ADDR_W:0] binary;
        begin
            bin2gray = binary ^ (binary >> 1);
        end
    endfunction
    
    // Gray to Binary Code Conversion Function
    function [ADDR_W:0] gray2bin;
        input [ADDR_W:0] gray;
        integer i;
        begin
            gray2bin[ADDR_W] = gray[ADDR_W];
            for (i = ADDR_W-1; i >= 0; i = i - 1) begin
                gray2bin[i] = gray2bin[i+1] ^ gray[i];
            end
        end
    endfunction
    
    // Write Clock Domain (clk1 - 10 kHz)
    
    // Write pointer and memory write logic
    always @(posedge clk1 or negedge rstn1) begin
        if (!rstn1) begin
            wptr_bin  <= {(ADDR_W+1){1'b0}};
            wptr_gray <= {(ADDR_W+1){1'b0}};
        end else begin
            if (wen && !full) begin
                // Write data to FIFO
                mem[wptr_bin[ADDR_W-1:0]] <= din;
                // Increment write pointer
                wptr_bin  <= wptr_bin + 1'b1;
                wptr_gray <= bin2gray(wptr_bin + 1'b1);
            end
        end
    end
    
    // Synchronize read pointer to write clock domain (2-FF synchronizer)
    always @(posedge clk1 or negedge rstn1) begin
        if (!rstn1) begin
            rptr_gray_sync1 <= {(ADDR_W+1){1'b0}};
            rptr_gray_sync2 <= {(ADDR_W+1){1'b0}};
        end else begin
            rptr_gray_sync1 <= rptr_gray;
            rptr_gray_sync2 <= rptr_gray_sync1;
        end
    end
    
    // Generate full flag (write domain)
    always @(posedge clk1 or negedge rstn1) begin
        if (!rstn1) begin
            full <= 1'b0;
        end else begin
            // Full when write pointer + 1 equals synchronized read pointer
            // Compare in Gray code: MSB different, rest same
            full <= (wptr_gray == {~rptr_gray_sync2[ADDR_W:ADDR_W-1], rptr_gray_sync2[ADDR_W-2:0]});
        end
    end
    
    // Read Clock Domain (clk2 - 100 MHz)
    
    // Read pointer logic
    always @(posedge clk2 or negedge rstn2) begin
        if (!rstn2) begin
            rptr_bin  <= {(ADDR_W+1){1'b0}};
            rptr_gray <= {(ADDR_W+1){1'b0}};
        end else begin
            if (ren && !empty) begin
                // Increment read pointer
                rptr_bin  <= rptr_bin + 1'b1;
                rptr_gray <= bin2gray(rptr_bin + 1'b1);
            end
        end
    end
    
    // Registered read output (matches REGFILE/CMEM style)
    always @(posedge clk2 or negedge rstn2) begin
        if (!rstn2) begin
            dout <= {WIDTH{1'b0}};
        end else begin
            if (ren && !empty) begin
                dout <= mem[rptr_bin[ADDR_W-1:0]];
            end
        end
    end
    
    // Synchronize write pointer to read clock domain (2-FF synchronizer)
    always @(posedge clk2 or negedge rstn2) begin
        if (!rstn2) begin
            wptr_gray_sync1 <= {(ADDR_W+1){1'b0}};
            wptr_gray_sync2 <= {(ADDR_W+1){1'b0}};
        end else begin
            wptr_gray_sync1 <= wptr_gray;
            wptr_gray_sync2 <= wptr_gray_sync1;
        end
    end
    
    // Generate empty flag (read domain)
    always @(posedge clk2 or negedge rstn2) begin
        if (!rstn2) begin
            empty <= 1'b1;  // Start empty
        end else begin
            // Empty when read pointer equals synchronized write pointer
            empty <= (rptr_gray == wptr_gray_sync2);
        end
    end

endmodule
