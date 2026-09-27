// =============================================================================
// Module      : uart_rx.v
// Description : UART Receiver
//               Deserializes an incoming UART serial stream into an 8-bit word.
//               Frame format: [START | D0 | D1 | D2 | D3 | D4 | D5 | D6 | D7 | STOP]
//
//               Uses 16x oversampling for noise-robust bit detection.
//               Samples each bit at the 8th tick (centre of the bit period).
//
// Parameters  :
//   DATA_BITS  - Number of data bits (5-8), default 8
//   STOP_BITS  - Number of stop bits (1 or 2), default 1
//   PARITY_EN  - Enable parity checking (0=none, 1=enabled), default 0
//   PARITY_ODD - 0=even parity, 1=odd parity, default 0
//
// Interface   :
//   clk        - System clock
//   rst_n      - Active-low synchronous reset
//   tick       - 16x baud tick from baud rate generator
//   rx         - Serial RX input line (idle HIGH)
//   rx_data    - 8-bit parallel received data (valid when rx_done)
//   rx_done    - Pulses HIGH for one clk when a valid frame is received
//   rx_error   - HIGH if framing or parity error is detected
// =============================================================================

module uart_rx #(
    parameter DATA_BITS  = 8,   // Number of data bits
    parameter STOP_BITS  = 1,   // Number of stop bits (1 or 2)
    parameter PARITY_EN  = 0,   // Parity enable
    parameter PARITY_ODD = 0    // 0=Even, 1=Odd
)(
    input  wire         clk,
    input  wire         rst_n,
    input  wire         tick,       // 16x baud rate tick
    input  wire         rx,         // Serial RX input
    output reg  [7:0]   rx_data,    // Received parallel data
    output reg          rx_done,    // Done pulse (data valid)
    output reg          rx_error    // Framing/parity error
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
    // Input synchronizer (2-FF) to prevent metastability
    // -----------------------------------------------------------------------
    reg rx_sync1, rx_sync2;
    wire rx_in = rx_sync2;

    always @(posedge clk) begin
        if (!rst_n) begin
            rx_sync1 <= 1'b1;
            rx_sync2 <= 1'b1;
        end else begin
            rx_sync1 <= rx;
            rx_sync2 <= rx_sync1;
        end
    end

    // -----------------------------------------------------------------------
    // Internal registers
    // -----------------------------------------------------------------------
    reg [2:0]   state;
    reg [7:0]   rx_shift;       // Shift register
    reg [3:0]   tick_cnt;       // Tick counter (0-15)
    reg [3:0]   bit_cnt;        // Bit counter
    reg [1:0]   stop_cnt;       // Stop bit counter
    reg         parity_recv;    // Received parity bit
    reg         parity_calc;    // Calculated parity from data bits

    // -----------------------------------------------------------------------
    // FSM + Datapath
    // -----------------------------------------------------------------------
    always @(posedge clk) begin
        if (!rst_n) begin
            state       <= IDLE;
            rx_shift    <= 8'h00;
            rx_data     <= 8'h00;
            tick_cnt    <= 4'd0;
            bit_cnt     <= 4'd0;
            stop_cnt    <= 2'd0;
            parity_recv <= 1'b0;
            parity_calc <= 1'b0;
            rx_done     <= 1'b0;
            rx_error    <= 1'b0;
        end else begin
            rx_done  <= 1'b0;       // Default: not done
            rx_error <= 1'b0;       // Default: no error

            case (state)
                // -----------------------------------------------------------------
                // IDLE: Wait for START bit (falling edge: HIGH -> LOW)
                // -----------------------------------------------------------------
                IDLE: begin
                    tick_cnt <= 4'd0;
                    bit_cnt  <= 4'd0;
                    stop_cnt <= 2'd0;
                    if (!rx_in) begin   // Detected LOW = possible start bit
                        state <= START;
                    end
                end

                // -----------------------------------------------------------------
                // START: Verify START bit at centre (tick 7)
                // -----------------------------------------------------------------
                START: begin
                    if (tick) begin
                        if (tick_cnt == 4'd7) begin
                            if (!rx_in) begin       // Valid start bit confirmed
                                tick_cnt    <= 4'd0;
                                parity_calc <= 1'b0;
                                state       <= DATA;
                            end else begin           // False trigger, return to IDLE
                                state <= IDLE;
                            end
                        end else begin
                            tick_cnt <= tick_cnt + 1;
                        end
                    end
                end

                // -----------------------------------------------------------------
                // DATA: Sample each data bit at tick 15 (centre of bit period)
                // -----------------------------------------------------------------
                DATA: begin
                    if (tick) begin
                        if (tick_cnt == 4'd15) begin
                            tick_cnt    <= 4'd0;
                            rx_shift    <= {rx_in, rx_shift[7:1]};  // LSB first
                            parity_calc <= parity_calc ^ rx_in;     // Accumulate parity
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
                // PARITY: Sample the parity bit (if enabled)
                // -----------------------------------------------------------------
                PARITY: begin
                    if (tick) begin
                        if (tick_cnt == 4'd15) begin
                            tick_cnt    <= 4'd0;
                            parity_recv <= rx_in;
                            state       <= STOP;
                        end else begin
                            tick_cnt <= tick_cnt + 1;
                        end
                    end
                end

                // -----------------------------------------------------------------
                // STOP: Verify STOP bit(s) are HIGH
                // -----------------------------------------------------------------
                STOP: begin
                    if (tick) begin
                        if (tick_cnt == 4'd15) begin
                            tick_cnt <= 4'd0;
                            if (stop_cnt == STOP_BITS - 1) begin
                                // Check framing: STOP must be HIGH
                                if (!rx_in) begin
                                    rx_error <= 1'b1;   // Framing error
                                end else begin
                                    // Check parity if enabled
                                    if (PARITY_EN) begin
                                        if (PARITY_ODD) begin
                                            if (parity_recv != ~parity_calc)
                                                rx_error <= 1'b1;
                                        end else begin
                                            if (parity_recv != parity_calc)
                                                rx_error <= 1'b1;
                                        end
                                    end
                                    rx_data <= rx_shift;
                                    rx_done <= 1'b1;
                                end
                                state <= IDLE;
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
