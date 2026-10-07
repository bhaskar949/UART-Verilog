# Full-Duplex UART Core with FIFO & 16× Oversampling (Xilinx Vivado & FPGA Ready)

[![Verilog](https://img.shields.io/badge/Language-Verilog-blue.svg)](https://en.wikipedia.org/wiki/Verilog)
[![Tool](https://img.shields.io/badge/EDA-Xilinx_Vivado-red.svg)](https://www.xilinx.com/products/design-tools/vivado.html)
[![FPGA](https://img.shields.io/badge/Target-Basys3_/_Artix--7-orange.svg)](https://digilent.com/reference/programmable-logic/basys-3/start)


A complete, fully parameterizable, synthesizable, and self-checking **Universal Asynchronous Receiver-Transmitter (UART)** designed in Verilog HDL. Optimized for **Xilinx Vivado** development and hardware deployment on **Xilinx 7-Series FPGAs** (such as Digilent Basys 3, Nexys A7, or custom Artix-7/Zynq/Spartan boards).

---

##  Table of Contents
- [Key Features](#-key-features)
- [Repository Structure (GitHub Files)](#-repository-structure-github-files)
- [Architecture & Block Diagram](#-architecture--block-diagram)
- [Module Descriptions](#-module-descriptions)
- [Vivado Quick-Start Guide](#-vivado-quick-start-guide)
  - [Method 1: Automated TCL Script (1-Click)](#method-1-automated-tcl-script-recommended)
  - [Method 2: Vivado GUI Step-by-Step](#method-2-vivado-gui-step-by-step)
- [Simulation & Verification](#-simulation--verification)
- [FPGA Pin Constraints & Synthesis](#-fpga-pin-constraints--synthesis)
- [Interactive Presentation](#-interactive-presentation)
- [GitHub Upload Guide](#-github-upload-guide)

---

##  Key Features

- **Full-Duplex Operation**: Independent simultaneous transmission and reception.
- **16× Oversampling Receiver**: High noise immunity with mid-bit sampling at the 8th tick of each bit period.
- **2-Flip-Flop Metastability Filter**: Double-registers incoming asynchronous serial data to ensure reliable clock domain crossing.
- **Configurable Synchronous FIFOs**: Circular buffer FIFOs (default depth: 16 words) on both TX and RX channels to prevent data loss and decouple host transfer timing.
- **Fully Parameterizable**:
  - System Clock Frequency (`CLK_FREQ`, default: 50 MHz or 100 MHz)
  - Baud Rate (`BAUD_RATE`, default: 9600 bps; supports up to 921600+ bps)
  - Data Width (`DATA_BITS`, default: 8)
  - Stop Bits (`STOP_BITS`, default: 1 or 2)
  - Parity (`PARITY_EN`, `PARITY_ODD`: None, Even, Odd)
  - FIFO Depth (`FIFO_DEPTH`, parameterizable power of 2)
- **Error Detection**: Flags framing errors, parity mismatch, and FIFO overrun conditions.
- **Production-Ready Verification**: Comprehensive self-checking testbench (`uart_tb_vivado.v`) testing single bytes, ASCII streams, burst transmissions, and boundary corner cases (0x00, 0xFF, 0x55, 0xAA).

---

##  Repository Structure (GitHub Files)

The files in this repository are structured specifically for version control and clean Vivado project recreation:

```
URAT/
├── baud_rate_gen.v          # 16× oversampling tick generator
├── uart_fifo.v              # Parameterized synchronous circular FIFO buffer
├── uart_tx.v                # FSM-based UART Transmitter
├── uart_rx.v                # FSM-based UART Receiver with 2-FF synchronizer
├── uart_top.v               # Top-level integration & FIFO wrapper
├── uart_tb_vivado.v         # Vivado XSIM self-checking testbench
├── uart_tb.v                # Generic standalone testbench
├── uart_basys3.xdc          # Xilinx Design Constraints (XDC) for Basys 3 (Artix-7)
├── create_vivado_project.tcl# Automated Vivado project setup & simulation script
├── uart_sim.ps1             # Local simulation automation script
├── uart_presentation.html   # Professional animated 12-slide project presentation
├── Makefile                 # Icarus Verilog build & lint automation
├── .gitignore               # Ignores Vivado generated caches (.Xil, *.runs, *.jou, etc.)
└── README.md                # Comprehensive documentation
```

> **Note on `.gitignore`**: Vivado generates hundreds of megabytes of temporary files (`.Xil/`, `*.runs/`, `*.sim/`, `*.jou`, `*.log`, `*.str`). The included `.gitignore` ensures only clean source code, constraints, and scripts are tracked in Git.

---

##  Architecture & Block Diagram

```
                              +-------------------------------------------------------------+
                              |                          uart_top                           |
                              |                                                             |
   Host / System Controller   |   +---------------+      +-------------+                    |
   ------------------------   |   |    TX FIFO    | ---> |   uart_tx   | ---> uart_tx_pin   |
    tx_wr_en  --------------> |   +---------------+      +-------------+                    |
    tx_wr_data -------------> |                                                             |
    tx_full   <-------------- |          +-------------------------+                        |
    tx_empty  <-------------- |          |      baud_rate_gen      | <--- 16x baud_tick     |
                              |          +-------------------------+                        |
    rx_rd_en  --------------> |   +---------------+      +-------------+                    |
    rx_rd_data <------------- |   |    RX FIFO    | <--- |   uart_rx   | <--- uart_rx_pin   |
    rx_full   <-------------- |   +---------------+      +-------------+   (2-FF sync)      |
    rx_empty  <-------------- |                                                             |
    rx_error  <-------------- |                                                             |
                              +-------------------------------------------------------------+
```

### Frame Format
```
   IDLE  | START |  D0  |  D1  |  D2  |  D3  |  D4  |  D5  |  D6  |  D7  | [PARITY] | STOP | IDLE
  -------+       +------+------+------+------+------+------+------+------+----------+------+------
         |_______| (LSB)                                            (MSB)          |______|
          1 bit                                                             0/1 bit  1/2 bit
```

---

##  Module Descriptions

| Module | Purpose | Key Sub-functions |
| :--- | :--- | :--- |
| [`baud_rate_gen.v`](baud_rate_gen.v) | Generates `tick` pulses at 16× the configured baud rate. | Modulo counter: `DIVISOR = CLK_FREQ / (BAUD_RATE * 16)`. |
| [`uart_tx.v`](uart_tx.v) | Serializes parallel byte data into standard UART protocol. | 4-state FSM: `IDLE` $\rightarrow$ `START` $\rightarrow$ `DATA` $\rightarrow$ `STOP`. Transmits LSB-first. |
| [`uart_rx.v`](uart_rx.v) | Deserializes serial incoming bit stream into bytes. | Double-flop synchronizer, 16× oversampling, mid-bit sample at tick 7, stop bit validation. |
| [`uart_fifo.v`](uart_fifo.v) | Dual-pointer circular FIFO for decoupling host and line rates. | `wr_ptr`, `rd_ptr` with MSB extension for accurate `full`, `empty`, and `count` status. |
| [`uart_top.v`](uart_top.v) | Top-level integration uniting Baud Gen, TX/RX, and FIFOs. | Simple host read/write interface for microcontrollers, soft-cores (MicroBlaze/RISC-V), or testbenches. |

---

##  Vivado Quick-Start Guide

### Method 1: Automated TCL Script (Recommended)

1. Open **Vivado** (2020.1 or newer).
2. Open the **Tcl Console** (bottom panel of Vivado).
3. Change directory to this project folder:
   ```tcl
   cd {C:/"FOLDER LOCATON"}
   ```
4. Run the project generation script:
   ```tcl
   source create_vivado_project.tcl
   ```
5. Vivado will automatically:
   - Create the project targeting Artix-7 (`xc7a35tcpg236-1`).
   - Import all Verilog design files and XDC constraints.
   - Launch behavioral simulation (XSIM).
   - Plot formatted wave traces in the Waveform Viewer.

---

### Method 2: Vivado GUI Step-by-Step

#### 1. Create a New Vivado Project
- Click **Create Project** $\rightarrow$ Click **Next**.
- Project Name: `uart_project`, Location: Select your desired folder $\rightarrow$ Click **Next**.
- Project Type: **RTL Project** (check *Do not specify sources at this time*) $\rightarrow$ Click **Next**.
- Select Default Part:
  - For **Basys 3**: `xc7a35tcpg236-1`
  - For **Nexys A7-100T**: `xc7a100tcsg324-1`
- Click **Finish**.

#### 2. Add Design Sources
- Under *Flow Navigator*, click **Add Sources** $\rightarrow$ **Add or create design sources**.
- Click **Add Files** and select:
  - `baud_rate_gen.v`
  - `uart_fifo.v`
  - `uart_tx.v`
  - `uart_rx.v`
  - `uart_top.v`
- Click **Finish**.

#### 3. Add Constraints
- Click **Add Sources** $\rightarrow$ **Add or create constraints**.
- Click **Add Files** and select `uart_basys3.xdc`.
- Click **Finish**.

#### 4. Add Simulation Testbench
- Click **Add Sources** $\rightarrow$ **Add or create simulation sources**.
- Click **Add Files** and select `uart_tb_vivado.v`.
- Click **Finish**.

---

##  Simulation & Verification

### Running Behavioral Simulation in Vivado
1. In the Flow Navigator, click **Run Simulation** $\rightarrow$ **Run Behavioral Simulation**.
2. Vivado XSIM will compile and execute the testbench.
3. In the Tcl Console, observe the self-checking test report:

```text
============================================================
  RUNNING VIVADO UART BEHAVIORAL SIMULATION
============================================================
[RESET] System reset asserted...
[RESET] System reset released.

[TEST 1] Single Byte Loopback (0xA5)
  [PASS] TX 0xA5 -> RX 0xA5 matched perfectly!

[TEST 2] Multi-Byte String Loopback ("UART")
  [PASS] TX 'U' (0x55) -> RX 'U' (0x55)
  [PASS] TX 'A' (0x41) -> RX 'A' (0x41)
  [PASS] TX 'R' (0x52) -> RX 'R' (0x52)
  [PASS] TX 'T' (0x54) -> RX 'T' (0x54)

[TEST 3] Boundary Values (0x00 and 0xFF)
  [PASS] TX 0x00 -> RX 0x00
  [PASS] TX 0xFF -> RX 0xFF

[TEST 4] Alternating Bit Patterns (0x55 and 0xAA)
  [PASS] TX 0x55 -> RX 0x55
  [PASS] TX 0xAA -> RX 0xAA

============================================================
  TEST RESULTS: 9 Passed, 0 Failed
  ALL VIVADO UART TESTS PASSED SUCCESSFULLY!
============================================================
```

---

##  FPGA Pin Constraints & Synthesis

The included [`uart_basys3.xdc`](uart_basys3.xdc) maps UART signals to hardware pins on the **Digilent Basys 3**:

| Signal | FPGA Pin (Artix-7) | Basys 3 Hardware Component |
| :--- | :--- | :--- |
| `clk` | `W5` | 100 MHz On-board Oscillator |
| `rst_n` | `U18` | Center Pushbutton `btnC` (Active-low reset in logic) |
| `uart_rx_pin` | `B18` | USB-UART Bridge RX (`RsRx`) |
| `uart_tx_pin` | `A18` | USB-UART Bridge TX (`RsTx`) |
| `tx_full` | `U16` | LED `LD0` |
| `rx_empty` | `E19` | LED `LD1` |
| `rx_error` | `L1` | LED `LD15` |

### Synthesis & Bitstream Flow:
1. In Vivado, click **Run Synthesis**.
2. Click **Run Implementation**.
3. Click **Generate Bitstream**.
4. Open **Hardware Manager** $\rightarrow$ **Auto Connect** $\rightarrow$ **Program Device**.
5. Connect your PC via micro-USB and open PuTTY / Tera Term at 9600 baud (8-N-1) to communicate directly with the FPGA!

---

##  Interactive Presentation

An interactive HTML5 presentation deck is included in [`uart_presentation.html`](uart_presentation.html).

- **How to view**: Open `uart_presentation.html` in any web browser (Chrome, Edge, Firefox).
- **Navigation**: Use **Left / Right arrow keys** or **F** for full-screen mode.
- **Contents**:
  - Slide 1: Cover & Engineering Metrics
  - Slide 2: UART Fundamentals & Protocol
  - Slide 3: Interactive Signal Waveforms
  - Slide 4: System Architecture Diagram
  - Slide 5: TX Finite State Machine
  - Slide 6: RX FSM & 16× Oversampling Theory
  - Slide 7: Baud Rate Generation Mathematics
  - Slide 8: Synchronous FIFO Architecture
  - Slide 9: Simulation Verification Matrix
  - Slide 10: Step-by-Step Vivado Workflow
  - Slide 11: Repository Inventory
  - Slide 12: Summary & References

---

##  GitHub Upload Guide

To initialize and push this project to your GitHub account, run these commands from the project directory:

```bash
# 1. Navigate to the project directory
cd "C:\Users\bhask\OneDrive\ドキュメント\G.Pro\URAT"

# 2. Initialize a local Git repository
git init

# 3. Add all project files (the .gitignore will automatically exclude Vivado temp files)
git add .

# 4. Commit the initial release
git commit -m "Initial commit: Complete synthesizable UART Verilog core with Vivado TCL automation, XDC constraints, and self-checking testbench"

# 5. Link to your GitHub repository (replace URL with your GitHub repo link)
git branch -M main
git remote add origin https://github.com/<YOUR_USERNAME>/<YOUR_REPO_NAME>.git

# 6. Push to GitHub
git push -u origin main
```

---
