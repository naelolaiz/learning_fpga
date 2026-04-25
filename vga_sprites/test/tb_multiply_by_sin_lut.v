// tb_multiply_by_sin_lut.v — Verilog mirror of tb_multiply_by_sin_lut.vhd.
//
// Unit test for ``multiplyBySinLUT``. Asserts the same four algebraic
// properties as the VHDL TB:
//   (A) odd symmetry in input          L(idx, -x) ≈ -L(idx, +x)
//   (B) anti-symmetry across π         L(idx + 16, x) ≈ -L(idx, x)
//   (C) mirror across π/2              L(16 - idx, x) ≈  L(idx, x)
//   (D) bounded output                 |L(idx, x)| ≤ |x| + 1
//
// Tolerance ±1 (TOL) on (A)–(C) mirrors the VHDL — two's-complement
// truncation makes |-128| vs |+127| asymmetric, which shows up at the
// nibble level as ±1.

`timescale 1ns/1ps

`include "trigonometric_functions.vh"

module tb_multiply_by_sin_lut;

    localparam integer TOL = 1;

    reg  [7:0] sStage            = 8'd0;
    reg  [4:0] sIdx              = 5'd0;
    reg  [7:0] sInput            = 8'd0;
    reg  signed [31:0] sOutput   = 32'd0;
    reg        sClock            = 1'b0;
    reg        sSimulationActive = 1'b1;

    function automatic integer abs_i(input integer v);
        abs_i = (v < 0) ? -v : v;
    endfunction

    // Call the LUT with (idx, signed integer input) and return a signed
    // integer. `idx mod 32` and the 8-bit cast mirror the VHDL helper.
    function automatic integer call_lut(input integer idx, input integer x);
        reg [4:0] vIdx;
        reg [7:0] vIn;
        reg [7:0] vOut;
        begin
            vIdx = idx[4:0];
            vIn  = x[7:0];
            vOut = multiplyBySinLUT(vIdx, vIn);
            call_lut = $signed(vOut);
        end
    endfunction

    initial begin
        $dumpfile(`VCD_OUT);
        $dumpvars(1, tb_multiply_by_sin_lut);
    end

    initial begin : driver
        integer idx, xMag, x;
        integer vPos, vNeg, vRef, vDelta;
        // (A) odd symmetry.
        sStage <= 8'd1;
        for (idx = 0; idx < 32; idx = idx + 1) begin
            for (xMag = 1; xMag <= 127; xMag = xMag + 1) begin
                if ((xMag % 16) == 1 || xMag == 127) begin
                    sIdx   <= idx[4:0];
                    sInput <= xMag[7:0];
                    vPos   = call_lut(idx,  xMag);
                    vNeg   = call_lut(idx, -xMag);
                    vDelta = vPos + vNeg;
                    sOutput <= vPos;
                    if (abs_i(vDelta) > TOL)
                        $fatal(1, "A: odd symmetry broken at idx=%0d |x|=%0d: L(+x)=%0d L(-x)=%0d",
                                  idx, xMag, vPos, vNeg);
                    sClock <= ~sClock;
                    #20;
                end
            end
        end

        // (B) anti-symmetry across π.
        sStage <= 8'd2;
        for (idx = 0; idx < 16; idx = idx + 1) begin
            for (x = -64; x <= 64; x = x + 1) begin
                if ((x % 16) == 0) begin
                    sIdx   <= idx[4:0];
                    sInput <= x[7:0];
                    vPos   = call_lut(idx,      x);
                    vRef   = call_lut(idx + 16, x);
                    vDelta = vPos + vRef;
                    sOutput <= vPos;
                    if (abs_i(vDelta) > TOL)
                        $fatal(1, "B: anti-symmetry across pi broken at idx=%0d x=%0d: L(idx)=%0d L(idx+16)=%0d",
                                  idx, x, vPos, vRef);
                    sClock <= ~sClock;
                    #20;
                end
            end
        end

        // (C) mirror across π/2.
        sStage <= 8'd3;
        for (idx = 1; idx < 16; idx = idx + 1) begin
            for (x = -64; x <= 64; x = x + 1) begin
                if ((x % 16) == 0) begin
                    sIdx   <= idx[4:0];
                    sInput <= x[7:0];
                    vPos   = call_lut(idx,      x);
                    vRef   = call_lut(16 - idx, x);
                    vDelta = vPos - vRef;
                    sOutput <= vPos;
                    if (abs_i(vDelta) > TOL)
                        $fatal(1, "C: mirror across pi/2 broken at idx=%0d x=%0d: L(idx)=%0d L(16-idx)=%0d",
                                  idx, x, vPos, vRef);
                    sClock <= ~sClock;
                    #20;
                end
            end
        end

        // (D) |L(idx, x)| <= |x| + 1.
        sStage <= 8'd4;
        for (idx = 0; idx < 32; idx = idx + 1) begin
            for (x = -127; x <= 127; x = x + 1) begin
                if ((x % 32) == 0 || x == 127 || x == -127) begin
                    sIdx   <= idx[4:0];
                    sInput <= x[7:0];
                    vPos   = call_lut(idx, x);
                    sOutput <= vPos;
                    if (abs_i(vPos) > abs_i(x) + 1)
                        $fatal(1, "D: bound |L(idx,x)| > |x|+1 at idx=%0d x=%0d L=%0d",
                                  idx, x, vPos);
                    sClock <= ~sClock;
                    #20;
                end
            end
        end

        sStage <= 8'd99;
        $display("tb_multiply_by_sin_lut simulation done!");
        sSimulationActive <= 1'b0;
        $finish;
    end

endmodule
