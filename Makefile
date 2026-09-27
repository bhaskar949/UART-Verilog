# ==============================================================================
# Makefile for UART Verilog Project
# Simulator: Icarus Verilog (iverilog) + GTKWave
# ==============================================================================

# Project name
TOP       = uart_tb
SIMOUT    = sim_out
VCD       = uart_sim.vcd

# Source files (order matters for Icarus)
SRCS = baud_rate_gen.v  \
       uart_fifo.v      \
       uart_tx.v        \
       uart_rx.v        \
       uart_top.v       \
       uart_tb.v

# Default target: compile + simulate
all: compile simulate

# Compile all Verilog sources
compile:
	iverilog -g2012 -o $(SIMOUT) $(SRCS)

# Run simulation
simulate: compile
	vvp $(SIMOUT)

# Open waveform in GTKWave
wave: simulate
	gtkwave $(VCD) &

# Lint check with Verilator (optional, if installed)
lint:
	verilator --lint-only -Wall $(filter-out uart_tb.v, $(SRCS))

# Clean build artifacts
clean:
	rm -f $(SIMOUT) $(VCD)

.PHONY: all compile simulate wave lint clean
