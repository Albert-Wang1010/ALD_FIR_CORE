# 64-Tap 16-Bit FIR Filter Core

A complete RTL-to-GDSII implementation of a 64-tap finite impulse response (FIR) filter with dual-clock domain crossing, designed and verified in Verilog HDL.

## Overview

This project implements a high-performance digital FIR filter with programmable coefficients, asynchronous clock domain crossing, and complete verification through gate-level simulation and power analysis.

**Key Specifications:**
- 64-tap filter with 16-bit Q1.15 coefficients
- Dual-clock domain: 10 kHz input sampling, 100 MHz processing
- Fixed-point arithmetic with saturation and rounding
- Gray code synchronizers for safe CDC
- 40-bit accumulator prevents overflow
- 6-state FSM controller

## Performance Metrics

| Metric | Value | Method |
|--------|-------|--------|
| Throughput | 10 kS/s | Input-limited design |
| Max Frequency | 100 MHz | PrimeTime STA with SDF |
| Power Consumption | 3.384 mW | PrimeTime VCD-based analysis |
| Energy Efficiency | 0.034 mW/MHz | Excellent for 130nm technology |
| Area | 46,551 μm² | Design Compiler synthesis |
| Gate Count | 10,650 cells | 3,252 flip-flops, 7,378 combinational |
| Accuracy | <0.012% NRMSE | vs. MATLAB floating-point reference |

## Architecture

The design consists of five primary modules integrated into a single top-level `fir_core.v`:

**FIFO** - Asynchronous FIFO (64×16) with Gray code synchronizers for clock domain crossing from 10 kHz input (clk1) to 100 MHz processing (clk2). Implements 2-stage synchronizer chains to prevent metastability.

**CMEM** - Coefficient memory (64×16) storing programmable Q1.15 filter coefficients. Supports sequential write via external interface and random-access read during MAC operations.

**REGFILE** - Circular buffer (64×16) storing the most recent 64 input samples. Implements wrap-around addressing for efficient FIR computation without data shifting.

**ALU** - MAC unit with 16×16 signed multiplier producing Q2.30 products, 40-bit accumulator (prevents overflow for 64 accumulations), round-to-nearest logic, and saturation to Q7.9 output format.

**FSM** - 6-state controller (IDLE, WAIT_RD, LOAD, COMPUTE, WAIT_MAC, OUTPUT) orchestrating the filter operation. Generates all control signals including memory enables, addresses, and MAC controls.

## Repository Organization

