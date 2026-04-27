// tb_clock_dot_blink.v - Verilog mirror of tb_clock_dot_blink.vhd.
//
// Cause-effect property: switching `isHHMMMode` from 0 to 1 halves the
// toggle rate of `dotOut`, given the same square-wave input. Drives a
// synthetic 1 Hz square at high simulated frequency, counts edges of
// `dotOut` in each mode, asserts MMSS = 2 * HHMM.

`timescale 1ns/1ps

module tb_clock_dot_blink;

    localparam time SQ_PERIOD = 200;            // shrunk "1 Hz" period
    localparam time SQ_HALF   = SQ_PERIOD / 2;
    localparam time OBSERVE   = 50 * SQ_PERIOD;

    reg  sSquare           = 1'b0;
    reg  sIsHHMMMode       = 1'b0;
    wire sDotOut;
    reg  sSimulationActive = 1'b1;

    integer sEdgesMMSS = 0;
    integer sEdgesHHMM = 0;
    reg     sCountingMMSS = 1'b0;
    reg     sCountingHHMM = 1'b0;
    reg     sLastDot      = 1'b0;

    DotBlinker dut (
        .oneSecondPeriodSquare (sSquare),
        .isHHMMMode            (sIsHHMMMode),
        .dotOut                (sDotOut)
    );

    initial begin
        $dumpfile(`FST_OUT);
        $dumpvars(1, tb_clock_dot_blink);
        $dumpvars(1, dut);
    end

    // Synthetic square-wave generator -- the mirror of the VHDL TB's
    // `square_gen` process.
    initial begin : sq_gen
        while (sSimulationActive) begin
            sSquare = 1'b0;
            #(SQ_HALF);
            sSquare = 1'b1;
            #(SQ_HALF);
        end
    end

    // Edge counter.
    always @(sDotOut) begin
        if (sDotOut !== sLastDot) begin
            if (sCountingMMSS) sEdgesMMSS = sEdgesMMSS + 1;
            else if (sCountingHHMM) sEdgesHHMM = sEdgesHHMM + 1;
            sLastDot = sDotOut;
        end
    end

    initial begin : driver
        #(SQ_PERIOD);

        // Phase 1: MMSS view.
        sIsHHMMMode  = 1'b0;
        sCountingMMSS = 1'b1;
        #(OBSERVE);
        sCountingMMSS = 1'b0;

        // Phase 2: HHMM view.
        sIsHHMMMode  = 1'b1;
        sCountingHHMM = 1'b1;
        #(OBSERVE);
        sCountingHHMM = 1'b0;

        if (!(sEdgesMMSS > 4)) begin
            $display("MMSS view: expected dot toggles, saw %0d", sEdgesMMSS);
            $fatal;
        end
        if (!(sEdgesHHMM > 1)) begin
            $display("HHMM view: expected dot toggles, saw %0d", sEdgesHHMM);
            $fatal;
        end
        if (!(sEdgesMMSS == 2 * sEdgesHHMM)) begin
            $display("expected MMSS edges = 2 * HHMM edges, got MMSS=%0d HHMM=%0d",
                     sEdgesMMSS, sEdgesHHMM);
            $fatal;
        end

        $display("tb_clock_dot_blink PASSED. MMSS edges=%0d HHMM edges=%0d",
                 sEdgesMMSS, sEdgesHHMM);
        sSimulationActive = 1'b0;
        $finish;
    end

endmodule
