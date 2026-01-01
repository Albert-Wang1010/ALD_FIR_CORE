## Timing constraints for CMEM post-synthesis PrimeTime analysis
## The unit for time is ns as defined in the IBM delay-power library
## The unit for wireload is pF as defined in the IBM delay-power library
###################################################################### 

# Setting variables for 100 MHz operation
# Increased margins for post-synthesis analysis
set clk_period 10.00
set clk_uncertainty 0.25
set clk_transition 0.15
set typical_input_delay 1.0
set typical_output_delay 1.0
set typical_wire_load 0.010

# Create clock - CMEM uses clk2 port
if {[sizeof_collection [get_ports clk2]] > 0} {
  set clk_name "clk2"
  set clk_port "clk2"
  create_clock -name $clk_name -period $clk_period [get_ports $clk_port] 
}

# Set clock uncertainty (jitter + skew)
set_clock_uncertainty $clk_uncertainty [get_clocks $clk_name]

# Set clock transition (rise/fall time)
set_clock_transition $clk_transition [get_clocks $clk_name]

# Set input and output delays
set_driving_cell -lib_cell INVX1TS [all_inputs]
set_input_delay $typical_input_delay [all_inputs] -clock $clk_name 
remove_input_delay -clock $clk_name [find port $clk_port]

# Don't constrain async reset
if {[sizeof_collection [get_ports rstn]] > 0} {
  remove_input_delay -clock $clk_name [get_ports rstn]
  set_false_path -from [get_ports rstn]
}

# Output delay
set_output_delay $typical_output_delay [all_outputs] -clock $clk_name 

# Set loading of outputs 
set_load $typical_wire_load [all_outputs]

# Multi-cycle path for write control during preload
# cload signal is stable for multiple cycles
set_multicycle_path 2 -setup -from [get_ports cload]
set_multicycle_path 1 -hold -from [get_ports cload]
