// Verilog mirror of tb_text_long.vhd.
//
// Long-window TB (40 ms) exercising scroll + freeze. The DUT's
// SCROLL_MAX parameter is overridden to 250_000 (5 ms scroll period
// in sim) so multiple scroll ticks fit in the window.
//
// Two phases:
//   Phase 1 (0..18 ms, inputButtons[0]=1, no pause). The character
//           on digit 0 must change at least once — proves scroll
//           advances.
//   Phase 2 (18..40 ms, inputButtons[0]=0, pause held). Without
//           freeze, scroll would tick at t=20/25/30/35 ms (all in
//           this window). With freeze, the character on digit 0 must
//           equal the first sample latched in this phase.
//
// No PNG is rendered for this TB (V_NO_WAVEFORM_TBS in the Makefile).
// The assertions still gate CI via $fatal.

`timescale 1ns/1ps

module tb_text_long;

    localparam time TEST_DURATION = 40_000_000;   // 40 ms in ns
    localparam time PHASE1_END    = 18_000_000;   // 18 ms in ns
    localparam integer SIM_SCROLL = 250_000;      // 5 ms scroll period in sim

    reg        sClock50MHz   = 1'b0;
    reg  [3:0] sInputButtons = 4'b1111;
    wire [7:0] sSevenSegments;
    wire [3:0] sCableSelect;

    reg sSimulationActive = 1'b1;

    // Phase tracking. 1 = scrolling, 2 = frozen, 0 = warmup or post.
    reg [1:0] sPhase = 2'd0;

    reg [7:0] sLastDigit0      = 8'd0;
    reg       sLastDigit0Valid = 1'b0;

    reg [7:0] sFreezeBaseline      = 8'd0;
    reg       sFreezeBaselineValid = 1'b0;

    reg sScrollObserved = 1'b0;
    reg sFreezeViolated = 1'b0;

    text #(.SCROLL_MAX(SIM_SCROLL)) dut (
        .clock         (sClock50MHz),
        .inputButtons  (sInputButtons),
        .sevenSegments (sSevenSegments),
        .cableSelect   (sCableSelect)
    );

    always #10 if (sSimulationActive) sClock50MHz = ~sClock50MHz;

    // Sample digit 0. Latches first-sample-per-phase as a baseline,
    // and flags either a scroll-change (phase 1) or a freeze-violation
    // (phase 2) on every subsequent change.
    always @(posedge sClock50MHz) begin
        if (sCableSelect == 4'b1110) begin
            if (sPhase == 2'd1) begin
                if (sLastDigit0Valid && sLastDigit0 !== sSevenSegments)
                    sScrollObserved <= 1'b1;
            end

            if (sPhase == 2'd2) begin
                if (!sFreezeBaselineValid) begin
                    sFreezeBaseline      <= sSevenSegments;
                    sFreezeBaselineValid <= 1'b1;
                end else if (sSevenSegments !== sFreezeBaseline) begin
                    sFreezeViolated <= 1'b1;
                end
            end

            sLastDigit0      <= sSevenSegments;
            sLastDigit0Valid <= 1'b1;
        end
    end

    initial begin
        $dumpfile(`VCD_OUT);
        $dumpvars(1, tb_text_long);
        $dumpvars(1, dut);
    end

    initial begin : driver
        // Phase 1: button released, scroll active.
        sInputButtons = 4'b1111;
        sPhase        = 2'd1;
        #(PHASE1_END);

        // Phase 2: button(0) held, scroll frozen.
        sInputButtons = 4'b1110;
        sPhase        = 2'd2;
        #(TEST_DURATION - PHASE1_END);

        sPhase = 2'd0;

        if (!sScrollObserved)
            $fatal(1, "scroll did not advance: digit-0 character never changed during phase 1 (SIM_SCROLL=%0d)", SIM_SCROLL);

        if (sFreezeViolated)
            $fatal(1, "freeze violated: digit-0 character changed during phase 2 with inputButtons[0]=0");

        if (!sFreezeBaselineValid)
            $fatal(1, "phase 2 saw no digit-0 sample at all - TB scheduling bug?");

        $display("tb_text_long simulation done!");
        sSimulationActive = 1'b0;
        $finish;
    end

endmodule
