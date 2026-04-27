// Verilog mirror of tb_blink_led_minimal.vhd.
// WIDTH=4 -> counter wraps every 16 cycles; MSB toggles every 8.

`timescale 1ns/1ps

module tb_blink_led_minimal;

    reg  sClock50MHz = 1'b0;
    wire sLed;

    reg  sSimulationActive = 1'b1;

    blink_led_minimal #(.WIDTH(4)) dut (
        .clk (sClock50MHz),
        .led (sLed)
    );

    always #10 if (sSimulationActive) sClock50MHz = ~sClock50MHz;

    initial begin
        $dumpfile(`FST_OUT);
        $dumpvars(1, tb_blink_led_minimal);
        $dumpvars(1, dut);
    end

    integer i;
    initial begin : driver
        #1;
        if (sLed !== 1'b0) $fatal(1, "led must start at 0");

        for (i = 0; i < 8; i = i + 1) @(posedge sClock50MHz);
        #1;
        if (sLed !== 1'b1) $fatal(1, "led must be 1 after 8 edges");

        for (i = 0; i < 8; i = i + 1) @(posedge sClock50MHz);
        #1;
        if (sLed !== 1'b0) $fatal(1, "led must be back to 0 after counter wrap");

        $display("Simulation done!");
        sSimulationActive = 1'b0;
        $finish;
    end

endmodule
