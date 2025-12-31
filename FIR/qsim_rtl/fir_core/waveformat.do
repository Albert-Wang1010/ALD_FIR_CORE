onerror {resume}
quietly WaveActivateNextPane {} 0

# ============================================================================
# FIR Core Waveform Configuration - Tests 1-10
# Use for both pre-synthesis (RTL) and post-synthesis (gate-level) simulation
# ============================================================================

# ============================================================================
# Clock & Reset
# ============================================================================
add wave -noupdate -divider "Clocks & Resets"
add wave -noupdate /testbench/clk1
add wave -noupdate /testbench/clk2
add wave -noupdate /testbench/rstn

# ============================================================================
# Input Interface (clk1 domain - 10 kHz)
# ============================================================================
add wave -noupdate -divider "Input Interface"
add wave -noupdate /testbench/valid_in
add wave -noupdate -radix hexadecimal /testbench/din
add wave -noupdate -radix decimal /testbench/din

# ============================================================================
# Coefficient Loading Interface (clk2 domain - 100 MHz)
# ============================================================================
add wave -noupdate -divider "Coefficient Loading"
add wave -noupdate /testbench/cload
add wave -noupdate -radix unsigned /testbench/caddr
add wave -noupdate -radix hexadecimal /testbench/cin
add wave -noupdate -radix decimal /testbench/cin

# ============================================================================
# Output Interface (clk2 domain - 100 MHz)
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
add wave -noupdate -radix unsigned /testbench/i

# ============================================================================
# DUT Internal Signals (RTL only - comment out for gate-level)
# ============================================================================

# ---------- FIFO Signals ----------
add wave -noupdate -divider "FIFO (Input Clock Domain Crossing)"
add wave -noupdate /testbench/dut/fifo_wen
add wave -noupdate -radix hexadecimal /testbench/dut/fifo_din
add wave -noupdate /testbench/dut/fifo_full
add wave -noupdate /testbench/dut/fifo_ren
add wave -noupdate -radix hexadecimal /testbench/dut/fifo_dout
add wave -noupdate /testbench/dut/fifo_empty

# ---------- FSM Signals ----------
add wave -noupdate -divider "FSM Control"
add wave -noupdate /testbench/dut/u_fsm/state
add wave -noupdate -radix unsigned /testbench/dut/u_fsm/tap_counter
add wave -noupdate -radix unsigned /testbench/dut/u_fsm/write_pointer
add wave -noupdate -radix unsigned /testbench/dut/u_fsm/read_pointer

# ---------- Coefficient Memory ----------
add wave -noupdate -divider "Coefficient Memory (First 8)"
add wave -noupdate -radix hexadecimal /testbench/dut/u_cmem/mem(0)
add wave -noupdate -radix hexadecimal /testbench/dut/u_cmem/mem(1)
add wave -noupdate -radix hexadecimal /testbench/dut/u_cmem/mem(2)
add wave -noupdate -radix hexadecimal /testbench/dut/u_cmem/mem(3)
add wave -noupdate -radix hexadecimal /testbench/dut/u_cmem/mem(4)
add wave -noupdate -radix hexadecimal /testbench/dut/u_cmem/mem(5)
add wave -noupdate -radix hexadecimal /testbench/dut/u_cmem/mem(6)
add wave -noupdate -radix hexadecimal /testbench/dut/u_cmem/mem(7)

# ---------- Data Regfile (Circular Buffer) ----------
add wave -noupdate -divider "Regfile (Circular Buffer - First 8)"
add wave -noupdate -radix hexadecimal /testbench/dut/u_regfile/mem(0)
add wave -noupdate -radix hexadecimal /testbench/dut/u_regfile/mem(1)
add wave -noupdate -radix hexadecimal /testbench/dut/u_regfile/mem(2)
add wave -noupdate -radix hexadecimal /testbench/dut/u_regfile/mem(3)
add wave -noupdate -radix hexadecimal /testbench/dut/u_regfile/mem(4)
add wave -noupdate -radix hexadecimal /testbench/dut/u_regfile/mem(5)
add wave -noupdate -radix hexadecimal /testbench/dut/u_regfile/mem(6)
add wave -noupdate -radix hexadecimal /testbench/dut/u_regfile/mem(7)

# ---------- ALU Signals ----------
add wave -noupdate -divider "ALU (MAC Unit)"
add wave -noupdate /testbench/dut/alu_en_mac
add wave -noupdate /testbench/dut/alu_clr_acc
add wave -noupdate -radix hexadecimal /testbench/dut/u_alu/a_q15
add wave -noupdate -radix hexadecimal /testbench/dut/u_alu/b_q15
add wave -noupdate -radix hexadecimal /testbench/dut/u_alu/prod_q30
add wave -noupdate -radix hexadecimal /testbench/dut/u_alu/acc_out
add wave -noupdate -radix hexadecimal /testbench/dut/u_alu/acc_shift
add wave -noupdate -radix hexadecimal /testbench/dut/u_alu/y_q7_9
add wave -noupdate -radix decimal /testbench/dut/u_alu/y_q7_9
add wave -noupdate /testbench/dut/u_alu/y_saturated

# ---------- Regfile Last 8 Entries (for wrap-around) ----------
add wave -noupdate -divider "Regfile (Last 8 - for wrap check)"
add wave -noupdate -radix hexadecimal /testbench/dut/u_regfile/mem(56)
add wave -noupdate -radix hexadecimal /testbench/dut/u_regfile/mem(57)
add wave -noupdate -radix hexadecimal /testbench/dut/u_regfile/mem(58)
add wave -noupdate -radix hexadecimal /testbench/dut/u_regfile/mem(59)
add wave -noupdate -radix hexadecimal /testbench/dut/u_regfile/mem(60)
add wave -noupdate -radix hexadecimal /testbench/dut/u_regfile/mem(61)
add wave -noupdate -radix hexadecimal /testbench/dut/u_regfile/mem(62)
add wave -noupdate -radix hexadecimal /testbench/dut/u_regfile/mem(63)

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
