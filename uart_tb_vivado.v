// =============================================================================
// Module      : uart_tb_vivado.v
// Description : Vivado XSIM-compatible UART testbench
//               - Uses $display for console output (XSIM compatible)
//               - No VCD dump (Vivado uses its own .wdb format)
//               - Loopback: TX pin directly wired to RX pin
//               - Set simulation time in Vivado: Run for 500ms (sim time)
//
// How to use in Vivado:
//   1. Add all .v files to project as Design Sources (except this file)
//   2. Add this file as Simulation Source
//   3. Right-click → Set as Top (simulation)
//   4. Run Behavioral Simulation
//   5. View waveforms in Vivado Wave window
// =============================================================================

`timescale 1ns / 1ps

module uart_tb_vivado;

    // ---- Simulation clock: 1 MHz to reduce sim time ----
    localparam CLK_FREQ   = 1_000_000;
    localparam BAUD_RATE  = 9600;
    localparam CLK_PERIOD = 1000; // ns (1 MHz)

    // ---- DUT Signals ----
    reg         clk      = 0;
    reg         rst_n    = 0;

    reg         tx_wr_en   = 0;
    reg  [7:0]  tx_wr_data = 8'h00;
    wire        tx_full;
    wire        tx_empty;

    reg         rx_rd_en   = 0;
    wire [7:0]  rx_rd_data;
    wire        rx_full;
    wire        rx_empty;
    wire        rx_error;

    wire        uart_tx_pin;
    wire        uart_rx_pin;

    // Loopback for self-test
    assign uart_rx_pin = uart_tx_pin;

    // ---- DUT ----
    uart_top #(
        .CLK_FREQ   (CLK_FREQ),
        .BAUD_RATE  (BAUD_RATE),
        .DATA_BITS  (8),
        .STOP_BITS  (1),
        .PARITY_EN  (0),
        .PARITY_ODD (0),
        .FIFO_DEPTH (16)
    ) uut (
        .clk         (clk),
        .rst_n       (rst_n),
        .tx_wr_en    (tx_wr_en),
        .tx_wr_data  (tx_wr_data),
        .tx_full     (tx_full),
        .tx_empty    (tx_empty),
        .rx_rd_en    (rx_rd_en),
        .rx_rd_data  (rx_rd_data),
        .rx_full     (rx_full),
        .rx_empty    (rx_empty),
        .rx_error    (rx_error),
        .uart_tx_pin (uart_tx_pin),
        .uart_rx_pin (uart_rx_pin)
    );

    // ---- Clock ----
    always #(CLK_PERIOD/2) clk = ~clk;

    // ---- Score tracking ----
    integer pass_count = 0;
    integer fail_count = 0;

    // ---- Task: Write byte to TX FIFO ----
    task automatic send_byte(input [7:0] data);
        @(posedge clk);
        tx_wr_en   = 1'b1;
        tx_wr_data = data;
        @(posedge clk);
        tx_wr_en   = 1'b0;
        $display("[%0t ns] TX: Sent 0x%02X", $time, data);
    endtask

    // ---- Task: Wait for byte in RX FIFO and check ----
    task automatic recv_and_check(input [7:0] expected);
        integer timeout;
        timeout = 0;
        while (rx_empty && timeout < 5_000_000) begin
            @(posedge clk);
            timeout = timeout + 1;
        end
        if (timeout >= 5_000_000) begin
            $display("[%0t ns] TIMEOUT waiting for 0x%02X", $time, expected);
            fail_count = fail_count + 1;
        end else begin
            @(posedge clk);
            rx_rd_en = 1'b1;
            @(posedge clk);
            rx_rd_en = 1'b0;
            if (rx_rd_data === expected) begin
                $display("[%0t ns] PASS: RX=0x%02X matches TX=0x%02X", $time, rx_rd_data, expected);
                pass_count = pass_count + 1;
            end else begin
                $display("[%0t ns] FAIL: RX=0x%02X, Expected=0x%02X", $time, rx_rd_data, expected);
                fail_count = fail_count + 1;
            end
        end
    endtask

    // ---- Stimulus ----
    integer i;
    initial begin
        $display("========================================");
        $display("  UART Vivado XSIM Testbench");
        $display("  CLK=%0d Hz  BAUD=%0d", CLK_FREQ, BAUD_RATE);
        $display("========================================");

        rst_n = 0;
        repeat(10) @(posedge clk);
        rst_n = 1;
        repeat(5)  @(posedge clk);

        // Test 1: 0xA5
        $display("\n-- TEST 1: Single byte 0xA5 --");
        send_byte(8'hA5);
        recv_and_check(8'hA5);

        // Test 2: "UART" string
        $display("\n-- TEST 2: ASCII 'UART' --");
        send_byte("U"); recv_and_check("U");
        send_byte("A"); recv_and_check("A");
        send_byte("R"); recv_and_check("R");
        send_byte("T"); recv_and_check("T");

        // Test 3: Burst 0x00..0x07
        $display("\n-- TEST 3: Burst bytes 0x00..0x07 --");
        for (i=0; i<8; i=i+1) send_byte(i[7:0]);
        for (i=0; i<8; i=i+1) recv_and_check(i[7:0]);

        // Test 4: Boundaries
        $display("\n-- TEST 4: Boundaries 0x00 and 0xFF --");
        send_byte(8'h00); recv_and_check(8'h00);
        send_byte(8'hFF); recv_and_check(8'hFF);

        repeat(20) @(posedge clk);
        $display("\n========================================");
        $display("  SUMMARY: PASS=%0d  FAIL=%0d", pass_count, fail_count);
        if (fail_count == 0)
            $display("  *** ALL TESTS PASSED ***");
        else
            $display("  *** FAILURES DETECTED ***");
        $display("========================================\n");
        $finish;
    end

    // ---- Timeout watchdog ----
    initial begin
        #500_000_000;
        $display("[WATCHDOG] Simulation timed out!");
        $finish;
    end

endmodule
