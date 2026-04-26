// Verilog mirror of Serial2Parallel_tb.vhd.
//
// Sweeps every NUMBER_OF_BITS-wide value through the shift register and
// asserts the printed output matches the input pattern. The VHDL TB
// sweeps 0..2^N-1; we keep that exhaustive coverage at N=16 (~65k
// cycles, still fast under iverilog).

`timescale 1ns/1ps

module Serial2Parallel_tb;

    localparam integer NUMBER_OF_BITS = 16;

    reg                       sClock = 1'b0;
    reg                       sData  = 1'b0;
    reg                       sPrint = 1'b0;
    wire [NUMBER_OF_BITS-1:0] sOutData;

    reg  [NUMBER_OF_BITS-1:0] sCounter;

    reg                       sSimulationActive = 1'b1;

    Serial2Parallel #(.NUMBER_OF_BITS(NUMBER_OF_BITS)) dut (
        .inClock (sClock),
        .inData  (sData),
        .inPrint (sPrint),
        .outData (sOutData)
    );

    initial begin
        $dumpfile(`VCD_OUT);
        $dumpvars(1, Serial2Parallel_tb);
        $dumpvars(1, dut);
    end

    initial begin : driver
        integer i, b;

        for (i = 0; i < (1 << NUMBER_OF_BITS); i = i + 1) begin
            sClock   = 1'b0;
            sPrint   = 1'b0;
            sCounter = i[NUMBER_OF_BITS-1:0];
            #1;
            sClock = 1'b1;
            #1;
            for (b = NUMBER_OF_BITS - 1; b >= 0; b = b - 1) begin
                sClock = 1'b0;
                sData  = sCounter[b];
                #1;
                sClock = 1'b1;
                #1;
            end
            sClock = 1'b0;
            #1;
            sPrint = 1'b1;
            sClock = 1'b1;
            #1;
            sData  = 1'b0;
            sClock = 1'b0;
            #1;
            sClock = 1'b1;
            #1;
            if (sCounter !== sOutData)
                $fatal(1, "Error at i=%0d: expected %h got %h", i, sCounter, sOutData);
        end
        $display("Simulation completed!");
        sSimulationActive = 1'b0;
        $finish;
    end

endmodule
