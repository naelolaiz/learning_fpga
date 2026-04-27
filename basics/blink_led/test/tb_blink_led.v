// Verilog testbench mirror of tb_blink_led.vhd.
//
// 50 MHz clock (20 ns period); CLOCKS_TO_OVERFLOW=10 makes the led
// toggle every 200 ns of sim time.

`timescale 1ns/1ps

module tb_blink_led;

    reg  sClock50MHz = 1'b0;
    wire sLed;

    reg  sSimulationActive = 1'b1;

    blink_led #(.CLOCKS_TO_OVERFLOW(10)) dut (
        .clk (sClock50MHz),
        .led (sLed)
    );

    always #10 if (sSimulationActive) sClock50MHz = ~sClock50MHz;

    initial begin
        $dumpfile(`FST_OUT);
        $dumpvars(1, tb_blink_led);
        $dumpvars(1, dut);
    end

    initial begin : driver
        #1;
        if (sLed !== 1'b0) $fatal(1, "led must start at 0");

        #200;
        if (sLed !== 1'b1) $fatal(1, "led must be 1 after first 200 ns window");

        #200;
        if (sLed !== 1'b0) $fatal(1, "led must be back to 0 after second window");

        $display("Simulation done!");
        sSimulationActive = 1'b0;
        $finish;
    end

endmodule
