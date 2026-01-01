######################################################################
# PrimeTime Timing Constraints for FIR Core
######################################################################
# Simplified from DC timing.tcl - removed synthesis-specific commands
######################################################################

######################################################################
# Clock Definitions
######################################################################
# clk1: Input sampling clock (10 kHz)
create_clock -name clk1 -period 100000 [get_ports clk1]

# clk2: Processing clock (100 MHz)
create_clock -name clk2 -period 10 [get_ports clk2]

# Mark clocks as asynchronous (no relationship)
set_clock_groups -asynchronous -group {clk1} -group {clk2}

# Clock uncertainty (jitter/skew)
set_clock_uncertainty -setup 0.2 [get_clocks clk1]
set_clock_uncertainty -hold 0.05 [get_clocks clk1]
set_clock_uncertainty -setup 0.2 [get_clocks clk2]
set_clock_uncertainty -hold 0.05 [get_clocks clk2]

# Clock transition time
set_clock_transition 0.1 [get_clocks clk1]
set_clock_transition 0.1 [get_clocks clk2]

######################################################################
# Reset Constraints
######################################################################
# Reset is asynchronous - no timing check needed
set_false_path -from [get_ports rstn]

######################################################################
# Input Delays
######################################################################
# clk1 domain inputs (10 kHz - slow)
set_input_delay -clock clk1 -max 10000 [get_ports {valid_in din[*]}]
set_input_delay -clock clk1 -min 0 [get_ports {valid_in din[*]}]

# clk2 domain inputs (100 MHz - fast)
set_input_delay -clock clk2 -max 1.0 [get_ports {cload caddr[*] cin[*]}]
set_input_delay -clock clk2 -min 0 [get_ports {cload caddr[*] cin[*]}]

######################################################################
# Output Delays
######################################################################
# clk2 domain outputs
set_output_delay -clock clk2 -max 0.5 [get_ports {dout[*] valid_out}]
set_output_delay -clock clk2 -min 0 [get_ports {dout[*] valid_out}]

######################################################################
# Clock Domain Crossing (CDC) Constraints
######################################################################
# Gray code synchronizers in FIFO - mark as false paths
# Write pointer: clk1 -> clk2
if {[sizeof_collection [get_pins -hierarchical *wptr_gray_reg*/Q]] > 0} {
  if {[sizeof_collection [get_pins -hierarchical *wptr_gray_sync1_reg*/D]] > 0} {
    set_false_path -from [get_pins -hierarchical *wptr_gray_reg*/Q] \
                   -to [get_pins -hierarchical *wptr_gray_sync1_reg*/D]
  }
}

# Read pointer: clk2 -> clk1  
if {[sizeof_collection [get_pins -hierarchical *rptr_gray_reg*/Q]] > 0} {
  if {[sizeof_collection [get_pins -hierarchical *rptr_gray_sync1_reg*/D]] > 0} {
    set_false_path -from [get_pins -hierarchical *rptr_gray_reg*/Q] \
                   -to [get_pins -hierarchical *rptr_gray_sync1_reg*/D]
  }
}

######################################################################
# Multi-Cycle Paths
######################################################################
# FSM states are stable for multiple cycles during MAC operation
if {[sizeof_collection [get_pins -hierarchical u_fsm/state_reg*/Q]] > 0} {
  set_multicycle_path 2 -setup -from [get_pins -hierarchical u_fsm/state_reg*/Q]
  set_multicycle_path 1 -hold  -from [get_pins -hierarchical u_fsm/state_reg*/Q]
}

######################################################################
# Operating Conditions
######################################################################
set_operating_conditions -max tt_1p2v_25c -max_library scx3_cmos8rf_lpvt_tt_1p2v_25c
