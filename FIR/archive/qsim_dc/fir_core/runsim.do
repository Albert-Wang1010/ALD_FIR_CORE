##################################################
# ModelSim do file for POST-SYNTHESIS simulation
##################################################

# Setup
vlib work 
vmap work work

# Include Technology Library, Gate-Level Netlist, and Testbench
vlog +acc -incr /courses/ee6321/share/ibm13rflpvt/verilog/ibm13rflpvt.v
vlog +acc -incr ../../dc/fir_core/fir_core.nl.v
vlog +acc -incr test_power_fir_core.v 

# Run Simulator with SDF annotation
# +nowarnTFMPC suppresses "Too Few Port Connections" warnings
# +delay_mode_zero disables timing delays (use for initial functional check)
vsim -voptargs=+acc \
     -t ps \
     -lib work \
     +nowarnTFMPC \
     +delay_mode_zero \
     -sdfmax /testbench/dut=../../dc/fir_core/fir_core.syn.sdf \
     testbench

# Load waveform configuration (optional - comment out for speed)
# do waveformat.do   

# Run simulation
run -all
