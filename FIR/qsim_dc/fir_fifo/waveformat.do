onerror {resume}
quietly WaveActivateNextPane {} 0

# ============================================================================
# ASYNC FIFO Waveform Configuration

# ============================================================================
# Clock & Reset (Both Domains)
# ============================================================================
add wave -noupdate -divider "Clocks & Resets"
add wave -noupdate /testbench/clk1
add wave -noupdate /testbench/rstn1
add wave -noupdate /testbench/clk2
add wave -noupdate /testbench/rstn2

# ============================================================================
# Write Interface (clk1 domain - 10 kHz)
# ============================================================================
add wave -noupdate -divider "Write Interface"
add wave -noupdate /testbench/wen
add wave -noupdate -radix decimal /testbench/din
add wave -noupdate /testbench/full

# ============================================================================
# Read Interface (clk2 domain - 100 MHz)
# ============================================================================
add wave -noupdate -divider "Read Interface"
add wave -noupdate /testbench/ren
add wave -noupdate -radix decimal /testbench/dout
add wave -noupdate /testbench/empty

# ============================================================================
#Concurrent Test
# ============================================================================
add wave -noupdate -divider "Test 3: Concurrent Test"
add wave -noupdate -radix decimal /testbench/concurrent_write_idx
add wave -noupdate -radix decimal /testbench/concurrent_read_idx
add wave -noupdate -radix decimal /testbench/concurrent_shadow(0)
add wave -noupdate -radix decimal /testbench/concurrent_shadow(1)
add wave -noupdate -radix decimal /testbench/concurrent_shadow(2)
add wave -noupdate -radix decimal /testbench/concurrent_shadow(3)
add wave -noupdate -radix decimal /testbench/concurrent_shadow(4)
add wave -noupdate -radix decimal /testbench/concurrent_shadow(5)
add wave -noupdate -radix decimal /testbench/concurrent_shadow(6)
add wave -noupdate -radix decimal /testbench/concurrent_shadow(7)

# ============================================================================
# Testbench Verification
# ============================================================================
add wave -noupdate -divider "Testbench Status"
add wave -noupdate -radix decimal /testbench/write_count
add wave -noupdate -radix decimal /testbench/read_count
add wave -noupdate -radix decimal /testbench/mismatches

TreeUpdate [SetDefaultTree]
WaveRestoreCursors {{Cursor 1} {0 ns} 0}
quietly wave cursor active 1
configure wave -namecolwidth 300
configure wave -valuecolwidth 100
configure wave -justifyvalue left
configure wave -signalnamewidth 0
configure wave -snapdistance 10
configure wave -datasetprefix 0
configure wave -rowmargin 4
configure wave -childrowmargin 2
configure wave -gridoffset 0
configure wave -gridperiod 1
configure wave -griddelta 40
configure wave -timeline 0
configure wave -timelineunits ns
update
WaveRestoreZoom {0 ns} {500000 ns}
