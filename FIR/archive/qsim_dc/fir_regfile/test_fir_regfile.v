`timescale 1ns/1ps
module testbench();
  localparam integer DEPTH  = 64;
  localparam integer WIDTH  = 16;
  localparam integer ADDR_W = 6;
  
  // DUT I/O
  reg                     clk2, rstn;
  reg                     wen;
  reg  [ADDR_W-1:0]       waddr;
  reg  signed [WIDTH-1:0] din;
  reg                     ren;
  reg  [ADDR_W-1:0]       raddr;
  wire signed [WIDTH-1:0] dout;
  
  regfile dut (
    .clk2 (clk2), .rstn (rstn),
    .wen  (wen),  .waddr(waddr), .din(din),
    .ren  (ren),  .raddr(raddr), .dout(dout)
  );
  
  // simple model to check against
  reg signed [WIDTH-1:0] shadow [0:DEPTH-1];
  
  // clock
  initial clk2 = 0;
  always #5 clk2 = ~clk2;   // 100 MHz
  

  initial begin
    $dumpfile("testbench.vcd");
    $dumpvars(0, dut.clk2);
    $dumpvars(0, dut.rstn);
    $dumpvars(0, dut.wen);
    $dumpvars(0, dut.waddr);
    $dumpvars(0, dut.din);
    $dumpvars(0, dut.ren);
    $dumpvars(0, dut.raddr);
    $dumpvars(0, dut.dout);  
  end

  
  integer i;
  integer mismatches;
  initial begin
    // init
    rstn = 0; wen = 0; ren = 0; waddr = 0; raddr = 0; din = 0;
    mismatches = 0;
    repeat (3) @(posedge clk2);
    rstn = 1;
    
    // ----------------------------
    // write phase (1 entry per cycle)
    // ----------------------------
    for (i = 0; i < DEPTH; i = i + 1) begin
      @(posedge clk2);
      wen   <= 1'b1;
      waddr <= i % DEPTH;
      din   <= $random;
      shadow[i] = din;
    end
    @(posedge clk2);
    wen <= 1'b0;
    
    // ----------------------------
    // read phase (registered => 1-cycle latency)
    // ----------------------------
    ren   <= 1'b1;
    raddr <= 0;
    @(posedge clk2); 
    
    for (i = 0; i < DEPTH; i = i + 1) begin
      // data returned now corresponds to current raddr
      /*$display("[%0t] read[%0d] -> dout=%0d  exp=%0d",
               $time, i, dout, shadow[i]);
      */
      if (dout !== shadow[i]) begin
        mismatches = mismatches + 1;
        $display("  MISMATCH at idx %0d: got=%0d exp=%0d",
                 i, dout, shadow[i]);
      end
      // queue next address
      raddr <= (i + 1) % DEPTH;
      @(posedge clk2);
    end
    
    // ----------------------------
    // simultaneous read/write test
    // ----------------------------
    @(posedge clk2);
    wen   <= 1'b1;
    waddr <= 10;
    din   <= 16'sh1234;
    ren   <= 1'b1;
    raddr <= 10;
    shadow[10] = 16'sh1234;
    
    @(posedge clk2);
    // read back the just-written value
    wen   <= 1'b0;
    raddr <= 10;
    
    @(posedge clk2);
    @(posedge clk2);
    if (dout !== 16'sh1234) begin
      mismatches = mismatches + 1;
      $display("  MISMATCH on simultaneous R/W: got=%0d exp=%0d",
               dout, 16'sh1234);
    end
    
    if (mismatches == 0)
      $display("REGFILE test PASSED (%0d entries).", DEPTH);
    else
      $display("REGFILE test FAILED: %0d mismatches.", mismatches);
    $finish;
  end
endmodule
