// fifo_sync.v - Verilog mirror of fifo_sync.vhd.
//
// Single-clock FIFO. DEPTH must be a power of two so the pointer
// arithmetic wraps for free. The pointers carry one extra MSB so
// (wr_ptr == rd_ptr) means empty and (MSBs differ AND lower bits
// match) means full — the classic Cliff Cummings idiom.
//
// The `rd_reg`, `s_empty`, `s_full` intermediates mirror the VHDL
// `signal` declarations — same shape in both languages so the two
// waveforms show the same internal signal set.

module fifo_sync #(
    parameter integer DATA_WIDTH = 8,
    parameter integer DEPTH      = 16
) (
    input  wire                   clk,
    input  wire                   rst,
    input  wire                   wr_en,
    input  wire [DATA_WIDTH-1:0]  wr_data,
    input  wire                   rd_en,
    output wire [DATA_WIDTH-1:0]  rd_data,
    output wire                   empty,
    output wire                   full
);

    localparam integer ADDR_W = $clog2(DEPTH);

    reg [DATA_WIDTH-1:0] ram [0:DEPTH-1];
    reg [ADDR_W:0]       wr_ptr = {(ADDR_W+1){1'b0}};
    reg [ADDR_W:0]       rd_ptr = {(ADDR_W+1){1'b0}};
    reg [DATA_WIDTH-1:0] rd_reg = {DATA_WIDTH{1'b0}};

    wire s_empty;
    wire s_full;

    assign s_empty = (wr_ptr == rd_ptr);
    assign s_full  = (wr_ptr[ADDR_W] != rd_ptr[ADDR_W]) &&
                     (wr_ptr[ADDR_W-1:0] == rd_ptr[ADDR_W-1:0]);

    always @(posedge clk) begin
        if (rst) begin
            wr_ptr <= {(ADDR_W+1){1'b0}};
            rd_ptr <= {(ADDR_W+1){1'b0}};
        end else begin
            if (wr_en && !s_full) begin
                ram[wr_ptr[ADDR_W-1:0]] <= wr_data;
                wr_ptr <= wr_ptr + 1'b1;
            end
            if (rd_en && !s_empty) begin
                rd_reg <= ram[rd_ptr[ADDR_W-1:0]];
                rd_ptr <= rd_ptr + 1'b1;
            end
        end
    end

    assign rd_data = rd_reg;
    assign empty   = s_empty;
    assign full    = s_full;

endmodule
