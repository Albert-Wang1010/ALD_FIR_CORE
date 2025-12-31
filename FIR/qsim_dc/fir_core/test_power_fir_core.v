// ===========================================================================
// FIR Core Power Analysis Testbench
// ===========================================================================
// Generates VCD for power analysis with realistic workload
// Shorter duration but covers all switching scenarios
// ===========================================================================

`timescale 1ns/1ps

module testbench;

    parameter NUM_TAPS = 64;
    parameter CLK1_PERIOD = 100000;  // 10 kHz
    parameter CLK2_PERIOD = 10;      // 100 MHz
    
    // Signals
    reg                 clk1;
    reg                 clk2;
    reg                 rstn;
    reg  signed [15:0]  din;
    reg                 valid_in;
    reg  signed [15:0]  cin;
    reg  [5:0]          caddr;
    reg                 cload;
    wire signed [15:0]  dout;
    wire                valid_out;
    
    integer i;
    
    // Clock Generation
    initial begin
        clk1 = 0;
        forever #(CLK1_PERIOD/2) clk1 = ~clk1;
    end
    
    initial begin
        clk2 = 0;
        forever #(CLK2_PERIOD/2) clk2 = ~clk2;
    end
    
    // DUT
    fir_core dut (
        .clk1(clk1),
        .clk2(clk2),
        .rstn(rstn),
        .din(din),
        .valid_in(valid_in),
        .cin(cin),
        .caddr(caddr),
        .cload(cload),
        .dout(dout),
        .valid_out(valid_out)
    );
    
    // -----------------------------------------------------------------------
    // VCD Dump for Power Analysis
    // -----------------------------------------------------------------------
    initial begin
        $dumpfile("power_analysis.vcd");
        
        // CRITICAL: Dump entire hierarchy for power analysis
        $dumpvars(0, testbench);
        
        // Explicitly dump clock domains (high activity)
        $dumpvars(0, clk1);
        $dumpvars(0, clk2);
        $dumpvars(0, rstn);
        
        // Dump all top-level I/O
        $dumpvars(0, valid_in);
        $dumpvars(0, din);
        $dumpvars(0, cload);
        $dumpvars(0, caddr);
        $dumpvars(0, cin);
        $dumpvars(0, valid_out);
        $dumpvars(0, dout);
    end
    
    // -----------------------------------------------------------------------
    // Power Analysis Stimulus
    // -----------------------------------------------------------------------
    initial begin
        $display("\n========================================");
        $display("FIR Core Power Analysis Testbench");
        $display("========================================");
        $display("Generating VCD for power analysis...\n");
        
        // Initialize
        rstn = 0;
        din = 0;
        valid_in = 0;
        cin = 0;
        caddr = 0;
        cload = 0;
        
        // Reset
        $display("[%0t ns] Reset...", $time);
        repeat(100) @(posedge clk2);
        rstn = 1;
        repeat(100) @(posedge clk2);
        $display("[%0t ns] Reset complete\n", $time);
        
        // ===================================================================
        // PHASE 1: Coefficient Loading (measures control path power)
        // ===================================================================
        $display("[%0t ns] Phase 1: Loading coefficients...", $time);
        for (i = 0; i < 64; i = i + 1) begin
            @(posedge clk2);
            #1;
            cload = 1;
            caddr = i[5:0];
            cin = $random;  // Random coefficients for realistic switching
        end
        @(posedge clk2);
        #1;
        cload = 0;
        repeat(10) @(posedge clk2);
        
        // ===================================================================
        // PHASE 2: Processing 20 samples (measures datapath power)
        // ===================================================================
        $display("[%0t ns] Phase 2: Processing 20 samples...", $time);
        for (i = 0; i < 20; i = i + 1) begin
            @(posedge clk1);
            #1;
            din = $random;  // Random input for realistic activity
            valid_in = 1;
            @(posedge clk1);
            #1;
            valid_in = 0;
            
            // Wait for output
            wait(valid_out == 1);
            @(posedge clk2);
            repeat(2) @(posedge clk2);
        end
        
        $display("[%0t ns] Processing complete\n", $time);
        
        // ===================================================================
        // PHASE 3: Idle period (measures leakage power)
        // ===================================================================
        $display("[%0t ns] Phase 3: Idle period...", $time);
        repeat(1000) @(posedge clk2);
        
        $display("\n========================================");
        $display("VCD Generation Complete");
        $display("========================================");
        $display("File: power_analysis.vcd");
        $display("Duration: %0t ns", $time);
        $display("Use this VCD with PrimeTime PX or similar\n");
        
        #10000;
        $finish;
    end


endmodule
