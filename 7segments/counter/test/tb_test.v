// Verilog mirror of tb_test.vhd.
//
// Spins the counter for 150 ms of simulated time at 50 MHz so the mux
// gets to cycle through all four digits enough times to be visible in
// the VCD.

`timescale 1ns/1ps

module tb_test;

    // Shorter than the VHDL TB (150 ms) — at 50 MHz the mux ticks every
    // 2 ms, so 5 ms exercises the full digit rotation a few times and
    // keeps iverilog's runtime + VCD size manageable in CI.
    localparam time TEST_DURATION = 5_000_000;     // 5 ms in ns
    reg        sClock50MHz   = 1'b0;
    wire [6:0] sSevenSegments;
    wire [3:0] sCableSelect;

    test dut (
        .clock         (sClock50MHz),
        .sevenSegments (sSevenSegments),
        .cableSelect   (sCableSelect)
    );

    always #10 sClock50MHz = ~sClock50MHz;

    initial begin
        $dumpfile(`VCD_OUT);
        $dumpvars(0, tb_test);
        #(TEST_DURATION);
        $finish;
    end

endmodule
