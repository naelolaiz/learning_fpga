// tb_rom_lut.v - Verilog mirror of tb_rom_lut.vhd. Drives tl_rom_lut and
// asserts the same six properties (nibble=0 zero, angle=0 zero, mirror
// around PI/2, anti-symmetry across PI, +464 peak, -464 peak).

`timescale 1ns/1ps

module tb_rom_lut;

    localparam time CLK_PERIOD = 4;
    localparam time LATENCY    = 2 * CLK_PERIOD;

    reg              sClock = 1'b0;
    reg  [6:0]       sAngleIdx         = 7'd0;
    reg  [3:0]       sNibbleProductIdx = 4'd0;
    wire [9:0]       sReadByte;
    reg              sTestRunning      = 1'b1;

    tl_rom_lut dut (
        .inClock50Mhz       (sClock),
        .inAngleIdxToRead   (sAngleIdx),
        .inNibbleProductIdx (sNibbleProductIdx),
        .outReadMemory      (sReadByte)
    );

    always #(CLK_PERIOD/2.0) if (sTestRunning) sClock = ~sClock;

    initial begin
        $dumpfile(`FST_OUT);
        $dumpvars(1, tb_rom_lut);
        $dumpvars(1, dut);
    end

    // Initialise the loop locals so the waveform doesn't open with a
    // red `'x` band on `k` and `v_first` before they're first written.
    integer a       = 0;
    integer n       = 0;
    integer k       = 0;
    integer v_first = 0;

    // Drive helpers using `task` so the procedure body sees the
    // testbench signals directly (Verilog procedural assignments
    // don't compose through ports as cleanly as VHDL signal
    // parameters do).
    task drive_and_settle(input integer aa, input integer nn);
        begin
            sAngleIdx         = aa[6:0];
            sNibbleProductIdx = nn[3:0];
            #(LATENCY);
        end
    endtask

    initial begin : driver
        @(negedge sClock);

        // 1) nibble=0 -> output 0 for every angle.
        for (a = 0; a < 128; a = a + 1) begin
            drive_and_settle(a, 0);
            if ($signed(sReadByte) !== 0)
                $fatal(1, "nibble=0 should yield 0; got %0d at angle=%0d",
                       $signed(sReadByte), a);
        end

        // 2) angle=0 -> output 0 for every nibble (sin(0)=0).
        for (n = 0; n < 16; n = n + 1) begin
            drive_and_settle(0, n);
            if ($signed(sReadByte) !== 0)
                $fatal(1, "angle=0 should yield 0; got %0d at nibble=%0d",
                       $signed(sReadByte), n);
        end

        // 3) Peak positive: out(32, 15) = +464.
        drive_and_settle(32, 15);
        if ($signed(sReadByte) !== 464)
            $fatal(1, "peak positive expected 464, got %0d", $signed(sReadByte));

        // 4) Peak negative: out(96, 15) = -464.
        drive_and_settle(96, 15);
        if ($signed(sReadByte) !== -464)
            $fatal(1, "peak negative expected -464, got %0d", $signed(sReadByte));

        // 5) Mirror around PI/2: out(31, n) == out(32, n).
        for (n = 1; n < 16; n = n + 1) begin
            drive_and_settle(31, n);
            v_first = $signed(sReadByte);
            drive_and_settle(32, n);
            if ($signed(sReadByte) !== v_first)
                $fatal(1, "mirror PI/2 broken at nibble=%0d: out(31,n)=%0d vs out(32,n)=%0d",
                       n, v_first, $signed(sReadByte));
        end

        // 6) Anti-symmetry across PI: out(k, 15) == -out(k+64, 15).
        for (k = 0; k < 64; k = k + 1) begin
            drive_and_settle(k, 15);
            v_first = $signed(sReadByte);
            drive_and_settle(k + 64, 15);
            if ($signed(sReadByte) !== -v_first)
                $fatal(1, "antisymmetry broken at k=%0d: out(k,15)=%0d vs out(k+64,15)=%0d",
                       k, v_first, $signed(sReadByte));
        end

        $display("tb_rom_lut: all assertions passed");
        sTestRunning = 1'b0;
        $finish;
    end

endmodule
