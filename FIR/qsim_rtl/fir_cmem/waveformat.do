onerror {resume}
quietly WaveActivateNextPane {} 0

# TB level - timing & control
add wave -noupdate -divider "Clock & Reset"
add wave -noupdate /testbench/clk2
add wave -noupdate /testbench/rstn

# Write port (preload)
add wave -noupdate -divider "Write Port"
add wave -noupdate /testbench/cload
add wave -noupdate -radix unsigned /testbench/caddr
add wave -noupdate -radix signed /testbench/cin

# Read port (control)
add wave -noupdate -divider "Read Port"
add wave -noupdate /testbench/ren
add wave -noupdate -radix unsigned /testbench/raddr

# Expected vs Actual Comparison
add wave -noupdate -divider "Data Comparison"
add wave -noupdate -radix signed /testbench/cout 

# Verification
add wave -noupdate -divider "Testbench Status"
add wave -noupdate -radix decimal /testbench/i
add wave -noupdate -radix decimal /testbench/mismatches

# To inspect expected values, expand the shadow array below
add wave -noupdate -divider "Expected Data (Shadow Memory)"
add wave -noupdate -radix signed /testbench/shadow

TreeUpdate [SetDefaultTree]
WaveRestoreCursors {{Cursor 1} {3 ns} 0}
quietly wave cursor active 1
configure wave -namecolwidth 223
configure wave -valuecolwidth 89
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
configure wave -timelineunits ps
update
WaveRestoreZoom {0 ns} {12 ns}


