// ===========================================================================
// FIR Core Top-Level Module (64-tap, 16-bit FIR Filter)
// ===========================================================================

`timescale 1ns/1ps

module fir_core (
    // Clock and Reset
    input  wire                 clk1,           // Input clock (10 kHz)
    input  wire                 clk2,           // Core processing clock
    input  wire                 rstn,           // Active-low async reset
    
    // Input Interface (clk1 domain)
    input  wire signed [15:0]   din,            // Input data Q1.15
    input  wire                 valid_in,       // Input valid signal
    
    // Coefficient Loading Interface (clk2 domain)
    input  wire signed [15:0]   cin,            // Coefficient input Q1.15
    input  wire [5:0]           caddr,          // Coefficient address
    input  wire                 cload,          // Coefficient load enable
    
    // Output Interface (clk2 domain)
    output wire signed [15:0]   dout,           // Output data Q7.9
    output wire                 valid_out       // Output valid signal
);

    // -----------------------------------------------------------------------
    // Parameters
    // -----------------------------------------------------------------------
    localparam NUM_TAPS = 64;
    localparam ADDR_W   = 6;
    
    // -----------------------------------------------------------------------
    // Internal Signals
    // -----------------------------------------------------------------------
    
    // FIFO signals
    wire signed [15:0]  fifo_dout;
    wire                fifo_empty;
    wire                fifo_full;
    wire                fifo_ren;
    
    // CMEM signals
    wire signed [15:0]  coeff_out;
    wire                coeff_ren;
    wire [ADDR_W-1:0]   coeff_raddr;
    
    // REGFILE signals
    wire signed [15:0]  reg_dout;
    wire                reg_wen;
    wire                reg_ren;
    wire [ADDR_W-1:0]   reg_waddr;
    wire [ADDR_W-1:0]   reg_raddr;
    
    // ALU signals
    wire                alu_en_mac;
    wire                alu_clr_acc;
    wire signed [39:0]  alu_acc;
    wire signed [31:0]  alu_prod;
    wire signed [15:0]  alu_result;
    wire                alu_saturated;
    
    // FSM signals
    wire                fsm_done;
    
    // -----------------------------------------------------------------------
    // Module Instantiations
    // -----------------------------------------------------------------------
    
    // FIFO for clock domain crossing (clk1 -> clk2)
    fir_fifo #(
        .WIDTH(16),
        .DEPTH(64),
        .ADDR_W(6)
    ) u_fifo (
        // Write domain (clk1)
        .clk1(clk1),
        .rstn1(rstn),
        .wen(valid_in),
        .din(din),
        .full(fifo_full),
        
        // Read domain (clk2)
        .clk2(clk2),
        .rstn2(rstn),
        .ren(fifo_ren),
        .dout(fifo_dout),
        .empty(fifo_empty)
    );
    
    // Coefficient Memory (64x16)
    cmem #(
        .DEPTH(64),
        .WIDTH(16),
        .ADDR_W(6)
    ) u_cmem (
        .clk2(clk2),
        .rstn(rstn),
        .cload(cload),
        .caddr(caddr),
        .cin(cin),
        .ren(coeff_ren),
        .raddr(coeff_raddr),
        .cout(coeff_out)
    );
    
    // Register File (64x16) - stores input sample window
    regfile #(
        .DEPTH(64),
        .WIDTH(16),
        .ADDR_W(6)
    ) u_regfile (
        .clk2(clk2),
        .rstn(rstn),
        .wen(reg_wen),
        .waddr(reg_waddr),
        .din(fifo_dout),
        .ren(reg_ren),
        .raddr(reg_raddr),
        .dout(reg_dout)
    );
    
    // ALU (MAC unit)
    fir_alu #(
        .ACC_W(40)
    ) u_alu (
        .clk(clk2),
        .rstn(rstn),
        .en_mac(alu_en_mac),
        .clr_acc(alu_clr_acc),
        .a_q15(reg_dout),       // Sample from regfile
        .b_q15(coeff_out),      // Coefficient from cmem
        .acc_out(alu_acc),
        .prod_q30(alu_prod),
        .y_q7_9(alu_result),
        .y_saturated(alu_saturated)
    );
    
    // FSM Controller
    fir_fsm u_fsm (
        .clk2(clk2),
        .rstn(rstn),
        
        // FIFO interface
        .fifo_empty(fifo_empty),
        .fifo_ren(fifo_ren),
        
        // CMEM interface
        .coeff_ren(coeff_ren),
        .coeff_raddr(coeff_raddr),
        
        // REGFILE interface
        .reg_wen(reg_wen),
        .reg_ren(reg_ren),
        .reg_waddr(reg_waddr),
        .reg_raddr(reg_raddr),
        
        // ALU interface
        .alu_en_mac(alu_en_mac),
        .alu_clr_acc(alu_clr_acc),
        .alu_result(alu_result),
        
        // Output interface
        .dout(dout),
        .valid_out(valid_out),
        .done(fsm_done)
    );
    
endmodule


// ===========================================================================
// FSM Controller for FIR Core
// ===========================================================================

module fir_fsm (
    input  wire                 clk2,
    input  wire                 rstn,
    
    // FIFO interface
    input  wire                 fifo_empty,
    output reg                  fifo_ren,
    
    // CMEM interface
    output reg                  coeff_ren,
    output reg  [5:0]           coeff_raddr,
    
    // REGFILE interface
    output reg                  reg_wen,
    output reg                  reg_ren,
    output reg  [5:0]           reg_waddr,
    output reg  [5:0]           reg_raddr,
    
    // ALU interface
    output reg                  alu_en_mac,
    output reg                  alu_clr_acc,
    input  wire signed [15:0]   alu_result,
    
    // Output interface
    output reg  signed [15:0]   dout,
    output reg                  valid_out,
    output wire                 done
);

    // State encoding
    localparam [2:0] IDLE     = 3'd0,
                     WAIT_RD  = 3'd1,
                     LOAD     = 3'd2,
                     COMPUTE  = 3'd3,
                     WAIT_MAC = 3'd4,
                     OUTPUT   = 3'd5;
    
    reg [2:0] state, next_state;
    reg [6:0] tap_counter;
    reg [5:0] write_pointer;
    reg [2:0] wait_counter;
    
    assign done = (state == OUTPUT);
    
    always @(posedge clk2 or negedge rstn) begin
        if (!rstn)
            state <= IDLE;
        else
            state <= next_state;
    end
    
    // Next State Logic (Combinational - no reset needed)
    always @(*) begin
        next_state = state;
        case (state)
            IDLE: begin
                if (!fifo_empty)
                    next_state = WAIT_RD;
            end
            
            WAIT_RD: begin
                next_state = LOAD;
            end
            
            LOAD: begin
                next_state = COMPUTE;
            end
            
            COMPUTE: begin
                if (tap_counter == 7'd65)
                    next_state = WAIT_MAC;
            end
            
            WAIT_MAC: begin
                if (wait_counter == 3'd3)
                    next_state = OUTPUT;
            end
            
            OUTPUT: begin
                next_state = IDLE;
            end
            
            default: next_state = IDLE;
        endcase
    end
    
    always @(posedge clk2 or negedge rstn) begin
        if (!rstn) begin
            tap_counter <= 7'd0;
            write_pointer <= 6'd0;
            wait_counter <= 3'd0;
        end else begin
            case (state)
                IDLE: begin
                    tap_counter <= 7'd0;
                    wait_counter <= 3'd0;
                end
                
                COMPUTE: begin
                    if (tap_counter < 7'd65)
                        tap_counter <= tap_counter + 1'b1;
                end
                
                WAIT_MAC: begin
                    wait_counter <= wait_counter + 1'b1;
                end
                
                OUTPUT: begin
                    write_pointer <= (write_pointer == 6'd63) ? 6'd0 : write_pointer + 1'b1;
                end
            endcase
        end
    end
    
    // Output Logic (Combinational - no reset needed)
    always @(*) begin
        fifo_ren    = 1'b0;
        coeff_ren   = 1'b0;
        coeff_raddr = 6'd0;
        reg_wen     = 1'b0;
        reg_ren     = 1'b0;
        reg_waddr   = 6'd0;
        reg_raddr   = 6'd0;
        alu_en_mac  = 1'b0;
        alu_clr_acc = 1'b0;
        
        case (state)
            IDLE: begin
                if (!fifo_empty) begin
                    fifo_ren = 1'b1;
                end
            end
            
            WAIT_RD: begin
                // Wait for FIFO read
            end
            
            LOAD: begin
                reg_wen   = 1'b1;
                reg_waddr = write_pointer;
            end
            
            COMPUTE: begin
                if (tap_counter == 7'd0) begin
                    alu_clr_acc = 1'b1;
                end
                
                if (tap_counter < 7'd64) begin
                    coeff_ren   = 1'b1;
                    coeff_raddr = tap_counter[5:0];
                    
                    reg_ren   = 1'b1;
                    if (write_pointer >= tap_counter[5:0]) begin
                        reg_raddr = write_pointer - tap_counter[5:0];
                    end else begin
                        reg_raddr = 6'd64 + write_pointer - tap_counter[5:0];
                    end
                end
                
                if (tap_counter >= 7'd2 && tap_counter < 7'd66) begin
                    alu_en_mac = 1'b1;
                end
            end
            
            WAIT_MAC: begin
                // Wait for MAC to settle
            end
            
            OUTPUT: begin
                // Output registered below
            end
        endcase
    end
    
    always @(posedge clk2 or negedge rstn) begin
        if (!rstn) begin
            dout <= 16'd0;
            valid_out <= 1'b0;
        end else begin
            if (state == OUTPUT) begin
                dout <= alu_result;
                valid_out <= 1'b1;
            end else begin
                valid_out <= 1'b0;
            end
        end
    end
    
endmodule


// ===========================================================================
// FIR ALU (MAC Unit)
// ===========================================================================

module fir_alu
#(
  parameter ACC_W = 40
)
(
  input  wire                     clk,
  input  wire                     rstn,
  input  wire                     en_mac,
  input  wire                     clr_acc,
  input  wire signed [15:0]       a_q15,
  input  wire signed [15:0]       b_q15,
  output reg  signed [ACC_W-1:0]  acc_out,
  output wire signed [31:0]       prod_q30,
  output reg  signed [15:0]       y_q7_9,
  output reg                      y_saturated
);
  
  wire signed [31:0] mult_raw;
  assign mult_raw  = $signed(a_q15) * $signed(b_q15);
  assign prod_q30  = mult_raw;
  
  wire signed [ACC_W-1:0] prod_ext;
  assign prod_ext = {{(ACC_W-32){mult_raw[31]}}, mult_raw};
  
  always @(posedge clk or negedge rstn) begin
    if (!rstn) begin
      acc_out <= {ACC_W{1'b0}};
    end else if (clr_acc) begin
      acc_out <= {ACC_W{1'b0}};
    end else if (en_mac) begin
      acc_out <= acc_out + prod_ext;
    end
  end
  
  // Rounding and saturation (combinational - no reset needed)
  localparam integer SHIFT = 21;
  
  wire signed [ACC_W-1:0] round_add =
      {{(ACC_W-SHIFT){1'b0}}, 1'b1, {(SHIFT-1){1'b0}}};
  wire signed [ACC_W-1:0] acc_round =
      (acc_out[ACC_W-1] == 1'b0) ? (acc_out + round_add)
                                 : (acc_out - round_add);
  
  wire signed [ACC_W-1:0] acc_shift = acc_round >>> SHIFT;
  
  wire signed [ACC_W-1:0] max_pos = {{(ACC_W-16){1'b0}}, 16'h7FFF};
  wire signed [ACC_W-1:0] min_neg = {{(ACC_W-16){1'b1}}, 16'h8000};
  
  always @* begin
    y_saturated = 1'b0;
    if (acc_shift > max_pos) begin
      y_q7_9      = 16'sh7FFF;
      y_saturated = 1'b1;
    end else if (acc_shift < min_neg) begin
      y_q7_9      = 16'sh8000;
      y_saturated = 1'b1;
    end else begin
      y_q7_9 = acc_shift[15:0];
    end
  end
endmodule


// ===========================================================================
// Coefficient Memory (cmem)
// ===========================================================================

module cmem
#(
  parameter integer DEPTH  = 64,
  parameter integer WIDTH  = 16,
  parameter integer ADDR_W = 6
)(
  input  wire                     clk2,
  input  wire                     rstn,
  input  wire                     cload,
  input  wire [ADDR_W-1:0]        caddr,
  input  wire signed [WIDTH-1:0]  cin,
  input  wire                     ren,
  input  wire [ADDR_W-1:0]        raddr,
  output reg  signed [WIDTH-1:0]  cout
);
  
  reg signed [WIDTH-1:0] mem [0:DEPTH-1];
  
  integer mem_rst_idx;
  always @(posedge clk2 or negedge rstn) begin
    if (!rstn) begin
      cout <= {WIDTH{1'b0}};
      // Initialize ALL memory locations
      for (mem_rst_idx = 0; mem_rst_idx < DEPTH; mem_rst_idx = mem_rst_idx + 1) begin
        mem[mem_rst_idx] <= {WIDTH{1'b0}};
      end
    end else begin
      if (cload) begin
        mem[caddr] <= cin;
      end
      if (ren) begin
        cout <= mem[raddr];
      end
    end
  end
endmodule


// ===========================================================================
// Register File (regfile)
// ===========================================================================

module regfile
#(
  parameter integer DEPTH  = 64,
  parameter integer WIDTH  = 16,
  parameter integer ADDR_W = 6
)(
  input  wire                     clk2,
  input  wire                     rstn,
  input  wire                     wen,
  input  wire [ADDR_W-1:0]        waddr,
  input  wire signed [WIDTH-1:0]  din,
  input  wire                     ren,
  input  wire [ADDR_W-1:0]        raddr,
  output reg  signed [WIDTH-1:0]  dout
);
  
  reg signed [WIDTH-1:0] mem [0:DEPTH-1];
  
  integer mem_rst_idx;
  always @(posedge clk2 or negedge rstn) begin
    if (!rstn) begin
      dout <= {WIDTH{1'b0}};
      // Initialize ALL memory locations
      for (mem_rst_idx = 0; mem_rst_idx < DEPTH; mem_rst_idx = mem_rst_idx + 1) begin
        mem[mem_rst_idx] <= {WIDTH{1'b0}};
      end
    end else begin
      if (wen) begin
        mem[waddr] <= din;
      end
      if (ren) begin
        dout <= mem[raddr];
      end
    end
  end
endmodule


// ===========================================================================
// Asynchronous FIFO
// ===========================================================================

module fir_fifo #(
    parameter WIDTH = 16,
    parameter DEPTH = 64,
    parameter ADDR_W = 6
) (
    // Write clock domain (clk1 - 10 kHz)
    input  wire                 clk1,
    input  wire                 rstn1,
    input  wire                 wen,
    input  wire signed [WIDTH-1:0] din,
    output reg                  full,
    
    // Read clock domain (clk2 - 100 MHz)
    input  wire                 clk2,
    input  wire                 rstn2,
    input  wire                 ren,
    output reg signed [WIDTH-1:0] dout,
    output reg                  empty
);

    // Internal Signals
    reg signed [WIDTH-1:0] mem [0:DEPTH-1];
    
    reg [ADDR_W:0] wptr_bin;
    reg [ADDR_W:0] wptr_gray;
    reg [ADDR_W:0] wptr_gray_sync1;
    reg [ADDR_W:0] wptr_gray_sync2;
    
    reg [ADDR_W:0] rptr_bin;
    reg [ADDR_W:0] rptr_gray;
    reg [ADDR_W:0] rptr_gray_sync1;
    reg [ADDR_W:0] rptr_gray_sync2;
    
    // Binary to Gray Code Conversion
    function [ADDR_W:0] bin2gray;
        input [ADDR_W:0] binary;
        begin
            bin2gray = binary ^ (binary >> 1);
        end
    endfunction
    
    // Gray to Binary Code Conversion
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
    
    integer mem_rst_idx;
    always @(posedge clk1 or negedge rstn1) begin
        if (!rstn1) begin
            wptr_bin  <= {(ADDR_W+1){1'b0}};
            wptr_gray <= {(ADDR_W+1){1'b0}};
            // Initialize ALL memory locations
            for (mem_rst_idx = 0; mem_rst_idx < DEPTH; mem_rst_idx = mem_rst_idx + 1) begin
                mem[mem_rst_idx] <= {WIDTH{1'b0}};
            end
        end else begin
            if (wen && !full) begin
                mem[wptr_bin[ADDR_W-1:0]] <= din;
                wptr_bin  <= wptr_bin + 1'b1;
                wptr_gray <= bin2gray(wptr_bin + 1'b1);
            end
        end
    end
    
    always @(posedge clk1 or negedge rstn1) begin
        if (!rstn1) begin
            rptr_gray_sync1 <= {(ADDR_W+1){1'b0}};
            rptr_gray_sync2 <= {(ADDR_W+1){1'b0}};
        end else begin
            rptr_gray_sync1 <= rptr_gray;
            rptr_gray_sync2 <= rptr_gray_sync1;
        end
    end
    
    always @(posedge clk1 or negedge rstn1) begin
        if (!rstn1) begin
            full <= 1'b0;
        end else begin
            full <= (wptr_gray == {~rptr_gray_sync2[ADDR_W:ADDR_W-1], rptr_gray_sync2[ADDR_W-2:0]});
        end
    end
    
    always @(posedge clk2 or negedge rstn2) begin
        if (!rstn2) begin
            rptr_bin  <= {(ADDR_W+1){1'b0}};
            rptr_gray <= {(ADDR_W+1){1'b0}};
        end else begin
            if (ren && !empty) begin
                rptr_bin  <= rptr_bin + 1'b1;
                rptr_gray <= bin2gray(rptr_bin + 1'b1);
            end
        end
    end
    
    always @(posedge clk2 or negedge rstn2) begin
        if (!rstn2) begin
            dout <= {WIDTH{1'b0}};
        end else begin
            if (ren && !empty) begin
                dout <= mem[rptr_bin[ADDR_W-1:0]];
            end
        end
    end
    
    always @(posedge clk2 or negedge rstn2) begin
        if (!rstn2) begin
            wptr_gray_sync1 <= {(ADDR_W+1){1'b0}};
            wptr_gray_sync2 <= {(ADDR_W+1){1'b0}};
        end else begin
            wptr_gray_sync1 <= wptr_gray;
            wptr_gray_sync2 <= wptr_gray_sync1;
        end
    end
    
    always @(posedge clk2 or negedge rstn2) begin
        if (!rstn2) begin
            empty <= 1'b1;
        end else begin
            empty <= (rptr_gray == wptr_gray_sync2);
        end
    end

endmodule
