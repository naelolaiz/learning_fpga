// Verilog mirror of tb_serial_to_parallel_print_gating.vhd.
//
// (A) outData stays at 0 while inPrint=0 even though shift is happening.
// (B) After a print pulse, outData latches; subsequent shifting with
//     inPrint=0 must not perturb that snapshot until the next pulse.

`timescale 1ns/1ps

module tb_serial_to_parallel_print_gating;

    localparam integer N = 8;
    localparam [N-1:0] PATTERN_A = 8'hB4;
    localparam [N-1:0] PATTERN_B = 8'h53;

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

    task automatic shift_in(input [N-1:0] pat);
        integer j;
        begin
            j = 0;          // initialise so waveview doesn't render an x stripe before first iter
            for (j = N-1; j >= 0; j = j - 1) begin
                @(negedge sClock);
                sData = pat[j];
            end
        end
    endtask

    initial begin
        $dumpfile(`VCD_OUT);
        $dumpvars(1, tb_serial_to_parallel_print_gating);
        $dumpvars(1, dut);
    end

    reg [N-1:0] snapshotA = {N{1'b0}};
    initial begin : driver
        sPrint = 1'b0;
        shift_in(PATTERN_A);

        @(posedge sClock);
        if (sOut !== {N{1'b0}})
            $fatal(1, "outData changed while inPrint=0; snapshot register is leaking (got %h)", sOut);

        @(negedge sClock);
        sPrint = 1'b1;
        @(posedge sClock);
        @(negedge sClock);
        sPrint = 1'b0;

        @(posedge sClock);
        if (sOut !== PATTERN_A)
            $fatal(1, "snapshot mismatch after first print pulse: got %h, expected %h", sOut, PATTERN_A);
        snapshotA = sOut;

        shift_in(PATTERN_B);

        @(posedge sClock);
        if (sOut !== snapshotA)
            $fatal(1, "snapshot drifted while inPrint=0: got %h, expected %h", sOut, snapshotA);

        @(negedge sClock);
        sPrint = 1'b1;
        @(posedge sClock);
        @(negedge sClock);
        sPrint = 1'b0;
        @(posedge sClock);

        if (sOut !== PATTERN_B)
            $fatal(1, "second snapshot did not capture PATTERN_B: got %h, expected %h", sOut, PATTERN_B);

        $display("tb_serial_to_parallel_print_gating simulation done!");
        sSimulationActive = 1'b0;
        $finish;
    end

endmodule
