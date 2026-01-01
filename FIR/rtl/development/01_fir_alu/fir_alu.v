// ---------------------------------------------------------------------------
// FIR ALU
//   - one signed 16x16 multiplier and one wide adder (accumulator)
//   - inputs a_q15, b_q15 are Q1.15
//   - product is Q2.30 (32-bit)
//   - accumulator width is parameterized (default 40 bits) to minimize error
//   - output y_q7_9 is Q7.9 (rounded + saturated to 16-bit)
// Control:
//   - clk, rstn, en_mac (do one MAC tap), clr_acc (clear accumulator)
// ---------------------------------------------------------------------------
`timescale 1ns/1ps

module fir_alu
#(
  parameter ACC_W = 40              // >= 32 + guard bits
)
(
  input  wire                     clk,
  input  wire                     rstn,
  input  wire                     en_mac,
  input  wire                     clr_acc,
  input  wire signed [15:0]       a_q15,     // Q1.15
  input  wire signed [15:0]       b_q15,     // Q1.15

  output reg  signed [ACC_W-1:0]  acc_out,   // Q2.30 in wide reg
  output wire signed [31:0]       prod_q30,  // Q2.30 (for visibility)
  output reg  signed [15:0]       y_q7_9,    // Q7.9 (rounded + saturated)
  output reg                      y_saturated
);

  // 16x16 -> 32-bit signed product (Q2.30)
  wire signed [31:0] mult_raw;
  assign mult_raw  = $signed(a_q15) * $signed(b_q15);
  assign prod_q30  = mult_raw;

  // Widen product to accumulator width for addition
  wire signed [ACC_W-1:0] prod_ext;
  assign prod_ext = {{(ACC_W-32){mult_raw[31]}}, mult_raw};

  // Wide accumulator register
  always @(posedge clk or negedge rstn) begin
    if (!rstn) begin
      acc_out <= {ACC_W{1'b0}};
    end else if (clr_acc) begin
      acc_out <= {ACC_W{1'b0}};
    end else if (en_mac) begin
      acc_out <= acc_out + prod_ext;
    end
  end

  // -------- scale Q2.30 -> Q7.9 with sign-aware rounding and saturation ----
  // shift amount from 30 frac bits to 9 frac bits:
  localparam integer SHIFT = 21;

  // round-to-nearest: add +/- 2^(SHIFT-1) before arithmetic shift
  wire signed [ACC_W-1:0] round_add =
      {{(ACC_W-SHIFT){1'b0}}, 1'b1, {(SHIFT-1){1'b0}}};

  wire signed [ACC_W-1:0] acc_round =
      (acc_out[ACC_W-1] == 1'b0) ? (acc_out + round_add)  // positive
                                 : (acc_out - round_add); // negative

  // arithmetic right shift
  wire signed [ACC_W-1:0] acc_shift = acc_round >>> SHIFT;

  // saturate to 16-bit signed output
  // legal int16 range: [-32768, 32767]
  always @* begin
    y_saturated = 1'b0;

    if (acc_shift >  16'sh7FFF) begin
      y_q7_9      = 16'sh7FFF;
      y_saturated = 1'b1;
    end else if (acc_shift < -16'sh8000) begin
      y_q7_9      = -16'sh8000;
      y_saturated = 1'b1;
    end else begin
      y_q7_9 = acc_shift[15:0];
    end
  end

endmodule
