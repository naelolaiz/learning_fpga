// tb_fifo_sync_overlapping.v - Verilog mirror of tb_fifo_sync_overlapping.vhd.
//
// Covers the one case tb_fifo_sync.v doesn't: what happens when
// wr_en and rd_en are BOTH high on the same cycle. The FIFO should
// handle this atomically — occupancy stays constant, no data is lost
// or duplicated, and FIFO ordering is preserved.
//
// Sequence matches the VHDL TB:
//   1. Reset, pre-fill with HALF values (1..HALF).
//   2. Drive wr_en=1 and rd_en=1 for OVERLAP_N cycles, pushing
//      values 100..100+OVERLAP_N-1.
//   3. Per-cycle assertions: empty=0 and full=0 throughout; rd_data
//      matches the expected FIFO ordering offset by the 1-cycle
//      read latency.
//   4. Drain and assert empty=1 — a lost-data bug would leave residue.

`timescale 1ns/1ps

module tb_fifo_sync_overlapping;

    localparam integer DATA_WIDTH = 8;
    localparam integer DEPTH      = 8;
    localparam integer HALF       = DEPTH / 2;
    localparam integer OVERLAP_N  = 20;
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
    integer expected;

    initial begin
        $dumpfile(`VCD_OUT);
        $dumpvars(0, tb_fifo_sync_overlapping);

        // Release reset.
        #(2*CLK_PERIOD);
        sRst = 1'b0;
        #(CLK_PERIOD);

        // Pre-fill with HALF distinct values (1..HALF).
        for (i = 1; i <= HALF; i = i + 1) begin
            sWrEn   = 1'b1;
            sWrData = i[DATA_WIDTH-1:0];
            #(CLK_PERIOD);
        end
        sWrEn = 1'b0;
        #(CLK_PERIOD);
        if (sEmpty !== 1'b0) $fatal(1, "Should not be empty after pre-fill");
        if (sFull  !== 1'b0) $fatal(1, "Should not be full after pre-fill (HALF < DEPTH)");

        // Overlap phase: both enables high for OVERLAP_N cycles,
        // pushing values 100..100+OVERLAP_N-1 and draining
        // simultaneously.
        for (i = 0; i < OVERLAP_N; i = i + 1) begin
            sWrEn   = 1'b1;
            sRdEn   = 1'b1;
            sWrData = (100 + i);
            #(CLK_PERIOD);

            // Occupancy invariant.
            if (sEmpty !== 1'b0)
                $fatal(1, "overlap cycle %0d: empty unexpectedly high", i);
            if (sFull !== 1'b0)
                $fatal(1, "overlap cycle %0d: full unexpectedly high", i);

            // Ordering invariant: rd_data this cycle is the value
            // whose rd_en pulsed a cycle ago (one-cycle read
            // latency). Matches the VHDL TB's "-1" indexing.
            if (i == 0) begin
                expected = 1;
            end else if (i < HALF) begin
                expected = 1 + i;
            end else begin
                expected = 100 + (i - HALF);
            end
            if (sRdData !== expected[DATA_WIDTH-1:0])
                $fatal(1, "overlap cycle %0d: expected rd_data=%0d, got %0d",
                       i, expected, sRdData);
        end

        // Drain whatever remains; confirm we reach empty.
        sWrEn = 1'b0;
        sRdEn = 1'b1;
        for (i = 0; i <= DEPTH; i = i + 1) begin
            #(CLK_PERIOD);
            if (sEmpty === 1'b1) begin
                i = DEPTH + 10;  // break out
            end
        end
        sRdEn = 1'b0;
        #(CLK_PERIOD);
        if (sEmpty !== 1'b1)
            $fatal(1, "fifo did not drain after overlap phase -- occupancy drift?");

        $display("tb_fifo_sync_overlapping simulation done!");
        $finish;
    end

endmodule
