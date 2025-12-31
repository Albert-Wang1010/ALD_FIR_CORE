onerror {resume}
quietly WaveActivateNextPane {} 0

# ============================================================================
# FIR Core Post-Synthesis Waveform Configuration
# ============================================================================

# ============================================================================
# Clock & Reset
# ============================================================================
add wave -noupdate -divider "Clocks & Resets"
add wave -noupdate /testbench/clk1
add wave -noupdate /testbench/clk2
add wave -noupdate /testbench/rstn

# ============================================================================
# Input Interface (clk1 domain)
# ============================================================================
add wave -noupdate -divider "Input Interface"
add wave -noupdate /testbench/valid_in
add wave -noupdate -radix hexadecimal /testbench/din
add wave -noupdate -radix decimal /testbench/din

# ============================================================================
# Coefficient Loading (clk2 domain)
# ============================================================================
add wave -noupdate -divider "Coefficient Loading"
add wave -noupdate /testbench/cload
add wave -noupdate -radix unsigned /testbench/caddr
add wave -noupdate -radix hexadecimal /testbench/cin
add wave -noupdate -radix decimal /testbench/cin

# ============================================================================
# Output Interface (clk2 domain)
# ============================================================================
add wave -noupdate -divider "Output Interface"
add wave -noupdate /testbench/valid_out
add wave -noupdate -radix hexadecimal /testbench/dout
add wave -noupdate -radix decimal /testbench/dout

# ============================================================================
# Test Control
# ============================================================================
add wave -noupdate -divider "Test Control"
add wave -noupdate -radix unsigned /testbench/test_num
add wave -noupdate -radix unsigned /testbench/pass_count
add wave -noupdate -radix unsigned /testbench/fail_count

# ============================================================================
# DUT Top-Level Signals ONLY (no internal hierarchy in gate-level)
# ============================================================================
add wave -noupdate -divider "DUT Inputs"
add wave -noupdate /testbench/dut/clk1
add wave -noupdate /testbench/dut/clk2
add wave -noupdate /testbench/dut/rstn
add wave -noupdate /testbench/dut/valid_in
add wave -noupdate -radix hexadecimal /testbench/dut/din
add wave -noupdate /testbench/dut/cload
add wave -noupdate -radix unsigned /testbench/dut/caddr
add wave -noupdate -radix hexadecimal /testbench/dut/cin

add wave -noupdate -divider "DUT Outputs"
add wave -noupdate /testbench/dut/valid_out
add wave -noupdate -radix hexadecimal /testbench/dut/dout

# NOTE: Cannot access internal signals (u_alu, u_fsm, etc.) in gate-level
# All internal hierarchy is flattened to gates

# ============================================================================
# Waveform Display Configuration
# ============================================================================
TreeUpdate [SetDefaultTree]
WaveRestoreCursors {{Cursor 1} {0 ns} 0}
quietly wave cursor active 1
configure wave -namecolwidth 350
configure wave -valuecolwidth 120
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
WaveRestoreZoom {0 ns} {1000000 ns}
