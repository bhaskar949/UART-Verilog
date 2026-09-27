// =============================================================================
// Module      : baud_rate_gen.v
// Description : Baud Rate Generator for UART
//               Generates a tick signal at 16x the baud rate (oversampling).
//
// Parameters  :
//   CLK_FREQ  - System clock frequency in Hz (default: 50 MHz)
//   BAUD_RATE - Desired baud rate (default: 9600)
//
// Output      :
//   tick      - Pulses HIGH for one clock cycle at 16x baud rate
//
// Formula     : DIVISOR = CLK_FREQ / (BAUD_RATE * 16)
// =============================================================================

module baud_rate_gen #(
    parameter CLK_FREQ  = 50_000_000,   // 50 MHz system clock
    parameter BAUD_RATE = 9600           // Default baud rate
)(
    input  wire clk,
    input  wire rst_n,      // Active-low synchronous reset
    output reg  tick        // Oversampling tick (16x baud rate)
);

    // Compute the divisor at elaboration time
    localparam integer DIVISOR = CLK_FREQ / (BAUD_RATE * 16);

    // Counter width: ceil(log2(DIVISOR))
    localparam integer CNT_WIDTH = $clog2(DIVISOR);

    reg [CNT_WIDTH-1:0] count;

    // -----------------------------------------------------------------------
    // Counter: counts up to DIVISOR-1, then resets
    // -----------------------------------------------------------------------
    always @(posedge clk) begin
        if (!rst_n) begin
            count <= 0;
            tick  <= 1'b0;
        end else begin
            if (count == DIVISOR - 1) begin
                count <= 0;
                tick  <= 1'b1;
            end else begin
                count <= count + 1;
                tick  <= 1'b0;
            end
        end
    end

endmodule
