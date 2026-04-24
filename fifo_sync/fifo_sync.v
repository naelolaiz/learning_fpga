// fifo_sync.v - Verilog mirror of fifo_sync.vhd.
//
// Single-clock FIFO. DEPTH must be a power of two so the pointer
// arithmetic wraps for free. The pointers carry one extra MSB so
// (wr_ptr == rd_ptr) means empty and (MSBs differ AND lower bits
// match) means full — the classic Cliff Cummings idiom.

module fifo_sync #(
    parameter integer DATA_WIDTH = 8,
    parameter integer DEPTH      = 16
) (
    input  wire                   clk,
    input  wire                   rst,
    input  wire                   wr_en,
    input  wire [DATA_WIDTH-1:0]  wr_data,
    input  wire                   rd_en,
    output reg  [DATA_WIDTH-1:0]  rd_data,
    output wire                   empty,
    output wire                   full
);

    function integer clog2(input integer n);
        integer v, r;
        begin
            v = n - 1;
            r = 0;
            while (v > 0) begin
                r = r + 1;
                v = v >> 1;
            end
            clog2 = r;
        end
    endfunction

    localparam integer ADDR_W = clog2(DEPTH);

    reg [DATA_WIDTH-1:0] ram [0:DEPTH-1];
    reg [ADDR_W:0]       wr_ptr = {(ADDR_W+1){1'b0}};
    reg [ADDR_W:0]       rd_ptr = {(ADDR_W+1){1'b0}};

    assign empty = (wr_ptr == rd_ptr);
    assign full  = (wr_ptr[ADDR_W] != rd_ptr[ADDR_W]) &&
                   (wr_ptr[ADDR_W-1:0] == rd_ptr[ADDR_W-1:0]);

    always @(posedge clk) begin
        if (rst) begin
            wr_ptr <= {(ADDR_W+1){1'b0}};
            rd_ptr <= {(ADDR_W+1){1'b0}};
        end else begin
            if (wr_en && !full) begin
                ram[wr_ptr[ADDR_W-1:0]] <= wr_data;
                wr_ptr <= wr_ptr + 1'b1;
            end
            if (rd_en && !empty) begin
                rd_data <= ram[rd_ptr[ADDR_W-1:0]];
                rd_ptr  <= rd_ptr + 1'b1;
            end
        end
    end

endmodule
