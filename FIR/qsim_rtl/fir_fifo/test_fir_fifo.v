`timescale 1ns / 1ps

module testbench;

    parameter WIDTH = 16;
    parameter DEPTH = 64;
    parameter ADDR_W = 6;
    
    // Clock periods
    parameter CLK1_PERIOD = 100000;  // 10 kHz = 100 µs = 100,000 ns
    parameter CLK2_PERIOD = 10;      // 100 MHz = 10 ns
    
    // Phase offset between clocks (arbitrary, as per assignment)
    parameter PHASE_OFFSET = 3;      // 3 ns offset between clk1 and clk2
    
    // Signals
    
    // Write clock domain (clk1 - 10 kHz)
    reg                     clk1;
    reg                     rstn1;
    reg                     wen;
    reg signed [WIDTH-1:0]  din;
    wire                    full;
    
    // Read clock domain (clk2 - 100 MHz)
    reg                     clk2;
    reg                     rstn2;
    reg                     ren;
    wire signed [WIDTH-1:0] dout;
    wire                    empty;
    
    // Testbench control
    integer i;
    integer mismatches;
    
    // Shadow memory for verification (golden reference)
    reg signed [WIDTH-1:0] shadow_fifo [0:DEPTH-1];
    integer write_count;
    integer read_count;
    integer expected_count;
    
    // Phase 3 concurrent test tracking
    reg signed [WIDTH-1:0] concurrent_shadow [0:15];  // Extra space for concurrent writes
    integer concurrent_write_idx;
    integer concurrent_read_idx;

    // DUT Instantiation
    fir_fifo dut (
        // Write clock domain
        .clk1(clk1),
        .rstn1(rstn1),
        .wen(wen),
        .din(din),
        .full(full),
        
        // Read clock domain
        .clk2(clk2),
        .rstn2(rstn2),
        .ren(ren),
        .dout(dout),
        .empty(empty)
    );
    

    // Clock Generation
    
    // clk1: 10 kHz (100 µs period)
    initial begin
        clk1 = 0;
        #PHASE_OFFSET;  // Apply phase offset
        forever #(CLK1_PERIOD/2) clk1 = ~clk1;
    end
    
    // clk2: 100 MHz (10 ns period)
    initial begin
        clk2 = 0;
        forever #(CLK2_PERIOD/2) clk2 = ~clk2;
    end
    
    // VCD Dump for Waveform Analysis
    /*initial begin
      $dumpfile("fir_fifo.vcd");
        $dumpvars(0, testbench);
    end*/
    
    // Test Stimulus
  
    initial begin
        // Initialize signals
        rstn1 = 0;
        rstn2 = 0;
        wen = 0;
        ren = 0;
        din = 0;
        mismatches = 0;
        write_count = 0;
        read_count = 0;
        expected_count = 0;
        concurrent_write_idx = 0;
        concurrent_read_idx = 0;
        
        // Initialize shadow FIFO
        for (i = 0; i < DEPTH; i = i + 1) begin
            shadow_fifo[i] = 0;
        end
        
        $display("========================================");
        $display("Asynchronous FIFO/Synchronizer Test");
        $display("========================================");
        $display("clk1 frequency: 10 kHz (100 us period)");
        $display("clk2 frequency: 100 MHz (10 ns period)");
        $display("FIFO depth: %0d entries", DEPTH);
        $display("Data width: %0d bits (signed)", WIDTH);
        $display("Phase offset: %0d ns", PHASE_OFFSET);
        $display("========================================\n");
        
        // Apply reset
        $display("[%0t ns] Applying reset...", $time);
        #(CLK2_PERIOD * 5);
        rstn1 = 1;
        rstn2 = 1;
        #(CLK2_PERIOD * 5);
        $display("[%0t ns] Reset released\n", $time);
        

        // Test 1: Write to FIFO until full
      
        $display("========================================");
        $display("Test 1: Write %0d entries to FIFO", DEPTH);
        $display("========================================");
        
        for (i = 0; i < DEPTH; i = i + 1) begin
            @(posedge clk1);
            #1;  // Small delay after clock edge
            
            if (!full) begin
                wen = 1;
                din = $random;  // Random signed data
                shadow_fifo[write_count] = din;
                
                $display("[%0t ns] Write[%0d]: din = %0d", 
                         $time, write_count, din);
                
                write_count = write_count + 1;
            end else begin
                $display("[%0t ns] ERROR: FIFO full unexpectedly at entry %0d", $time, i);
            end
            
            @(posedge clk1);
            #1;
            wen = 0;
            
            // Wait a few clk1 cycles
            repeat(2) @(posedge clk1);
        end
        
        $display("\n[%0t ns] Wrote %0d entries to FIFO", $time, write_count);
        $display("[%0t ns] FIFO full flag = %0b (expected: 1)\n", $time, full);
        
        // Wait for synchronization to complete
        repeat(5) @(posedge clk2);
        
        // Test 2: Read from FIFO and verify data

        $display("========================================");
        $display("Test 2: Read and verify %0d entries", write_count);
        $display("========================================");
        
        for (i = 0; i < write_count; i = i + 1) begin
            @(posedge clk2);
            #1;
            
            if (!empty) begin
                ren = 1;
                
                @(posedge clk2);  // Data is captured and pointer increments
                #1;
                ren = 0;
                
                // Verify data (dout is now valid)
                if (dout === shadow_fifo[read_count]) begin
                    $display("[%0t ns] Read[%0d]: actual = %0d, expected = %0d - MATCH", 
                             $time, read_count, dout, shadow_fifo[read_count]);
                end else begin
                    $display("[%0t ns] Read[%0d]: actual = %0d, expected = %0d - MISMATCH! ✗", 
                             $time, read_count, dout, shadow_fifo[read_count]);
                    mismatches = mismatches + 1;
                end
                
                read_count = read_count + 1;
                
            end else begin
                $display("[%0t ns] ERROR: FIFO empty unexpectedly at read %0d", $time, i);
            end
            
            // Wait a few clk2 cycles
            repeat(3) @(posedge clk2);
        end
        
        $display("\n[%0t ns] Read %0d entries from FIFO", $time, read_count);
        $display("[%0t ns] FIFO empty flag = %0b (expected: 1)\n", $time, empty);
        
        // Wait for empty flag to update
        repeat(10) @(posedge clk2);
        
        // CRITICAL: Wait for read pointer to synchronize back to write domain!
        // This takes 2+ clk1 cycles for the 2-FF synchronizer
        repeat(3) @(posedge clk1);
        repeat(5) @(posedge clk2);
        
        // Test 3: Concurrent read/write operation

        $display("========================================");
        $display("Test 3: Concurrent Read/Write Test");
        $display("========================================");
        
        // Write a few entries first to have data in FIFO
        $display("\n--- Phase 3a: Initial writes ---");
        
        for (i = 0; i < 16; i = i + 1) begin
            @(posedge clk1);
            #1;  // Small delay after clock edge
            
            wen = 1;
            din = $random;
            concurrent_shadow[concurrent_write_idx] = din;
            $display("[%0t ns] Write[%0d]: din = %0d", 
                     $time, concurrent_write_idx, din);
            concurrent_write_idx = concurrent_write_idx + 1;
            
            @(posedge clk1);  // Write happens on THIS edge
            #1;
            wen = 0;
            
            // Wait a few clk1 cycles (like Test 1)
            repeat(2) @(posedge clk1);
        end
        
        // Wait for synchronization
        $display("\n[%0t ns] Waiting for CDC synchronization...", $time);
        repeat(3) @(posedge clk1);  // Wait for write pointer Gray code to propagate
        repeat(10) @(posedge clk2); // Wait for synchronization to read domain
        
        // Now read and write concurrently
        $display("\n--- Phase 3b: Concurrent read/write ---");
        fork
            // Write process (slower - 10 kHz)
            begin
                for (i = 0; i < 8; i = i + 1) begin
                    @(posedge clk1);
                    #1;
                    if (!full) begin
                        wen = 1;
                        din = $random;
                        concurrent_shadow[concurrent_write_idx] = din;
                        $display("[%0t ns] Concurrent Write[%0d]: din = %0d", 
                                 $time, concurrent_write_idx, din);
                        concurrent_write_idx = concurrent_write_idx + 1;
                        @(posedge clk1);
                        #1;
                        wen = 0;
                    end
                    repeat(5) @(posedge clk1);
                end
            end
            
            // Read process (faster - 100 MHz)
            begin
                for (i = 0; i < 16; i = i + 1) begin
                    // Wait until FIFO has data
                    while (empty) begin
                        @(posedge clk2);
                    end
                    
                    // Now wait for the next clock edge and assert ren
                    // (This matches Test 2 timing exactly)
                    @(posedge clk2);
                    #1;
                    ren = 1;
                    
                    // Data is captured on NEXT edge, pointer increments
                    @(posedge clk2);
                    #1;
                    ren = 0;
                    
                    // Verify concurrent read (dout is now valid)
                    if (dout === concurrent_shadow[concurrent_read_idx]) begin
                        $display("[%0t ns] Concurrent Read[%0d]: actual = %0d, expected = %0d - MATCH", 
                                 $time, concurrent_read_idx, dout, concurrent_shadow[concurrent_read_idx]);
                    end else begin
                        $display("[%0t ns] Concurrent Read[%0d]: actual = %0d, expected = %0d - MISMATCH!", 
                                 $time, concurrent_read_idx, dout, concurrent_shadow[concurrent_read_idx]);
                        mismatches = mismatches + 1;
                    end
                    concurrent_read_idx = concurrent_read_idx + 1;
                    
                    repeat(3) @(posedge clk2);
                end
            end
        join
        
        $display("\n[%0t ns] Concurrent read/write test complete", $time);
        $display("[%0t ns] Total concurrent writes: %0d", $time, concurrent_write_idx);
        $display("[%0t ns] Total concurrent reads: %0d", $time, concurrent_read_idx);
        

        // Test Summary

        repeat(20) @(posedge clk2);
        
        $display("\n========================================");
        $display("Test Summary");
        $display("========================================");
        $display("Total writes: %0d", write_count);
        $display("Total reads: %0d", read_count);
        $display("Data mismatches: %0d", mismatches);
        $display("========================================");
        
        if (mismatches == 0) begin
          $display("\n*** FIR_FIFO test PASSED ***\n");
        end else begin
          $display("\n*** FIR_FIFO test FAILED ***");
            $display("    %0d mismatches detected\n", mismatches);
        end
        
        $display("Simulation completed at %0t ns\n", $time);
        
        // End simulation
        #1000;
        $finish;
    end
    

    // Timeout Watch
    initial begin
        #100000000;  // 100 ms timeout (sufficient for 64 entries at 10 kHz)
        $display("\n*** ERROR: Simulation timeout! ***\n");
        $finish;
    end

endmodule
