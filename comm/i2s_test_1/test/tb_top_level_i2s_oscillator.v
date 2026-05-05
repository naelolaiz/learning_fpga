// tb_top_level_i2s_oscillator.v - Verilog mirror of
// tb_top_level_i2s_oscillator.vhd. Same shape, same assertions.

`timescale 1ns/1ps

module tb_top_level_i2s_oscillator;

    localparam time CLK_PERIOD = 20;        // 50 MHz

    reg  iClock50Mhz = 1'b0;
    reg  iReset      = 1'b1;
    wire mclk;
    wire lrclk;
    wire sclk;
    wire sdata;

    reg  sim_active = 1'b1;

    integer mclk_count  = 0;
    integer sclk_count  = 0;
    integer lrclk_count = 0;

    reg [23:0] capture_l = 24'd0;
    reg        capture_l_done = 1'b0;

    top_level_i2s_oscillator dut (
        .iReset          (iReset),
        .iClock50Mhz     (iClock50Mhz),
        .oMasterClock    (mclk),
        .oLeftRightClock (lrclk),
        .oSerialBitClock (sclk),
        .oData           (sdata)
    );

    // The Makefile runs vvp from build/, so $readmemh resolves
    // relative to that cwd. Point the LUT at the project-root copy.
    defparam dut.nco.lut.HEX_FILE = "../sincos_lut.hex";

    always #(CLK_PERIOD/2) if (sim_active) iClock50Mhz = ~iClock50Mhz;

    initial begin
        $dumpfile(`FST_OUT);
        $dumpvars(1, tb_top_level_i2s_oscillator);
        $dumpvars(1, dut);
    end

    // Edge counters.
    always @(posedge mclk)  mclk_count  <= mclk_count + 1;
    always @(posedge sclk)  sclk_count  <= sclk_count + 1;
    always @(lrclk)         lrclk_count <= lrclk_count + 1;

    // Assemble one 24-bit left-channel sample, MSB-first, sampled
    // on BCK rising edges. Skip the first frame (master's reset
    // state still has data_l_i = 0) by waiting for the second lrclk
    // rising edge then its falling edge.
    initial begin : capture_left
        integer bit_idx;
        @(posedge lrclk);
        @(posedge lrclk);
        @(negedge lrclk);
        for (bit_idx = 23; bit_idx >= 0; bit_idx = bit_idx - 1) begin
            @(posedge sclk);
            capture_l[bit_idx] = sdata;
        end
        capture_l_done = 1'b1;
    end

    // Stimulus + assertions.
    initial begin : driver
        iReset = 1'b1;
        #(10*CLK_PERIOD);
        iReset = 1'b0;

        #300_000;       // 300 µs

        if (!(lrclk_count > 40))
            $fatal(1, "lrclk transitioned too few times: %0d", lrclk_count);
        if (!(sclk_count > 1000))
            $fatal(1, "sclk too few rising edges: %0d", sclk_count);
        if (!(mclk_count > 6000))
            $fatal(1, "mclk too few rising edges: %0d", mclk_count);

        if (!capture_l_done)
            $fatal(1, "left-channel capture did not complete in 300us");
        // Strict capture check: must be a known, non-zero 24-bit
        // value. `^capture_l === 1'bx` traps any X bits, which would
        // otherwise sneak past `=== 24'h000000`.
        if (^capture_l === 1'bx)
            $fatal(1, "captured left sample has X bits - LUT not loaded?");
        if (capture_l == 24'h000000)
            $fatal(1, "captured left sample is all-zero - NCO not running?");

        $display("i2s_test_1 simulation done!");
        sim_active = 1'b0;
        $finish;
    end

endmodule
