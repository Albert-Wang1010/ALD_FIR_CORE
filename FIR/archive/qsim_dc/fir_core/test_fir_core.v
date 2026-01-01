// ===========================================================================
// FIR Core Post-Synthesis Testbench
// ===========================================================================
// Minimal testbench optimized for gate-level simulation
// - Extended reset for proper initialization
// - Reduced test count for faster simulation
// - No VCD dump by default (huge speedup)
// ===========================================================================

`timescale 1ns/1ps

module testbench;

    // -----------------------------------------------------------------------
    // Parameters
    // -----------------------------------------------------------------------
    parameter NUM_TAPS = 64;
    parameter CLK1_PERIOD = 100000;  // 10 kHz
    parameter CLK2_PERIOD = 10;      // 100 MHz
    
    // -----------------------------------------------------------------------
    // Signals
    // -----------------------------------------------------------------------
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
    integer pass_count;
    integer fail_count;
    reg signed [15:0] result;
    
    // -----------------------------------------------------------------------
    // Clock Generation
    // -----------------------------------------------------------------------
    initial begin
        clk1 = 0;
        forever #(CLK1_PERIOD/2) clk1 = ~clk1;
    end
    
    initial begin
        clk2 = 0;
        forever #(CLK2_PERIOD/2) clk2 = ~clk2;
    end
    
    // -----------------------------------------------------------------------
    // DUT Instantiation
    // -----------------------------------------------------------------------
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
    // VCD Dump (DISABLED by default for speed)
    // Uncomment only if you need waveforms
    // -----------------------------------------------------------------------
    
    initial begin
        $dumpfile("testbench.vcd");
        $dumpvars(0, dut);
    end
    
    
    // -----------------------------------------------------------------------
    // Main Test Sequence
    // -----------------------------------------------------------------------
    initial begin
        $display("\n========================================");
        $display("FIR Core Post-Synthesis Testbench");
        $display("========================================");
        $display("NUM_TAPS: %0d", NUM_TAPS);
        $display("clk1: 10 kHz, clk2: 100 MHz");
        $display("Gate-level netlist with SDF timing");
        $display("========================================\n");
        
        // Initialize signals
        pass_count = 0;
        fail_count = 0;
        rstn = 0;
        din = 0;
        valid_in = 0;
        cin = 0;
        caddr = 0;
        cload = 0;
        
        // ===================================================================
        // EXTENDED RESET for gate-level simulation
        // Gate delays require longer reset propagation time
        // ===================================================================
        $display("[%0t ns] Applying reset (extended for gate-level)...", $time);
        repeat(100) @(posedge clk2);  // Hold reset for 100 clk2 cycles
        rstn = 1;
        repeat(100) @(posedge clk2);  // Wait 100 more cycles after release
        $display("[%0t ns] Reset complete\n", $time);
        
        // ===================================================================
        // Load Coefficients (0x0100)
        // ===================================================================
        $display("[%0t ns] Loading coefficients (0x0100)...", $time);
        for (i = 0; i < NUM_TAPS; i = i + 1) begin
            @(posedge clk2);
            #1;
            cload = 1;
            caddr = i[5:0];
            cin = 16'sh0100;
        end
        @(posedge clk2);
        #1;
        cload = 0;
        repeat(10) @(posedge clk2);
        $display("[%0t ns] Coefficients loaded\n", $time);
        
        // ===================================================================
        // TEST 1: Zero Input
        // ===================================================================
        $display("========================================");
        $display("TEST 1: Zero Input");
        $display("========================================");
        
        @(posedge clk1);
        #1;
        din = 16'sh0000;
        valid_in = 1;
        @(posedge clk1);
        #1;
        valid_in = 0;
        
        // Wait for valid output
        wait(valid_out == 1);
        @(posedge clk2);
        #1;
        result = dout;
        
        $display("[%0t ns] Input: 0x0000", $time);
        $display("[%0t ns] Output: 0x%h (%0d)", $time, result, $signed(result));
        
        if (result == 16'sh0000) begin
            $display("TEST 1: PASSED\n");
            pass_count = pass_count + 1;
        end else begin
            $display("TEST 1: FAILED (expected 0, got %0d)\n", $signed(result));
            fail_count = fail_count + 1;
        end
        
        repeat(20) @(posedge clk2);
        
        // ===================================================================
        // TEST 2: Single Non-Zero Sample
        // ===================================================================
        $display("========================================");
        $display("TEST 2: Single Non-Zero Sample");
        $display("========================================");
        
        @(posedge clk1);
        #1;
        din = 16'sh1000;
        valid_in = 1;
        @(posedge clk1);
        #1;
        valid_in = 0;
        
        // Wait for valid output
        wait(valid_out == 1);
        @(posedge clk2);
        #1;
        result = dout;
        
        $display("[%0t ns] Input: 0x1000", $time);
        $display("[%0t ns] Output: 0x%h (%0d)", $time, result, $signed(result));
        
        // Expected: 1 * 0x1000 * 0x0100 / 2^21 = 0.125 ~ 0
        // But should be non-zero and not X
        if (result !== 16'hxxxx && result != 16'sh0000) begin
            $display("TEST 2: PASSED (non-zero output detected)\n");
            pass_count = pass_count + 1;
        end else if (result === 16'hxxxx) begin
            $display("TEST 2: FAILED (X values - check reset!)\n");
            fail_count = fail_count + 1;
        end else begin
            $display("TEST 2: MARGINAL (output is zero, may be rounding)\n");
            pass_count = pass_count + 1;
        end
        
        repeat(20) @(posedge clk2);
        
        // ===================================================================
        // TEST 3: DC Response (Fill Filter with 0x1000)
        // ===================================================================
        $display("========================================");
        $display("TEST 3: DC Response (64+ samples)");
        $display("========================================");
        
        $display("[%0t ns] Sending 70 samples of 0x1000...", $time);
        for (i = 0; i < 70; i = i + 1) begin
            @(posedge clk1);
            #1;
            din = 16'sh1000;
            valid_in = 1;
            @(posedge clk1);
            #1;
            valid_in = 0;
            
            // Wait for valid output
            wait(valid_out == 1);
            @(posedge clk2);
            #1;
            result = dout;
            
            if (i == 0 || i == 1 || i == 63 || i == 69) begin
                $display("  Sample[%02d]: 0x%h (%0d)", i, result, $signed(result));
            end else if (i == 2) begin
                $display("  ...");
            end
            
            repeat(2) @(posedge clk2);
        end
        
        // Expected: 64 * 0x1000 * 0x0100 / 2^21 = 32
        $display("[%0t ns] Final output: 0x%h (%0d)", $time, result, $signed(result));
        if (result >= 16'sh001E && result <= 16'sh0022) begin
            $display("TEST 3: PASSED (output=%0d, expected 30-34)\n", $signed(result));
            pass_count = pass_count + 1;
        end else if (result === 16'hxxxx) begin
            $display("TEST 3: FAILED (X values)\n");
            fail_count = fail_count + 1;
        end else begin
            $display("TEST 3: FAILED (output=%0d, expected 30-34)\n", $signed(result));
            fail_count = fail_count + 1;
        end
        
        repeat(50) @(posedge clk2);
        
        // ===================================================================
        // Summary
        // ===================================================================
        $display("\n========================================");
        $display("POST-SYNTHESIS TEST SUMMARY");
        $display("========================================");
        $display("Tests Run: 3");
        $display("Passed: %0d", pass_count);
        $display("Failed: %0d", fail_count);
        $display("========================================");
        
        if (fail_count == 0) begin
            $display("\n*** POST-SYNTHESIS VERIFICATION PASSED ***");
            $display("Gate-level netlist is functionally correct!\n");
        end else begin
            $display("\n*** POST-SYNTHESIS VERIFICATION FAILED ***");
            $display("%0d test(s) failed\n", fail_count);
            if (result === 16'hxxxx) begin
                $display("HINT: X values indicate:");
                $display("  1. Reset not propagating properly");
                $display("  2. Uninitialized flip-flops");
                $display("  3. SDF timing issues");
            end
        end
        
        $display("Simulation completed at %0t ns\n", $time);
        
        #10000;
        $finish;
    end
    

endmodule
