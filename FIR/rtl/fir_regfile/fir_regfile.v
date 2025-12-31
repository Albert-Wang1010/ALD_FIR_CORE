// regfile.v — 64x16 signed register file
// Sequential write + registered read (1-cycle latency) on clk2
`timescale 1ns/1ps
module regfile
#(
  parameter integer DEPTH  = 64,
  parameter integer WIDTH  = 16,
  parameter integer ADDR_W = 6     // clog2(64)
)(
  input  wire                     clk2,
  input  wire                     rstn,
  // writes
  input  wire                     wen,
  input  wire [ADDR_W-1:0]        waddr,
  input  wire signed [WIDTH-1:0]  din,
  // reads (used during FIR run)
  input  wire                     ren,
  input  wire [ADDR_W-1:0]        raddr,
  output reg  signed [WIDTH-1:0]  dout   // registered read data
);
  // storage
  reg signed [WIDTH-1:0] mem [0:DEPTH-1];
  
  // seq: write + register the read data from COMBINATIONAL address
  always @(posedge clk2 or negedge rstn) begin
    if (!rstn) begin
      dout <= {WIDTH{1'b0}};
    end else begin
      // write
      if (wen) begin
        mem[waddr] <= din;
      end
      // registered read from COMBINATIONAL raddr (true 1-cycle latency)
      if (ren) begin
        dout <= mem[raddr];
      end
    end
  end
endmodule
