// Verilog mirror of tb_random_generator_long.vhd.
//
// Long-window TB (12 ms) exercising update + freeze. DIVIDER_MAX /
// ENABLE_HIGH compressed via parameter override so the ~140 ms
// hardware refresh becomes ~50 us in sim.
//
// Two phases:
//   Phase 1 (0..6 ms, inputButtons[0]=1). The character on digit 0
//           must change at least once — proves the shift register is
//           taking new bytes from the LFSR.
//   Phase 2 (6..12 ms, inputButtons[0]=0). With freeze, the digit 0
//           sample must equal the first sample latched in this phase.

`timescale 1ns/1ps

module tb_random_generator_long;

    localparam time TEST_DURATION = 12_000_000;   // 12 ms in ns
    localparam time PHASE1_END    =  6_000_000;   //  6 ms in ns

    // SIM_GATE = SIM_DIVIDER means counterForGenerator never reaches
    // ENABLE_HIGH (it wraps first), so the gate is held open for the
    // whole sim. Keeps the LFSR running continuously, mirroring the
    // VHDL TB and giving plenty of varied bytes to shift in.
    localparam integer SIM_DIVIDER = 2_500;
    localparam integer SIM_GATE    = SIM_DIVIDER;

    reg        sClock50MHz   = 1'b0;
    reg  [3:0] sInputButtons = 4'b1111;
    wire [6:0] sSevenSegments;
    wire [3:0] sCableSelect;
    wire [3:0] sLeds;

    reg sSimulationActive = 1'b1;

    reg [1:0] sPhase = 2'd0;

    reg [6:0] sLastDigit0      = 7'd0;
    reg       sLastDigit0Valid = 1'b0;

    reg [6:0] sFreezeBaseline      = 7'd0;
    reg       sFreezeBaselineValid = 1'b0;

    reg sUpdateObserved = 1'b0;
    reg sFreezeViolated = 1'b0;

    random_generator #(
        .DIVIDER_MAX (SIM_DIVIDER),
        .ENABLE_HIGH (SIM_GATE)
    ) dut (
        .clock         (sClock50MHz),
        .inputButtons  (sInputButtons),
        .sevenSegments (sSevenSegments),
        .cableSelect   (sCableSelect),
        .leds          (sLeds)
    );

    always #10 if (sSimulationActive) sClock50MHz = ~sClock50MHz;

    always @(posedge sClock50MHz) begin
        if (sCableSelect == 4'b1110) begin
            if (sPhase == 2'd1) begin
                if (sLastDigit0Valid && sLastDigit0 !== sSevenSegments)
                    sUpdateObserved <= 1'b1;
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
        $dumpfile(`FST_OUT);
        $dumpvars(1, tb_random_generator_long);
        $dumpvars(1, dut);
    end

    initial begin : driver
        sInputButtons = 4'b1111;
        sPhase        = 2'd1;
        #(PHASE1_END);

        sInputButtons = 4'b1110;
        sPhase        = 2'd2;
        #(TEST_DURATION - PHASE1_END);

        sPhase = 2'd0;

        if (!sUpdateObserved)
            $fatal(1, "shift register stuck: digit-0 nibble never changed during phase 1 (DIVIDER=%0d)", SIM_DIVIDER);

        if (sFreezeViolated)
            $fatal(1, "freeze violated: digit-0 nibble changed during phase 2 with inputButtons[0]=0");

        if (!sFreezeBaselineValid)
            $fatal(1, "phase 2 saw no digit-0 sample at all - TB scheduling bug?");

        $display("tb_random_generator_long simulation done!");
        sSimulationActive = 1'b0;
        $finish;
    end

endmodule
