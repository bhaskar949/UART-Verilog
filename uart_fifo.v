// =============================================================================
// Module      : uart_fifo.v
// Description : Synchronous FIFO buffer for UART TX/RX data buffering.
//               Parameterizable depth and data width.
//               Supports full/empty flag generation.
//
// Parameters  :
//   DATA_WIDTH - Width of each FIFO entry (default: 8 bits)
//   DEPTH      - Number of entries in FIFO (must be power of 2, default: 16)
//
// Interface   :
//   clk        - System clock
//   rst_n      - Active-low synchronous reset
//   wr_en      - Write enable
//   wr_data    - Data to write
//   rd_en      - Read enable
//   rd_data    - Data read out
//   full       - FIFO is full
//   empty      - FIFO is empty
//   count      - Number of entries currently in FIFO
// =============================================================================

module uart_fifo #(
    parameter DATA_WIDTH = 8,
    parameter DEPTH      = 16
)(
    input  wire                     clk,
    input  wire                     rst_n,
    // Write port
    input  wire                     wr_en,
    input  wire [DATA_WIDTH-1:0]    wr_data,
    // Read port
    input  wire                     rd_en,
    output wire [DATA_WIDTH-1:0]    rd_data,
    // Status
    output wire                     full,
    output wire                     empty,
    output wire [$clog2(DEPTH):0]   count
);

    localparam ADDR_WIDTH = $clog2(DEPTH);

    // -----------------------------------------------------------------------
    // Storage memory
    // -----------------------------------------------------------------------
    reg [DATA_WIDTH-1:0] mem [0:DEPTH-1];

    // -----------------------------------------------------------------------
    // Pointers (extra bit for full/empty detection)
    // -----------------------------------------------------------------------
    reg [ADDR_WIDTH:0] wr_ptr;
    reg [ADDR_WIDTH:0] rd_ptr;

    // -----------------------------------------------------------------------
    // Status flags
    // -----------------------------------------------------------------------
    assign empty = (wr_ptr == rd_ptr);
    assign full  = (wr_ptr[ADDR_WIDTH] != rd_ptr[ADDR_WIDTH]) &&
                   (wr_ptr[ADDR_WIDTH-1:0] == rd_ptr[ADDR_WIDTH-1:0]);
    assign count = wr_ptr - rd_ptr;

    // -----------------------------------------------------------------------
    // Read data (synchronous read)
    // -----------------------------------------------------------------------
    assign rd_data = mem[rd_ptr[ADDR_WIDTH-1:0]];

    // -----------------------------------------------------------------------
    // Write logic
    // -----------------------------------------------------------------------
    always @(posedge clk) begin
        if (!rst_n) begin
            wr_ptr <= 0;
        end else if (wr_en && !full) begin
            mem[wr_ptr[ADDR_WIDTH-1:0]] <= wr_data;
            wr_ptr <= wr_ptr + 1;
        end
    end

    // -----------------------------------------------------------------------
    // Read logic
    // -----------------------------------------------------------------------
    always @(posedge clk) begin
        if (!rst_n) begin
            rd_ptr <= 0;
        end else if (rd_en && !empty) begin
            rd_ptr <= rd_ptr + 1;
        end
    end

endmodule
