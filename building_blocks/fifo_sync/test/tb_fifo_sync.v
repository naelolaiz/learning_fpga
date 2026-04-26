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

    reg                    sSimulationActive = 1'b1;

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

    // Gate the clock on sSimulationActive so the VHDL and Verilog
    // waveforms carry the same shutdown signal.
    always #(CLK_PERIOD/2) if (sSimulationActive) sClk = ~sClk;

    // Level 1 restricts the dump to the TB's own top-level signals and
    // the DUT's top-level signals — loop counters inside `driver` and
    // any function-local hierarchy stay hidden, matching GHDL's VCD.
    initial begin
        $dumpfile(`VCD_OUT);
        $dumpvars(1, tb_fifo_sync);
        $dumpvars(1, dut);
    end

    initial begin : driver
        integer i;

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
        sSimulationActive = 1'b0;
        $finish;
    end

endmodule
