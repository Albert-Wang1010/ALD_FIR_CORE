`timescale 1ns/1ps
module testbench();
  localparam ACC_W = 40;
  localparam integer SHIFT = 21;

  reg  clk, rstn, en_mac, clr_acc;
  reg  signed [15:0] a_q15, b_q15;
  wire signed [ACC_W-1:0] acc_out;
  wire signed [15:0]      y_q7_9;
  wire signed [31:0]      prod_q30;

  fir_alu #(.ACC_W(ACC_W)) dut (
    .clk(clk), .rstn(rstn), .en_mac(en_mac), .clr_acc(clr_acc),
    .a_q15(a_q15), .b_q15(b_q15),
    .acc_out(acc_out), .prod_q30(prod_q30), .y_q7_9(y_q7_9), .y_saturated()
  );

  initial clk=0; always #5 clk=~clk;

  // VCD (optional)
  /*
  initial begin
    $dumpfile("fir_alu.vcd");
    $dumpvars(0, tb_fir_alu_simple_fixed);
  end
  */

  // helpers
  function signed [ACC_W-1:0] sx32(input signed [31:0] v);
    sx32 = {{(ACC_W-32){v[31]}}, v};
  endfunction
  function signed [15:0] round_shift_sat_q7_9(input signed [ACC_W-1:0] accq30);
    reg signed [ACC_W-1:0] addend, rsum, shifted;
    begin
      addend  = {{(ACC_W-SHIFT){1'b0}}, 1'b1, {(SHIFT-1){1'b0}}};
      rsum    = (accq30 >= 0) ? (accq30 + addend) : (accq30 - addend);
      shifted = rsum >>> SHIFT;
      if (shifted >  16'sh7FFF)      round_shift_sat_q7_9 = 16'sh7FFF;
      else if (shifted < -16'sh8000) round_shift_sat_q7_9 = -16'sh8000;
      else                           round_shift_sat_q7_9 = shifted[15:0];
    end
  endfunction

  // trace AFTER NBAs so we see what DUT actually sampled
 
  /*
  always @(posedge clk)
    $strobe("[%0t +POSE] rstn=%0b clr=%0b en=%0b a=%0d b=%0d prod=%0d acc=%0d y=%0d",
            $time, rstn, clr_acc, en_mac, a_q15, b_q15, prod_q30, acc_out, y_q7_9);
  */

  integer blk, tap;
  reg signed [ACC_W-1:0] exp_acc, exp_next;
  reg signed [31:0]      prod32;

  task do_clear;
    begin
      @(negedge clk) begin clr_acc=1; en_mac=0; a_q15=0; b_q15=0; end
      @(posedge clk);
      #1;  // wait for NBA updates
      if (acc_out !== 0) begin $display("ERROR: acc_out!=0 after clear"); $stop; end
      exp_acc = 0;
      @(negedge clk) clr_acc=0;
    end
  endtask

  task do_mac(input signed [15:0] A, input signed [15:0] B, input integer tix);
    begin
      // drive on NEGEDGE, hold through next POSEDGE
      @(negedge clk) begin
        a_q15  = A;
        b_q15  = B;
        en_mac = 1'b1;
        prod32   = $signed(A) * $signed(B);
        exp_next = exp_acc + sx32(prod32);
        /*$display("[%0t -NEGE] tap=%0d DRIVE en=1 A=%0d B=%0d exp_next=%0d",
                 $time, tix, A, B, exp_next);*/
      end

      // MAC happens on posedge; compare AFTER NBA
      @(posedge clk);
      #1;
      if (acc_out !== exp_next) begin
        $display(">>> ERROR tap %0d: acc got %0d exp %0d (prod=%0d)",
                 tix, acc_out, exp_next, prod_q30);
        $stop;
      end
      if (y_q7_9 !== round_shift_sat_q7_9(exp_next)) begin
        $display(">>> ERROR tap %0d: y got %0d exp %0d",
                 tix, y_q7_9, round_shift_sat_q7_9(exp_next));
        $stop;
      end

      // drop enable on following negedge (avoid same-edge race)
      @(negedge clk) en_mac = 1'b0;

      exp_acc = exp_next;
    end
  endtask

  initial begin
    // reset
    rstn=0; en_mac=0; clr_acc=0; a_q15=0; b_q15=0; exp_acc=0;
    repeat (3) @(posedge clk); rstn=1;

    for (blk=0; blk<2; blk=blk+1) begin
      do_clear();
      for (tap=0; tap<64; tap=tap+1) begin
        do_mac($random, $random, tap);
      end
    end

    $display("All ALU checks passed.");
    $finish;
  end
endmodule
