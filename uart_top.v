// =============================================================================
// Module      : uart_top.v
// Description : Top-level UART module integrating:
//                 - Baud Rate Generator (16x oversampling)
//                 - UART Transmitter (uart_tx)
//                 - UART Receiver    (uart_rx)
//                 - TX FIFO buffer   (uart_fifo)
//                 - RX FIFO buffer   (uart_fifo)
//
//               Loopback mode: connect TX to RX internally (for testing)
//
// Parameters  :
//   CLK_FREQ   - System clock frequency (Hz), default 50 MHz
//   BAUD_RATE  - Baud rate, default 9600
//   DATA_BITS  - Data bits per frame (5-8), default 8
//   STOP_BITS  - Stop bits (1 or 2), default 1
//   PARITY_EN  - Enable parity, default 0
//   PARITY_ODD - 0=Even, 1=Odd parity, default 0
//   FIFO_DEPTH - TX/RX FIFO depth, default 16
//
// CPU / Host Interface:
//   tx_wr_en   - Write a byte to the TX FIFO
//   tx_wr_data - Byte to transmit
//   tx_full    - TX FIFO is full (do not write)
//   tx_empty   - TX FIFO is empty (nothing pending)
//
//   rx_rd_en   - Read a byte from the RX FIFO
//   rx_rd_data - Received byte read out
//   rx_full    - RX FIFO is full (data may be lost if not read)
//   rx_empty   - No received data available
//   rx_error   - Framing or parity error on last received byte
//
//   uart_tx_pin - Serial output to external device / connector
//   uart_rx_pin - Serial input from external device / connector
// =============================================================================

module uart_top #(
    parameter CLK_FREQ   = 50_000_000,
    parameter BAUD_RATE  = 9600,
    parameter DATA_BITS  = 8,
    parameter STOP_BITS  = 1,
    parameter PARITY_EN  = 0,
    parameter PARITY_ODD = 0,
    parameter FIFO_DEPTH = 16
)(
    input  wire         clk,
    input  wire         rst_n,

    // ---- TX Host Interface ----
    input  wire         tx_wr_en,
    input  wire [7:0]   tx_wr_data,
    output wire         tx_full,
    output wire         tx_empty,

    // ---- RX Host Interface ----
    input  wire         rx_rd_en,
    output wire [7:0]   rx_rd_data,
    output wire         rx_full,
    output wire         rx_empty,
    output wire         rx_error,

    // ---- UART Serial Pins ----
    output wire         uart_tx_pin,
    input  wire         uart_rx_pin
);

    // -----------------------------------------------------------------------
    // Internal signals
    // -----------------------------------------------------------------------
    wire        baud_tick;

    // TX FIFO -> TX core
    wire [7:0]  tx_fifo_rd_data;
    wire        tx_fifo_empty;
    wire        tx_fifo_rd_en;

    // TX core status
    wire        tx_busy;
    wire        tx_done;

    // RX core -> RX FIFO
    wire [7:0]  rx_byte;
    wire        rx_done_pulse;
    wire        rx_err_pulse;

    // -----------------------------------------------------------------------
    // Baud Rate Generator
    // -----------------------------------------------------------------------
    baud_rate_gen #(
        .CLK_FREQ  (CLK_FREQ),
        .BAUD_RATE (BAUD_RATE)
    ) u_baud (
        .clk   (clk),
        .rst_n (rst_n),
        .tick  (baud_tick)
    );

    // -----------------------------------------------------------------------
    // TX FIFO
    // -----------------------------------------------------------------------
    uart_fifo #(
        .DATA_WIDTH (8),
        .DEPTH      (FIFO_DEPTH)
    ) u_tx_fifo (
        .clk     (clk),
        .rst_n   (rst_n),
        .wr_en   (tx_wr_en),
        .wr_data (tx_wr_data),
        .rd_en   (tx_fifo_rd_en),
        .rd_data (tx_fifo_rd_data),
        .full    (tx_full),
        .empty   (tx_fifo_empty),
        .count   ()
    );

    assign tx_empty = tx_fifo_empty;

    // -----------------------------------------------------------------------
    // TX Controller: Pull bytes from TX FIFO and send when TX is not busy
    // -----------------------------------------------------------------------
    reg tx_start_reg;
    reg [7:0] tx_data_reg;
    reg tx_fifo_rd_en_reg;

    assign tx_fifo_rd_en = tx_fifo_rd_en_reg;

    always @(posedge clk) begin
        if (!rst_n) begin
            tx_start_reg     <= 1'b0;
            tx_data_reg      <= 8'h00;
            tx_fifo_rd_en_reg<= 1'b0;
        end else begin
            tx_start_reg      <= 1'b0;
            tx_fifo_rd_en_reg <= 1'b0;

            // When TX core is free and FIFO has data, fetch next byte
            if (!tx_busy && !tx_fifo_empty && !tx_start_reg) begin
                tx_fifo_rd_en_reg <= 1'b1;
            end

            // One cycle after read enable, data is valid — start TX
            if (tx_fifo_rd_en_reg) begin
                tx_data_reg  <= tx_fifo_rd_data;
                tx_start_reg <= 1'b1;
            end
        end
    end

    // -----------------------------------------------------------------------
    // UART TX Core
    // -----------------------------------------------------------------------
    uart_tx #(
        .DATA_BITS  (DATA_BITS),
        .STOP_BITS  (STOP_BITS),
        .PARITY_EN  (PARITY_EN),
        .PARITY_ODD (PARITY_ODD)
    ) u_tx (
        .clk      (clk),
        .rst_n    (rst_n),
        .tick     (baud_tick),
        .tx_start (tx_start_reg),
        .tx_data  (tx_data_reg),
        .tx       (uart_tx_pin),
        .tx_busy  (tx_busy),
        .tx_done  (tx_done)
    );

    // -----------------------------------------------------------------------
    // UART RX Core
    // -----------------------------------------------------------------------
    uart_rx #(
        .DATA_BITS  (DATA_BITS),
        .STOP_BITS  (STOP_BITS),
        .PARITY_EN  (PARITY_EN),
        .PARITY_ODD (PARITY_ODD)
    ) u_rx (
        .clk      (clk),
        .rst_n    (rst_n),
        .tick     (baud_tick),
        .rx       (uart_rx_pin),
        .rx_data  (rx_byte),
        .rx_done  (rx_done_pulse),
        .rx_error (rx_err_pulse)
    );

    // -----------------------------------------------------------------------
    // RX FIFO
    // -----------------------------------------------------------------------
    uart_fifo #(
        .DATA_WIDTH (8),
        .DEPTH      (FIFO_DEPTH)
    ) u_rx_fifo (
        .clk     (clk),
        .rst_n   (rst_n),
        .wr_en   (rx_done_pulse),
        .wr_data (rx_byte),
        .rd_en   (rx_rd_en),
        .rd_data (rx_rd_data),
        .full    (rx_full),
        .empty   (rx_empty),
        .count   ()
    );

    // Latch the error flag: stays HIGH until next read
    reg rx_error_latch;
    always @(posedge clk) begin
        if (!rst_n)
            rx_error_latch <= 1'b0;
        else if (rx_err_pulse)
            rx_error_latch <= 1'b1;
        else if (rx_rd_en)
            rx_error_latch <= 1'b0;
    end
    assign rx_error = rx_error_latch;

endmodule
