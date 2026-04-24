// Verilog testbench mirror of tb_blink_led.vhd.
//
// 50 MHz clock (20 ns period), button toggles, with assertions
// equivalent to the VHDL testbench's report/assert checks.

`timescale 1ns/1ps

module tb_blink_led;

    reg  clk    = 1'b0;
    reg  button = 1'b1;     // active-low: idle = 1
    wire led1;
    wire led2;

    // Match the VHDL TB: CLOCKS_TO_OVERFLOW=10 → 10*20 ns = 200 ns toggle.
    blink_led #(.CLOCKS_TO_OVERFLOW(10)) dut (
        .clk     (clk),
        .button1 (button),
        .led     (led1),
        .led2    (led2)
    );

    // 50 MHz: 10 ns half-period.
    always #10 clk = ~clk;

    // Match the VHDL TB's button schedule.
    initial begin
        button = 1'b1;
        #50  button = 1'b0;
        #40  button = 1'b1;
        #150 button = 1'b0;
        #50  button = 1'b1;
    end

    // Checker process — mirrors tb_blink_led.vhd assertions.
    initial begin
        $dumpfile(`VCD_OUT);
        $dumpvars(0, tb_blink_led);

        @(posedge clk);
        if (!(led1 === 1'b0 && led2 === 1'b0))
            $fatal(1, "Wrong output signals at start");

        @(negedge button);          // first press
        @(posedge clk);
        if (!(led1 === 1'b0 && led2 === 1'b1))
            $fatal(1, "Wrong output signals after first button press");

        // The first press happens around 50 ns; wait into the second
        // pulse half (matches the VHDL TB's "wait for 130 ns" comment).
        #130;
        if (!(led1 === 1'b1 && led2 === 1'b1))
            $fatal(1, "Wrong output signals on second cycle, button not pressed");

        @(negedge button);          // second press
        @(posedge clk);
        if (!(led1 === 1'b1 && led2 === 1'b0))
            $fatal(1, "Wrong output signals on second cycle, button pressed");

        @(posedge button);          // release
        @(posedge clk);
        if (!(led1 === 1'b1 && led2 === 1'b1))
            $fatal(1, "Wrong output signals on second cycle, button released");

        $display("Simulation done!");
        $finish;
    end

endmodule
