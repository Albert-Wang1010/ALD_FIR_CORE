`timescale 1ns/1ps
module testbench;

  localparam integer DEPTH  = 64;
  localparam integer WIDTH  = 16;
  localparam integer ADDR_W = 6;

  // DUT I/O
  reg                     clk2, rstn;
  reg                     cload;
  reg  [ADDR_W-1:0]       caddr;
  reg  signed [WIDTH-1:0] cin;

  reg                     ren;
  reg  [ADDR_W-1:0]       raddr;
  wire signed [WIDTH-1:0] cout;

  // instantiate WITHOUT parameter override (uses defaults)
  cmem dut (
    .clk2 (clk2), .rstn (rstn),
    .cload(cload), .caddr(caddr), .cin(cin),
    .ren  (ren),   .raddr(raddr), .cout(cout)
  );

  // simple model to check against
  reg signed [WIDTH-1:0] shadow [0:DEPTH-1];
  

  // clock
  initial clk2 = 0;
  always #5 clk2 = ~clk2;   // 100 MHz
  
initial begin
    $dumpfile("testbench.vcd");
    // Dump from DUT's perspective
    $dumpvars(0, dut.clk2);
    $dumpvars(0, dut.rstn);
    $dumpvars(0, dut.cload);
    $dumpvars(0, dut.caddr);
    $dumpvars(0, dut.cin);
    $dumpvars(0, dut.ren);
    $dumpvars(0, dut.raddr);
    $dumpvars(0, dut.cout);
end

  integer i;
  integer mismatches;

  initial begin
    // init
    rstn = 0; cload = 0; ren = 0; caddr = 0; raddr = 0; cin = 0;
    mismatches = 0;
    repeat (3) @(posedge clk2);
    rstn = 1;

    // ----------------------------
    // preload writes (1 entry per cycle)
    // ----------------------------
    for (i = 0; i < DEPTH; i = i + 1) begin
      @(posedge clk2);
      cload <= 1'b1;
      caddr <= i % DEPTH;                 // avoid bit-select on int
      cin   <= $random;                   // signed Q1.15 fill
      shadow[i] = cin;
    end
    @(posedge clk2);
    cload <= 1'b0;

    // ----------------------------
    // reads (registered => 1-cycle latency)
    // ----------------------------
    
    ren   <= 1'b1;
    raddr <= 0;
    @(posedge clk2); 
    
    for (i = 0; i < DEPTH; i = i + 1) begin
      // data returned now corresponds to current raddr (which was set 2 cycles ago)
      /*
	$display("[%0t] read[%0d] -> cout=%0d  exp=%0d",
               $time, i, cout, shadow[i]);
      */
      if (cout !== shadow[i]) begin
        mismatches = mismatches + 1;
        $display("  MISMATCH at idx %0d: got=%0d exp=%0d",
                 i, cout, shadow[i]);
      end
      // queue next address
      raddr <= (i + 1) % DEPTH;
      @(posedge clk2);
    end
    
    // no extra final cycle needed now
    if (mismatches == 0)
      $display("CMEM test PASSED (%0d entries).", DEPTH);
    else
      $display("CMEM test FAILED: %0d mismatches.", mismatches);

    $finish;
  end
endmodule

