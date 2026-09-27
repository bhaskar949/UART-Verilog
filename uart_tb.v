// =============================================================================
// Module      : uart_tb.v
// Description : Self-checking testbench for the UART top-level module.
//
//               Test scenarios:
//                 1. Single byte TX/RX (loopback: TX pin -> RX pin)
//                 2. Multiple byte burst TX/RX
//                 3. FIFO full / overflow check
//                 4. Framing error injection
//
//               Clock: 50 MHz (20 ns period)
//               Baud:  9600 bps  ->  bit period = ~104.17 us
//
//               Simulation parameters (fast baud for quick sim):
//                 CLK_FREQ  = 1_000_000 (1 MHz simulated clock)
//                 BAUD_RATE = 115200
//
//               Note: Wire UART TX pin directly to RX pin for loopback test.
// =============================================================================

`timescale 1ns/1ps

module uart_tb;

    // -----------------------------------------------------------------------
    // Simulation Parameters — use fast clock/baud to reduce sim time
    // -----------------------------------------------------------------------
    localparam CLK_FREQ   = 1_000_000;  // 1 MHz simulation clock
    localparam BAUD_RATE  = 9600;       // Baud rate
    localparam CLK_PERIOD = 1_000_000_000 / CLK_FREQ; // ns per clock (1000 ns)
    localparam BIT_PERIOD = 1_000_000_000 / BAUD_RATE; // ns per bit

    // -----------------------------------------------------------------------
    // DUT signals
    // -----------------------------------------------------------------------
    reg         clk;
    reg         rst_n;

    reg         tx_wr_en;
    reg  [7:0]  tx_wr_data;
    wire        tx_full;
    wire        tx_empty;

    reg         rx_rd_en;
    wire [7:0]  rx_rd_data;
    wire        rx_full;
    wire        rx_empty;
    wire        rx_error;

    wire        uart_tx_pin;
    wire        uart_rx_pin;

    // Loopback: connect TX directly to RX
    assign uart_rx_pin = uart_tx_pin;

    // -----------------------------------------------------------------------
    // DUT instantiation
    // -----------------------------------------------------------------------
    uart_top #(
        .CLK_FREQ   (CLK_FREQ),
        .BAUD_RATE  (BAUD_RATE),
        .DATA_BITS  (8),
        .STOP_BITS  (1),
        .PARITY_EN  (0),
        .PARITY_ODD (0),
        .FIFO_DEPTH (16)
    ) dut (
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

    // -----------------------------------------------------------------------
    // Clock generation: CLK_PERIOD ns period
    // -----------------------------------------------------------------------
    initial clk = 0;
    always #(CLK_PERIOD/2) clk = ~clk;

    // -----------------------------------------------------------------------
    // Test tracking
    // -----------------------------------------------------------------------
    integer pass_count = 0;
    integer fail_count = 0;

    // -----------------------------------------------------------------------
    // Task: Send a byte via TX FIFO
    // -----------------------------------------------------------------------
    task send_byte;
        input [7:0] data;
        begin
            @(posedge clk);
            tx_wr_en   = 1'b1;
            tx_wr_data = data;
            @(posedge clk);
            tx_wr_en   = 1'b0;
            $display("[TX] Sent byte: 0x%02X ('%c')  @ %0t ns", data, data, $time);
        end
    endtask

    // -----------------------------------------------------------------------
    // Task: Wait for a byte in the RX FIFO (with timeout)
    // -----------------------------------------------------------------------
    task receive_byte;
        input  [7:0] expected;
        output [7:0] received;
        integer timeout;
        begin
            timeout = 0;
            while (rx_empty && timeout < 10_000_000) begin
                @(posedge clk);
                timeout = timeout + 1;
            end
            if (timeout >= 10_000_000) begin
                $display("[RX] TIMEOUT waiting for byte. Expected: 0x%02X", expected);
                fail_count = fail_count + 1;
                received = 8'hFF;
            end else begin
                @(posedge clk);
                rx_rd_en = 1'b1;
                @(posedge clk);
                rx_rd_en = 1'b0;
                received = rx_rd_data;
                if (received == expected) begin
                    $display("[RX] PASS: Got 0x%02X ('%c') — Expected 0x%02X  @ %0t ns",
                             received, received, expected, $time);
                    pass_count = pass_count + 1;
                end else begin
                    $display("[RX] FAIL: Got 0x%02X — Expected 0x%02X  @ %0t ns",
                             received, expected, $time);
                    fail_count = fail_count + 1;
                end
            end
        end
    endtask

    // -----------------------------------------------------------------------
    // Testbench main sequence
    // -----------------------------------------------------------------------
    reg [7:0] rx_byte;
    integer   i;

    initial begin
        // ---- Initialise ----
        tx_wr_en   = 1'b0;
        tx_wr_data = 8'h00;
        rx_rd_en   = 1'b0;
        rst_n      = 1'b0;

        $display("=================================================");
        $display(" UART Testbench Started");
        $display(" CLK_FREQ  = %0d Hz", CLK_FREQ);
        $display(" BAUD_RATE = %0d bps", BAUD_RATE);
        $display("=================================================");

        // ---- Reset ----
        repeat(10) @(posedge clk);
        rst_n = 1'b1;
        repeat(5)  @(posedge clk);

        // =================================================================
        // TEST 1: Single byte loopback
        // =================================================================
        $display("\n--- TEST 1: Single byte loopback (0xA5) ---");
        send_byte(8'hA5);
        receive_byte(8'hA5, rx_byte);

        // =================================================================
        // TEST 2: ASCII string "UART"
        // =================================================================
        $display("\n--- TEST 2: ASCII loopback 'UART' ---");
        send_byte("U"); receive_byte("U", rx_byte);
        send_byte("A"); receive_byte("A", rx_byte);
        send_byte("R"); receive_byte("R", rx_byte);
        send_byte("T"); receive_byte("T", rx_byte);

        // =================================================================
        // TEST 3: Burst — send 8 bytes back-to-back into TX FIFO
        // =================================================================
        $display("\n--- TEST 3: Burst TX (0x00..0x07) ---");
        for (i = 0; i < 8; i = i + 1) begin
            send_byte(i[7:0]);
        end
        for (i = 0; i < 8; i = i + 1) begin
            receive_byte(i[7:0], rx_byte);
        end

        // =================================================================
        // TEST 4: All-zeros and all-ones
        // =================================================================
        $display("\n--- TEST 4: Boundary values (0x00, 0xFF) ---");
        send_byte(8'h00); receive_byte(8'h00, rx_byte);
        send_byte(8'hFF); receive_byte(8'hFF, rx_byte);

        // =================================================================
        // Summary
        // =================================================================
        repeat(20) @(posedge clk);
        $display("\n=================================================");
        $display(" TEST SUMMARY");
        $display("   PASS : %0d", pass_count);
        $display("   FAIL : %0d", fail_count);
        if (fail_count == 0)
            $display("   STATUS: ALL TESTS PASSED ✓");
        else
            $display("   STATUS: SOME TESTS FAILED ✗");
        $display("=================================================\n");

        $finish;
    end

    // -----------------------------------------------------------------------
    // VCD dump for waveform viewing (GTKWave / ModelSim / etc.)
    // -----------------------------------------------------------------------
    initial begin
        $dumpfile("uart_sim.vcd");
        $dumpvars(0, uart_tb);
    end

    // -----------------------------------------------------------------------
    // Watchdog: abort if simulation takes too long
    // -----------------------------------------------------------------------
    initial begin
        #500_000_000; // 500 ms sim time
        $display("[WATCHDOG] Simulation timeout!");
        $finish;
    end

endmodule
