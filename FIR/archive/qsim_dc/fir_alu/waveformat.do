onerror {resume}
quietly WaveActivateNextPane {} 0

#TB level
add wave -noupdate /testbench/clk
add wave -noupdate /testbench/rstn
add wave -noupdate /testbench/en_mac
add wave -noupdate /testbench/clr_acc
add wave -noupdate -radix signed /testbench/a_q15
add wave -noupdate -radix signed /testbench/b_q15
add wave -noupdate -radix signed /testbench/exp_acc
add wave -noupdate -radix signed /testbench/exp_next

# DUT
add wave -noupdate -radix signed /testbench/dut/prod_q30
add wave -noupdate -radix signed /testbench/dut/acc_out
add wave -noupdate -radix signed /testbench/dut/y_q7_9
add wave -noupdate               /testbench/dut/y_saturated

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


