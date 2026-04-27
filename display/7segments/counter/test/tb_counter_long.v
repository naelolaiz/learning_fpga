// Verilog mirror of tb_counter_long.vhd.
//
// Long-window companion to tb_counter.v (10 ms, shows clock edges +
// mux rotation). This one runs for 150 ms so the internal
// numberToDisplay counter — which ticks every ~62.5 ms — is
// observed incrementing.
//
// No PNG is generated for this testbench (see V_NO_PNG_TBS in the
// Makefile): at 150 ms the 20 ns clock period is sub-pixel in the
// gallery image anyway, and the TB's value is its assertion, not
// its waveform. The FST still dumps (to keep the flow uniform) and
// the assertion guards CI via the $fatal exit code.
//
// Assertion:
//   By end-of-sim, sevenSegments must have shown a non-zero BCD
//   encoding while digit 0 was mux-selected — i.e. numberToDisplay
//   has incremented past 0. A stuck counter fails here.

`timescale 1ns/1ps

module tb_counter_long;

    localparam time TEST_DURATION = 150_000_000;   // 150 ms in ns

    reg        sClock50MHz = 1'b0;
    wire [6:0] sSevenSegments;
    wire [3:0] sCableSelect;

    reg sCounterTicked = 1'b0;

    reg sSimulationActive = 1'b1;

    // Encoding for digit "0" on the DUT's 7seg bus. Anything else
    // while digit 0 is selected means the counter has advanced.
    localparam [6:0] ENCODING_ZERO = 7'b1000000;

    counter dut (
        .clock         (sClock50MHz),
        .sevenSegments (sSevenSegments),
        .cableSelect   (sCableSelect)
    );

    always #10 if (sSimulationActive) sClock50MHz = ~sClock50MHz;

    always @(posedge sClock50MHz) begin
        if (sCableSelect == 4'b1110 && sSevenSegments !== ENCODING_ZERO) begin
            sCounterTicked <= 1'b1;
        end
    end

    initial begin
        $dumpfile(`FST_OUT);
        $dumpvars(1, tb_counter_long);
        $dumpvars(1, dut);
    end

    initial begin : driver
        #(TEST_DURATION);

        if (!sCounterTicked)
            $fatal(1, "counter stuck: numberToDisplay never incremented in 150 ms");

        $display("tb_counter_long simulation done!");
        sSimulationActive = 1'b0;
        $finish;
    end

endmodule
