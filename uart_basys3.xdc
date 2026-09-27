## Xilinx Vivado Constraints File (XDC)
## Target Board: Basys3 (Artix-7 XC7A35T-1CPG236C)
## ============================================================
## Adapt pin locations for your specific board below.
## Comments explain how to change for other boards.
## ============================================================

# --------------------------------------------------------------
# Clock — Basys3 onboard 100 MHz oscillator
# Change W5 to match your board's clock pin
# --------------------------------------------------------------
set_property PACKAGE_PIN W5 [get_ports clk]
set_property IOSTANDARD LVCMOS33 [get_ports clk]
create_clock -period 10.000 -name sys_clk [get_ports clk]

# --------------------------------------------------------------
# Reset — Basys3 center push button (active HIGH → invert in top)
# BTN_C = U18  (change for your board)
# The uart_top uses active-LOW rst_n, so connect to ~BTNC
# --------------------------------------------------------------
set_property PACKAGE_PIN U18 [get_ports rst_n]
set_property IOSTANDARD LVCMOS33 [get_ports rst_n]

# --------------------------------------------------------------
# UART TX — USB-UART bridge on Basys3
# Basys3 UART TX → A18 (connects to FT2232HQ USB chip)
# --------------------------------------------------------------
set_property PACKAGE_PIN A18 [get_ports uart_tx_pin]
set_property IOSTANDARD LVCMOS33 [get_ports uart_tx_pin]

# --------------------------------------------------------------
# UART RX — USB-UART bridge on Basys3
# Basys3 UART RX ← B18
# --------------------------------------------------------------
set_property PACKAGE_PIN B18 [get_ports uart_rx_pin]
set_property IOSTANDARD LVCMOS33 [get_ports uart_rx_pin]

# --------------------------------------------------------------
# TX Write Enable — SW0 (Slide Switch 0)
# --------------------------------------------------------------
set_property PACKAGE_PIN V17 [get_ports tx_wr_en]
set_property IOSTANDARD LVCMOS33 [get_ports tx_wr_en]

# --------------------------------------------------------------
# TX Data — SW[7:0] slide switches (for manual byte input)
# --------------------------------------------------------------
set_property PACKAGE_PIN V17 [get_ports {tx_wr_data[0]}]
set_property PACKAGE_PIN V16 [get_ports {tx_wr_data[1]}]
set_property PACKAGE_PIN W16 [get_ports {tx_wr_data[2]}]
set_property PACKAGE_PIN W17 [get_ports {tx_wr_data[3]}]
set_property PACKAGE_PIN W15 [get_ports {tx_wr_data[4]}]
set_property PACKAGE_PIN V15 [get_ports {tx_wr_data[5]}]
set_property PACKAGE_PIN W14 [get_ports {tx_wr_data[6]}]
set_property PACKAGE_PIN W13 [get_ports {tx_wr_data[7]}]

set_property IOSTANDARD LVCMOS33 [get_ports {tx_wr_data[*]}]

# --------------------------------------------------------------
# TX FIFO Full / Empty LEDs
# LD0 = TX_FULL, LD1 = TX_EMPTY, LD2 = RX_ERROR
# --------------------------------------------------------------
set_property PACKAGE_PIN U16 [get_ports tx_full]
set_property PACKAGE_PIN E19 [get_ports tx_empty]
set_property PACKAGE_PIN U19 [get_ports rx_error]
set_property IOSTANDARD LVCMOS33 [get_ports tx_full]
set_property IOSTANDARD LVCMOS33 [get_ports tx_empty]
set_property IOSTANDARD LVCMOS33 [get_ports rx_error]

# --------------------------------------------------------------
# Timing constraints
# --------------------------------------------------------------
set_property CLOCK_DEDICATED_ROUTE FALSE [get_nets clk]

# --------------------------------------------------------------
# Bitstream settings
# --------------------------------------------------------------
set_property BITSTREAM.GENERAL.COMPRESS TRUE [current_design]
set_property BITSTREAM.CONFIG.CONFIGRATE 33 [current_design]
set_property CONFIG_VOLTAGE 3.3 [current_design]
set_property CFGBVS VCCO [current_design]
