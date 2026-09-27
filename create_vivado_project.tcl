# =============================================================================
# Vivado TCL Script — Create UART Project + Run Behavioral Simulation
#
# USAGE:
#   In Vivado Tcl Console:
#     cd <directory_containing_this_script>
#     source create_vivado_project.tcl
#
#   Or from Command Line / Terminal:
#     vivado -mode tcl -source create_vivado_project.tcl
#
# This script:
#   1. Creates a new Vivado project in ./uart_vivado_proj
#   2. Adds all Verilog design sources
#   3. Adds XDC constraints file (Basys 3 / Artix-7)
#   4. Adds testbench as simulation source
#   5. Sets top modules for synthesis and simulation
#   6. Runs behavioral simulation (XSIM)
#   7. Adds signals to waveform viewer and runs simulation
# =============================================================================

# --- Resolve Script & Source Directory Dynamically ---
set script_dir [file dirname [file normalize [info script]]]
set src_dir    $script_dir
set proj_name  "uart_project"
set proj_dir   "$script_dir/uart_vivado_proj"

# Target part: Basys3 → XC7A35TCPG236-1
# (Change to your board if different, e.g. xc7a100tcsg324-1 for Nexys A7)
set fpga_part  "xc7a35tcpg236-1"

puts "================================================================"
puts "  Initializing UART Vivado Project"
puts "  Directory: $src_dir"
puts "  FPGA Part: $fpga_part"
puts "================================================================"

# --- Create project ---
puts "Creating Vivado project: $proj_name at $proj_dir"
create_project $proj_name $proj_dir -part $fpga_part -force

# --- Set project properties ---
set_property target_language Verilog [current_project]
set_property simulator_language Mixed [current_project]
set_property default_lib work [current_project]

# --- Add design sources ---
puts "Adding design sources..."
add_files -norecurse [list \
    "$src_dir/baud_rate_gen.v" \
    "$src_dir/uart_fifo.v"     \
    "$src_dir/uart_tx.v"       \
    "$src_dir/uart_rx.v"       \
    "$src_dir/uart_top.v"      \
]

# --- Add constraints ---
if {[file exists "$src_dir/uart_basys3.xdc"]} {
    puts "Adding constraints ($src_dir/uart_basys3.xdc)..."
    add_files -fileset constrs_1 -norecurse "$src_dir/uart_basys3.xdc"
}

# --- Add simulation sources ---
puts "Adding simulation sources..."
if {[file exists "$src_dir/uart_tb_vivado.v"]} {
    add_files -fileset sim_1 -norecurse "$src_dir/uart_tb_vivado.v"
    set_property top uart_tb_vivado [get_filesets sim_1]
} elseif {[file exists "$src_dir/uart_tb.v"]} {
    add_files -fileset sim_1 -norecurse "$src_dir/uart_tb.v"
    set_property top uart_tb [get_filesets sim_1]
}

# --- Set top module for synthesis ---
set_property top uart_top [get_filesets sources_1]

# Update compile order
update_compile_order -fileset sources_1
update_compile_order -fileset sim_1

puts ""
puts "================================================================"
puts "  Project created successfully!"
puts "  Design top : [get_property top [get_filesets sources_1]]"
puts "  Sim top    : [get_property top [get_filesets sim_1]]"
puts "  FPGA Part  : $fpga_part"
puts "================================================================"
puts ""

# --- Run Behavioral Simulation ---
puts "Launching Vivado behavioral simulation (XSIM)..."
launch_simulation -simset sim_1 -mode behavioral

# Add signals to waveform viewer
catch {
    add_wave /uart_tb_vivado/clk
    add_wave /uart_tb_vivado/rst_n
    add_wave /uart_tb_vivado/uart_tx_pin
    add_wave /uart_tb_vivado/uart_rx_pin
    add_wave /uart_tb_vivado/tx_wr_en
    add_wave /uart_tb_vivado/tx_wr_data
    add_wave /uart_tb_vivado/rx_rd_en
    add_wave /uart_tb_vivado/rx_rd_data
    add_wave /uart_tb_vivado/rx_empty
    add_wave /uart_tb_vivado/rx_error
    add_wave /uart_tb_vivado/tx_full

    set_property radix hex [get_waves /uart_tb_vivado/tx_wr_data]
    set_property radix hex [get_waves /uart_tb_vivado/rx_rd_data]
}

# Run simulation
run 500ms

puts ""
puts "Simulation complete. Check waveforms in the Vivado Waveform window."
puts "Tcl Console contains self-checking PASS / FAIL results."
