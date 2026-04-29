// tb_rom_lut_methods.v - Verilog mirror of tb_rom_lut_methods.vhd.
//
// Instantiates rom_lut (A: inline initial), rom_lut_hex (B: $readmemh),
// and rom_lut_func (C: $sin elaborated table) in parallel; drives the
// same (angle, nibble) on every edge; asserts the three outputs are
// bit-identical at every step.

`timescale 1ns/1ps

module tb_rom_lut_methods;

    localparam time CLK_PERIOD = 4;

    reg              sClock = 1'b0;
    reg  [6:0]       sAngleIdx  = 7'd0;
    reg  [3:0]       sNibbleIdx = 4'd0;
    wire [9:0]       sOutA, sOutB, sOutC;
    reg              sTestRunning = 1'b1;

    rom_lut      rom_a (
        .clock              (sClock),
        .read_angle_idx     (sAngleIdx),
        .nibble_product_idx (sNibbleIdx),
        .data_out           (sOutA)
    );

    // The Makefile runs vvp with cwd=build/ so the hex file sits one
    // level up from the simulator's perspective. Override the param
    // here rather than baking the relative path into the module.
    rom_lut_hex #(.HEX_FILE("../rom_lut.hex")) rom_b (
        .clock              (sClock),
        .read_angle_idx     (sAngleIdx),
        .nibble_product_idx (sNibbleIdx),
        .data_out           (sOutB)
    );

    rom_lut_func rom_c (
        .clock              (sClock),
        .read_angle_idx     (sAngleIdx),
        .nibble_product_idx (sNibbleIdx),
        .data_out           (sOutC)
    );

    always #(CLK_PERIOD/2.0) if (sTestRunning) sClock = ~sClock;

    initial begin
        $dumpfile(`FST_OUT);
        $dumpvars(1, tb_rom_lut_methods);
        $dumpvars(1, rom_a);
    end

    // Init at declaration so the waveform doesn't render `a`, `n`,
    // `mismatches` red until first written inside the initial block.
    integer a          = 0;
    integer n          = 0;
    integer mismatches = 0;

    initial begin : driver
        mismatches = 0;
        @(negedge sClock);

        for (a = 0; a < 128; a = a + 1) begin
            for (n = 0; n < 16; n = n + 1) begin
                sAngleIdx  = a[6:0];
                sNibbleIdx = n[3:0];
                @(negedge sClock);
                if (sOutA !== sOutB) begin
                    $display("method A != B at (a=%0d, n=%0d): %0d vs %0d",
                             a, n, $signed(sOutA), $signed(sOutB));
                    mismatches = mismatches + 1;
                end
                if (sOutA !== sOutC) begin
                    $display("method A != C at (a=%0d, n=%0d): %0d vs %0d",
                             a, n, $signed(sOutA), $signed(sOutC));
                    mismatches = mismatches + 1;
                end
            end
        end

        if (mismatches != 0)
            $fatal(1, "tb_rom_lut_methods: %0d mismatches", mismatches);

        $display("tb_rom_lut_methods: all three methods agree on every address");
        sTestRunning = 1'b0;
        $finish;
    end

endmodule
