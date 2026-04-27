// Verilog mirror of tb_serial_to_parallel_basic.vhd.
//
// Shifts in 0xB4 MSB-first, pulses inPrint, and asserts the latched
// outData matches.

`timescale 1ns/1ps

module tb_serial_to_parallel_basic;

    localparam integer N = 8;
    localparam [N-1:0] PATTERN = 8'hB4;

    reg          sClock = 1'b0;
    reg          sData  = 1'b0;
    reg          sPrint = 1'b0;
    wire [N-1:0] sOut;

    reg          sSimulationActive = 1'b1;

    Serial2Parallel #(.NUMBER_OF_BITS(N)) dut (
        .inClock (sClock),
        .inData  (sData),
        .inPrint (sPrint),
        .outData (sOut)
    );

    always #10 if (sSimulationActive) sClock = ~sClock;

    initial begin
        $dumpfile(`FST_OUT);
        $dumpvars(1, tb_serial_to_parallel_basic);
        $dumpvars(1, dut);
    end

    integer i = 0;
    initial begin : driver
        for (i = N-1; i >= 0; i = i - 1) begin
            @(negedge sClock);
            sData  = PATTERN[i];
            sPrint = 1'b0;
        end

        @(negedge sClock);
        sPrint = 1'b1;
        @(posedge sClock);
        @(negedge sClock);
        sPrint = 1'b0;

        @(posedge sClock);

        if (sOut !== PATTERN)
            $fatal(1, "outData mismatch: got %h, expected %h", sOut, PATTERN);

        $display("tb_serial_to_parallel_basic simulation done!");
        sSimulationActive = 1'b0;
        $finish;
    end

endmodule
