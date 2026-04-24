// tb_fifo_sync.v - Verilog mirror of tb_fifo_sync.vhd.
//
// Pushes DEPTH words in, asserts full, drains them, asserts the
// ordering and empty. Concurrent read/write behaviour is covered by
// the sibling tb_fifo_sync_overlapping.v.

`timescale 1ns/1ps

module tb_fifo_sync;

    localparam integer DATA_WIDTH = 8;
    localparam integer DEPTH      = 8;
    localparam time    CLK_PERIOD = 20;

    reg                    sClk    = 1'b0;
    reg                    sRst    = 1'b1;
    reg                    sWrEn   = 1'b0;
    reg  [DATA_WIDTH-1:0]  sWrData = {DATA_WIDTH{1'b0}};
    reg                    sRdEn   = 1'b0;
    wire [DATA_WIDTH-1:0]  sRdData;
    wire                   sEmpty;
    wire                   sFull;

    fifo_sync #(.DATA_WIDTH(DATA_WIDTH), .DEPTH(DEPTH)) dut (
        .clk    (sClk),
        .rst    (sRst),
        .wr_en  (sWrEn),
        .wr_data(sWrData),
        .rd_en  (sRdEn),
        .rd_data(sRdData),
        .empty  (sEmpty),
        .full   (sFull)
    );

    always #(CLK_PERIOD/2) sClk = ~sClk;

    integer i;

    initial begin
        $dumpfile(`VCD_OUT);
        $dumpvars(0, tb_fifo_sync);

        #(2*CLK_PERIOD);
        sRst = 1'b0;
        #(CLK_PERIOD);
        if (sEmpty !== 1'b1) $fatal(1, "Should be empty after reset");
        if (sFull  !== 1'b0) $fatal(1, "Should not be full after reset");

        for (i = 0; i < DEPTH; i = i + 1) begin
            sWrEn   = 1'b1;
            sWrData = i[DATA_WIDTH-1:0];
            #(CLK_PERIOD);
        end
        sWrEn = 1'b0;
        #(CLK_PERIOD);
        if (sFull !== 1'b1) $fatal(1, "Should be full after DEPTH writes");

        for (i = 0; i < DEPTH; i = i + 1) begin
            sRdEn = 1'b1;
            #(CLK_PERIOD);
            if (sRdData !== i[DATA_WIDTH-1:0])
                $fatal(1, "Drained mismatch at %0d: %h", i, sRdData);
        end
        sRdEn = 1'b0;
        #(CLK_PERIOD);
        if (sEmpty !== 1'b1) $fatal(1, "Should be empty after drain");

        $display("fifo_sync simulation done!");
        $finish;
    end

endmodule
