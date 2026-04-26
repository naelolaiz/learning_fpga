// Verilog mirror of tb_debounce_bounce.vhd.
//
// DEBOUNCE_LIMIT is overridden to 100 cycles (2 us at 50 MHz) so the
// whole sequence fits in a short sim window.
//
// Sequence:
//   t = 0..2 us       input held low.
//   t = 2..6 us       input bounces 0/1/0/1 every ~500 ns; no high
//                     stretch crosses DEBOUNCE_LIMIT.
//   t = 6 us onward   input held steady at 1.
//
// Asserts:
//   (A) o_Switch stays 0 throughout the bouncing window.
//   (B) o_Switch is 1 once input has been steady-high for >= 2 us.

`timescale 1ns/1ps

module tb_debounce_bounce;

    localparam integer SIM_LIMIT = 100;
    localparam time    TEST_DURATION = 12_000;   // 12 us in ns

    reg  sClock50MHz = 1'b0;
    reg  sSwitchIn   = 1'b0;
    wire sSwitchOut;

    reg  sSimulationActive = 1'b1;
    reg  sBouncingPhase    = 1'b0;
    reg  sBouncingViolated = 1'b0;

    Debounce #(.DEBOUNCE_LIMIT(SIM_LIMIT)) dut (
        .i_Clk    (sClock50MHz),
        .i_Switch (sSwitchIn),
        .o_Switch (sSwitchOut)
    );

    always #10 if (sSimulationActive) sClock50MHz = ~sClock50MHz;

    // Check for == 1 rather than != 0; sSwitchOut starts as x before
    // the DUT drives it, which would otherwise trip a false positive.
    always @(sSwitchOut) begin
        if (sBouncingPhase && sSwitchOut === 1'b1)
            sBouncingViolated <= 1'b1;
    end

    initial begin
        $dumpfile(`VCD_OUT);
        $dumpvars(1, tb_debounce_bounce);
        $dumpvars(1, dut);
    end

    integer i;
    initial begin : driver
        sSwitchIn = 1'b0;
        #2_000;          // 2 us steady-low warmup

        sBouncingPhase = 1'b1;
        for (i = 0; i < 4; i = i + 1) begin
            sSwitchIn = 1'b1;
            #500;
            sSwitchIn = 1'b0;
            #500;
        end
        sBouncingPhase = 1'b0;

        sSwitchIn = 1'b1;
        #4_000;          // 4 us steady-high (>= 2 us debounce + margin)

        if (sSwitchOut !== 1'b1)
            $fatal(1, "o_Switch did not propagate to 1 after sustained press");

        if (sBouncingViolated)
            $fatal(1, "o_Switch went high during the bouncing window");

        $display("tb_debounce_bounce simulation done!");
        sSimulationActive = 1'b0;
        $finish;
    end

endmodule
