// cmem.v — 64x16 signed coefficient memory (Q1.15)
// Sequential write + registered read (1-cycle latency) on clk2
`timescale 1ns/1ps
module cmem
#(
  parameter integer DEPTH  = 64,
  parameter integer WIDTH  = 16,
  parameter integer ADDR_W = 6     // clog2(64)
)(
  input  wire                     clk2,
  input  wire                     rstn,
  // preload / writes
  input  wire                     cload,
  input  wire [ADDR_W-1:0]        caddr,
  input  wire signed [WIDTH-1:0]  cin,
  // reads (used during FIR run)
  input  wire                     ren,
  input  wire [ADDR_W-1:0]        raddr,
  output reg  signed [WIDTH-1:0]  cout   // registered read data
);
  // storage
  reg signed [WIDTH-1:0] mem [0:DEPTH-1];
  
  // seq: write + register the read data from COMBINATIONAL address
  always @(posedge clk2 or negedge rstn) begin
    if (!rstn) begin
      cout <= {WIDTH{1'b0}};
    end else begin
      // write
      if (cload) begin
        mem[caddr] <= cin;
      end
      // registered read from COMBINATIONAL raddr (true 1-cycle latency)
      if (ren) begin
        cout <= mem[raddr];
      end
    end
  end
endmodule