### Core Design
- **rtl/fir_core.v** - Final integrated design (main deliverable)
- **rtl/development/** - Individual modules developed during design process
  - `01_fir_alu/` - MAC unit with testbench
  - `02_fir_cmem/` - Coefficient memory with testbench
  - `03_fir_regfile/` - Register file with testbench
  - `04_fir_fifo/` - Async FIFO with CDC and testbench
  - `05_fir_fsm/` - FSM controller with testbench

*Note: The final `fir_core.v` incorporates all modules in a single file for synthesis.*

### Verification
- **verification/rtl/** - Pre-synthesis RTL simulation
  - 10 comprehensive test cases
  - All tests passed (10/10)
- **verification/gate_level/** - Post-synthesis verification
  - 3 essential tests with SDF timing back-annotation
  - All tests passed (3/3), no X-propagation
  - Power analysis VCD generation testbench

*Note: VCD files excluded from repository due to large file size (8+ GB). Testbenches provided for regeneration.*

### Synthesis & Analysis
- **synthesis/scripts/** - Design Compiler TCL constraint files
- **synthesis/results/** - Gate-level netlist, SDF, synthesis reports
- **analysis/** - PrimeTime static timing and power analysis reports
  - Timing analysis with SDF back-annotation
  - Power analysis with VCD-based switching activity

### Documentation
- **docs/** - Architecture diagrams, waveforms, analysis plots
- **report.pdf** - Complete technical report with detailed methodology

### Archive
- **archive/** - Historical files from original development structure
  - Individual module simulation directories
  - Intermediate synthesis runs
  - Legacy testbenches

## Verification Methodology

**Pre-Synthesis (RTL):** 10 comprehensive tests covering coefficient loading, zero input, DC response, impulse response, alternating input patterns, step response, positive/negative saturation, mixed-sign arithmetic, and zero-flush verification. Result: 10/10 passed.

**Post-Synthesis (Gate-Level):** 3 critical tests with full SDF timing back-annotation to verify functional equivalence and proper memory initialization. Extended 200-cycle reset ensures all 3,252 flip-flops initialize correctly. Result: 3/3 passed.

**Power Analysis:** VCD-based switching activity with 100% annotation coverage (10,953 nets, 10,630 cells). Three-phase testbench: coefficient loading, active processing (20 samples), and idle period for leakage measurement.

## Critical Design Decisions

**40-bit Accumulator Width:** Required to prevent overflow. A 16×16 multiplication produces 32 bits (Q2.30). Accumulating 64 products requires log2(64) = 6 additional bits, totaling 36 bits minimum. Selected 40 bits to include 4 guard bits for rounding operations.

**Memory Initialization:** Synthesis tools remove Verilog `initial` blocks, causing X-propagation in gate-level simulation. Solution: explicit for-loop reset in all memory arrays, synthesizing to flip-flops with proper reset pins (DFFRXLTS).

**Clock Domain Crossing:** Implemented asynchronous FIFO with Gray code pointer synchronization. Write pointer (clk1 domain) synchronized to clk2 via 2-stage FF chain, and vice versa for read pointer. Prevents metastability in CDC paths.

**Fixed-Point Precision:** Input/coefficient format Q1.15 chosen to maximize dynamic range while maintaining precision. Output scaled to Q7.9 after accumulation to provide 7 integer bits (preventing saturation for typical signals) and 9 fractional bits (maintaining accuracy).

## Design Flow Summary

1. **Architecture Planning** - Defined fixed-point formats, calculated accumulator width, planned CDC strategy
2. **Module Development** - Built and verified each module independently: ALU → CMEM → REGFILE → FIFO → FSM
3. **Integration** - Combined modules into single `fir_core.v`, comprehensive 10-test verification suite
4. **Synthesis** - Design Compiler targeting 100 MHz (10ns period), achieved 0.02ns positive slack
5. **Post-Synthesis Verification** - Gate-level simulation with SDF, all tests passed
6. **Power Analysis** - PrimeTime PX with VCD annotation, 3.384 mW total power

## Tools & Technologies

- **HDL:** Verilog-2001
- **Simulation:** ModelSim/QuestaSim
- **Synthesis:** Synopsys Design Compiler Ultra (U-2022.12-SP7)
- **STA/Power:** Synopsys PrimeTime/PrimeTime PX
- **Technology:** IBM 130nm CMOS (scx3_cmos8rf_lpvt_tt_1p2v_25c)
- **Operating Conditions:** TT corner, 1.2V, 25°C

## Quick Start

**Prerequisites:** ModelSim/QuestaSim for simulation. Synopsys tools and IBM 130nm PDK required for synthesis/analysis.

**Note:** File paths in scripts may need adjustment after repository reorganization. The code examples below show the intended structure; actual paths in legacy scripts may differ.

**RTL Simulation:**
```bash
# Compile design
vlog rtl/fir_core.v

# Run comprehensive testbench
vlog verification/rtl/fir_core_tb_comprehensive.v
vsim work.testbench
run -all
# Expected: 10/10 tests PASSED
```

**Post-Synthesis Simulation:**
```bash
# Compile gate-level netlist
vlog synthesis/results/fir_core.nl.v

# Run with SDF timing
vlog verification/gate_level/testbench_postsyn.v
vsim -sdfmax /testbench/dut=synthesis/results/fir_core_syn.sdf work.testbench
run -all
# Expected: 3/3 tests PASSED
```

## Documentation

See **report.pdf** for complete technical documentation including detailed module specifications, verification results, timing analysis, power breakdown, and waveform screenshots.

## Academic Context

Completed as part of CSEE W4823 Advanced Logic Design at Columbia University (Fall 2025). Demonstrates RTL-to-GDSII design flow, fixed-point DSP implementation, clock domain crossing techniques, and comprehensive verification methodology using industry-standard EDA tools.

## Acknowledgments

**Professor Mingoo Seok** - Course instructor, CSEE W4823 Advanced Logic Design

**Columbia EE Department** - Lab resources and tool access

**AI Tools** - ChatGPT/Claude used for coding assistance, debugging support, and documentation. All code independently understood, tested, and verified.

## License

MIT License - see LICENSE file for details.

---

*For questions or collaboration opportunities, please contact via the information provided in the repository profile.*