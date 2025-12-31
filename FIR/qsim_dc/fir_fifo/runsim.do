##################################################
#  Modelsim do file to run simulation

#Setup
 vlib work 
 vmap work work

#Include Netlist and Testbench
 vlog +acc -incr /courses/ee6321/share/ibm13rflpvt/verilog/ibm13rflpvt.v
 vlog +acc -incr ../../dc/fir_fifo/fir_fifo.nl.v
 vlog +acc -incr test_fir_fifo.v 

#Run Simulator 
#SDF from DC is annotated for the timing check 
vsim -voptargs=+acc -t ps -lib work -sdftyp dut=../../dc/fir_fifo/fir_fifo.syn.sdf testbench 
 do waveformat.do   
 run -all
