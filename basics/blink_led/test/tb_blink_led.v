// Verilog testbench mirror of tb_blink_led.vhd.
//
// 50 MHz clock (20 ns period), button toggles, with assertions
// equivalent to the VHDL testbench's report/assert checks.
//
// Signal names use the same `s`-prefix convention as the VHDL
// mirror (sClock50MHz, sButton, sLed1, sLed2) so the two waveforms
// show identically-named signals side by side in the gallery.

`timescale 1ns/1ps

module tb_blink_led;

    reg  sClock50MHz = 1'b0;
    reg  sButton     = 1'b1;     // active-low: idle = 1
    wire sLed1;
    wire sLed2;

    reg  sSimulationActive = 1'b1;

    // Match the VHDL TB: CLOCKS_TO_OVERFLOW=10 → 10*20 ns = 200 ns toggle.
    blink_led #(.CLOCKS_TO_OVERFLOW(10)) dut (
        .clk     (sClock50MHz),
        .button1 (sButton),
        .led     (sLed1),
        .led2    (sLed2)
    );

    // 50 MHz: 10 ns half-period.
    always #10 if (sSimulationActive) sClock50MHz = ~sClock50MHz;

    // Match the VHDL TB's button schedule.
    initial begin
        sButton = 1'b1;
        #50  sButton = 1'b0;
        #40  sButton = 1'b1;
        #150 sButton = 1'b0;
        #50  sButton = 1'b1;
    end

    initial begin
        $dumpfile(`VCD_OUT);
        $dumpvars(1, tb_blink_led);
        $dumpvars(1, dut);
    end

    // Checker process — mirrors tb_blink_led.vhd assertions.
    initial begin : driver
        @(posedge sClock50MHz);
        if (!(sLed1 === 1'b0 && sLed2 === 1'b0))
            $fatal(1, "Wrong output signals at start");

        @(negedge sButton);          // first press
        @(posedge sClock50MHz);
        if (!(sLed1 === 1'b0 && sLed2 === 1'b1))
            $fatal(1, "Wrong output signals after first button press");

        // The first press happens around 50 ns; wait into the second
        // pulse half (matches the VHDL TB's "wait for 130 ns" comment).
        #130;
        if (!(sLed1 === 1'b1 && sLed2 === 1'b1))
            $fatal(1, "Wrong output signals on second cycle, button not pressed");

        @(negedge sButton);          // second press
        @(posedge sClock50MHz);
        if (!(sLed1 === 1'b1 && sLed2 === 1'b0))
            $fatal(1, "Wrong output signals on second cycle, button pressed");

        @(posedge sButton);          // release
        @(posedge sClock50MHz);
        if (!(sLed1 === 1'b1 && sLed2 === 1'b1))
            $fatal(1, "Wrong output signals on second cycle, button released");

        $display("Simulation done!");
        sSimulationActive = 1'b0;
        $finish;
    end

endmodule
