##################################################
#  Modelsim do file to run simulation
##################################################

vlib work 
vmap work work

# Include Netlist and Testbench
vlog +acc -incr ../../rtl/fir_core/fir_core.v 
vlog +acc -incr test_fir_core.v 

# Run Simulator 
vsim +acc -t ps -lib work testbench 
do waveformat.do   
run -all
