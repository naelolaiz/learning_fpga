// Verilog mirror of tb_debounce_glitch.vhd.
//
// DEBOUNCE_LIMIT overridden to 100 cycles (2 us at 50 MHz). A single
// ~600 ns glitch — well below the 2 us limit — must NOT propagate to
// the output.

`timescale 1ns/1ps

module tb_debounce_glitch;

    localparam integer SIM_LIMIT = 100;
    localparam time    TEST_DURATION = 8_000;   // 8 us in ns

    reg  sClock50MHz = 1'b0;
    reg  sSwitchIn   = 1'b0;
    wire sSwitchOut;

    reg  sSimulationActive = 1'b1;
    reg  sGlitchLeaked     = 1'b0;

    Debounce #(.DEBOUNCE_LIMIT(SIM_LIMIT)) dut (
        .i_Clk    (sClock50MHz),
        .i_Switch (sSwitchIn),
        .o_Switch (sSwitchOut)
    );

    always #10 if (sSimulationActive) sClock50MHz = ~sClock50MHz;

    // Check for == 1 rather than != 0; sSwitchOut starts as x before
    // the DUT drives it, which would otherwise trip a false positive.
    always @(sSwitchOut) begin
        if (sSwitchOut === 1'b1)
            sGlitchLeaked <= 1'b1;
    end

    initial begin
        $dumpfile(`FST_OUT);
        $dumpvars(1, tb_debounce_glitch);
        $dumpvars(1, dut);
    end

    initial begin : driver
        sSwitchIn = 1'b0;
        #2_000;            // steady-low warmup

        sSwitchIn = 1'b1;
        #600;              // glitch (well under DEBOUNCE_LIMIT)

        sSwitchIn = 1'b0;
        #(TEST_DURATION - 2_000 - 600);

        if (sGlitchLeaked)
            $fatal(1, "o_Switch went high; a sub-DEBOUNCE_LIMIT glitch leaked through");

        $display("tb_debounce_glitch simulation done!");
        sSimulationActive = 1'b0;
        $finish;
    end

endmodule
