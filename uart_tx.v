// =============================================================================
// Module      : uart_tx.v
// Description : UART Transmitter
//               Serializes an 8-bit data word into a UART frame:
//               [START | D0 | D1 | D2 | D3 | D4 | D5 | D6 | D7 | STOP]
//
//               Uses 16x oversampling tick from baud_rate_gen.
//               Supports optional parity (even/odd) via parameter.
//
// Parameters  :
//   DATA_BITS  - Number of data bits (5-8), default 8
//   STOP_BITS  - Number of stop bits (1 or 2), default 1
//   PARITY_EN  - Enable parity bit (0=none, 1=enabled), default 0
//   PARITY_ODD - 0=even parity, 1=odd parity, default 0
//
// Interface   :
//   clk        - System clock
//   rst_n      - Active-low synchronous reset
//   tick       - 16x baud tick from baud rate generator
//   tx_start   - Pulse HIGH for one clk cycle to start transmission
//   tx_data    - 8-bit parallel data to transmit
//   tx         - Serial output line (idle HIGH)
//   tx_busy    - HIGH while transmitting
//   tx_done    - Pulses HIGH for one clk when frame is complete
// =============================================================================

module uart_tx #(
    parameter DATA_BITS  = 8,   // Number of data bits
    parameter STOP_BITS  = 1,   // Number of stop bits (1 or 2)
    parameter PARITY_EN  = 0,   // Parity enable
    parameter PARITY_ODD = 0    // 0=Even, 1=Odd
)(
    input  wire             clk,
    input  wire             rst_n,
    input  wire             tick,       // 16x baud rate tick
    input  wire             tx_start,   // Start transmission
    input  wire [7:0]       tx_data,    // Data to transmit
    output reg              tx,         // Serial TX line
    output reg              tx_busy,    // Busy flag
    output reg              tx_done     // Done pulse
);

    // -----------------------------------------------------------------------
    // FSM States
    // -----------------------------------------------------------------------
    localparam [2:0]
        IDLE   = 3'd0,
        START  = 3'd1,
        DATA   = 3'd2,
        PARITY = 3'd3,
        STOP   = 3'd4;

    // -----------------------------------------------------------------------
    // Internal registers
    // -----------------------------------------------------------------------
    reg [2:0]           state;
    reg [7:0]           tx_shift;       // Shift register for data
    reg [3:0]           tick_cnt;       // 16-tick counter per bit
    reg [3:0]           bit_cnt;        // Bit position counter
    reg [1:0]           stop_cnt;       // Stop bit counter
    reg                 parity_bit;     // Computed parity

    // -----------------------------------------------------------------------
    // FSM + Datapath
    // -----------------------------------------------------------------------
    always @(posedge clk) begin
        if (!rst_n) begin
            state      <= IDLE;
            tx         <= 1'b1;         // Line idle = HIGH
            tx_busy    <= 1'b0;
            tx_done    <= 1'b0;
            tx_shift   <= 8'h00;
            tick_cnt   <= 4'd0;
            bit_cnt    <= 4'd0;
            stop_cnt   <= 2'd0;
            parity_bit <= 1'b0;
        end else begin
            tx_done <= 1'b0;            // Default: done is not asserted

            case (state)
                // -----------------------------------------------------------------
                // IDLE: Wait for tx_start pulse
                // -----------------------------------------------------------------
                IDLE: begin
                    tx      <= 1'b1;
                    tx_busy <= 1'b0;
                    if (tx_start) begin
                        tx_shift   <= tx_data;
                        parity_bit <= (PARITY_ODD) ? ~(^tx_data) : (^tx_data);
                        tick_cnt   <= 4'd0;
                        bit_cnt    <= 4'd0;
                        stop_cnt   <= 2'd0;
                        tx_busy    <= 1'b1;
                        state      <= START;
                    end
                end

                // -----------------------------------------------------------------
                // START: Transmit START bit (LOW) for 16 ticks
                // -----------------------------------------------------------------
                START: begin
                    tx <= 1'b0;
                    if (tick) begin
                        if (tick_cnt == 4'd15) begin
                            tick_cnt <= 4'd0;
                            state    <= DATA;
                        end else begin
                            tick_cnt <= tick_cnt + 1;
                        end
                    end
                end

                // -----------------------------------------------------------------
                // DATA: Transmit data bits LSB first, 16 ticks each
                // -----------------------------------------------------------------
                DATA: begin
                    tx <= tx_shift[0];
                    if (tick) begin
                        if (tick_cnt == 4'd15) begin
                            tick_cnt <= 4'd0;
                            tx_shift <= {1'b0, tx_shift[7:1]}; // Shift right
                            if (bit_cnt == DATA_BITS - 1) begin
                                bit_cnt <= 4'd0;
                                state   <= (PARITY_EN) ? PARITY : STOP;
                            end else begin
                                bit_cnt <= bit_cnt + 1;
                            end
                        end else begin
                            tick_cnt <= tick_cnt + 1;
                        end
                    end
                end

                // -----------------------------------------------------------------
                // PARITY: Transmit parity bit (if enabled)
                // -----------------------------------------------------------------
                PARITY: begin
                    tx <= parity_bit;
                    if (tick) begin
                        if (tick_cnt == 4'd15) begin
                            tick_cnt <= 4'd0;
                            state    <= STOP;
                        end else begin
                            tick_cnt <= tick_cnt + 1;
                        end
                    end
                end

                // -----------------------------------------------------------------
                // STOP: Transmit STOP bit(s) HIGH, 16 ticks each
                // -----------------------------------------------------------------
                STOP: begin
                    tx <= 1'b1;
                    if (tick) begin
                        if (tick_cnt == 4'd15) begin
                            tick_cnt <= 4'd0;
                            if (stop_cnt == STOP_BITS - 1) begin
                                tx_done <= 1'b1;
                                state   <= IDLE;
                            end else begin
                                stop_cnt <= stop_cnt + 1;
                            end
                        end else begin
                            tick_cnt <= tick_cnt + 1;
                        end
                    end
                end

                default: state <= IDLE;
            endcase
        end
    end

endmodule
