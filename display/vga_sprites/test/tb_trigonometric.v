// tb_trigonometric.v — Verilog mirror of tb_trigonometric.vhd.
//
// Two concurrent drivers:
//   check_properties  — algebraic property checks on multiplyBySinLUT
//                       and rotate(); failures call $fatal.
//   sweep_for_waveform — stimulus sweep into signals so the gallery
//                        PNG shows rotate() output over a (x,y) grid.
//
// The sweep deliberately does not gate on the checker — the waveform
// is produced even if assertions fail, so the gallery reflects what
// the LUT is actually computing at the point of failure.

`timescale 1ns/1ps

`include "trigonometric_functions.vh"

module tb_trigonometric;

    // Signals driven by the sweep (visible in the GTKWave PNG).
    reg  [4:0]         indexForTableStdTestRotate = 5'd0;
    reg  signed [31:0] sInputPosX                  = 32'd0;
    reg  signed [31:0] sInputPosY                  = 32'd0;
    reg  signed [31:0] sOutputPosX                 = 32'd0;
    reg  signed [31:0] sOutputPosY                 = 32'd0;
    reg                sClock                      = 1'b0;

    // Signals the checker drives so its progress is also visible.
    reg  [7:0]         checkerStage      = 8'd0;
    reg  [4:0]         checkerLUTIndex   = 5'd0;
    reg  [7:0]         checkerLUTInput   = 8'd0;
    reg  [7:0]         checkerLUTOutput  = 8'd0;

    reg                sSimulationActive = 1'b1;

    localparam integer SPRITE_SIZE_CHECK_W = 11;
    localparam integer SPRITE_SIZE_CHECK_H = 11;

    initial begin
        $dumpfile(`VCD_OUT);
        $dumpvars(1, tb_trigonometric);
    end

    function automatic integer abs_i(input integer v);
        abs_i = (v < 0) ? -v : v;
    endfunction

    // --- check_properties -------------------------------------------------
    initial begin : check_properties
        integer ci, cpx, cpy;
        reg  [4:0] cv_idx;
        reg  [7:0] cv_input;
        reg  [7:0] cv_output;
        integer cv_rotX_pos, cv_rotY_pos;
        integer cv_rotX_neg, cv_rotY_neg;
        // Stage 1: sin(0)*x == 0 for every x.
        checkerStage <= 8'd1;
        for (ci = -128; ci <= 127; ci = ci + 1) begin
            cv_idx    = 5'd0;
            cv_input  = ci[7:0];
            cv_output = multiplyBySinLUT(cv_idx, cv_input);
            checkerLUTIndex  <= cv_idx;
            checkerLUTInput  <= cv_input;
            checkerLUTOutput <= cv_output;
            if (cv_output !== 8'b00000000)
                $fatal(1, "sin(0)*x should be 0, got %0d for input %0d", $signed(cv_output), ci);
            #50;
        end

        // Stage 2: sin(pi)*x == 0.
        checkerStage <= 8'd2;
        for (ci = -128; ci <= 127; ci = ci + 1) begin
            cv_idx    = 5'd16;
            cv_input  = ci[7:0];
            cv_output = multiplyBySinLUT(cv_idx, cv_input);
            checkerLUTIndex  <= cv_idx;
            checkerLUTInput  <= cv_input;
            checkerLUTOutput <= cv_output;
            if (cv_output !== 8'b00000000)
                $fatal(1, "sin(pi)*x should be 0, got %0d for input %0d", $signed(cv_output), ci);
            #50;
        end

        // Stage 3: sin(·)*0 == 0.
        checkerStage <= 8'd3;
        for (ci = 0; ci < 32; ci = ci + 1) begin
            cv_idx    = ci[4:0];
            cv_input  = 8'd0;
            cv_output = multiplyBySinLUT(cv_idx, cv_input);
            checkerLUTIndex  <= cv_idx;
            checkerLUTInput  <= cv_input;
            checkerLUTOutput <= cv_output;
            if (cv_output !== 8'b00000000)
                $fatal(1, "sin(idx)*0 should be 0, got %0d for idx %0d", $signed(cv_output), ci);
            #50;
        end

        // Stage 4: rotate((0,0), idx) == (0,0).
        checkerStage <= 8'd4;
        for (ci = 0; ci < 32; ci = ci + 1) begin
            cv_idx = ci[4:0];
            cv_rotX_pos = rotate_x(SPRITE_SIZE_CHECK_W, SPRITE_SIZE_CHECK_H, 0, 0, cv_idx);
            cv_rotY_pos = rotate_y(SPRITE_SIZE_CHECK_W, SPRITE_SIZE_CHECK_H, 0, 0, cv_idx);
            if ((cv_rotX_pos !== 0) || (cv_rotY_pos !== 0))
                $fatal(1, "rotate((0,0), idx=%0d) should be (0,0), got (%0d, %0d)",
                          ci, cv_rotX_pos, cv_rotY_pos);
            #50;
        end

        // Stage 5: rotate linearity (±2 tolerance per axis, per VHDL TB).
        checkerStage <= 8'd5;
        for (ci = 0; ci < 32; ci = ci + 1) begin
            cv_idx = ci[4:0];
            for (cpx = 1; cpx <= 5; cpx = cpx + 1) begin
                for (cpy = 1; cpy <= 5; cpy = cpy + 1) begin
                    cv_rotX_pos = rotate_x(SPRITE_SIZE_CHECK_W, SPRITE_SIZE_CHECK_H,  cpx*10,  cpy*10, cv_idx);
                    cv_rotY_pos = rotate_y(SPRITE_SIZE_CHECK_W, SPRITE_SIZE_CHECK_H,  cpx*10,  cpy*10, cv_idx);
                    cv_rotX_neg = rotate_x(SPRITE_SIZE_CHECK_W, SPRITE_SIZE_CHECK_H, -cpx*10, -cpy*10, cv_idx);
                    cv_rotY_neg = rotate_y(SPRITE_SIZE_CHECK_W, SPRITE_SIZE_CHECK_H, -cpx*10, -cpy*10, cv_idx);
                    if ((abs_i(cv_rotX_neg + cv_rotX_pos) > 2) ||
                        (abs_i(cv_rotY_neg + cv_rotY_pos) > 2))
                        $fatal(1, "rotate linearity broken at idx=%0d pos=(%0d,%0d): rot(+)=(%0d,%0d) rot(-)=(%0d,%0d)",
                                  ci, cpx*10, cpy*10, cv_rotX_pos, cv_rotY_pos, cv_rotX_neg, cv_rotY_neg);
                    #50;
                end
            end
        end

        checkerStage <= 8'd99;
    end

    // --- sweep_for_waveform -----------------------------------------------
    initial begin : sweep_for_waveform
        integer sr, sx, sy;
        integer vOutX, vOutY;
        for (sr = 0; sr < 32; sr = sr + 1) begin
            indexForTableStdTestRotate <= sr[4:0];
            for (sx = -5; sx <= 5; sx = sx + 1) begin
                for (sy = -5; sy <= 5; sy = sy + 1) begin
                    sClock <= 1'b0;
                    #500;
                    sInputPosX <= sx;
                    sInputPosY <= sy;
                    vOutX = rotate_x(11, 11, sx, sy, sr[4:0]);
                    vOutY = rotate_y(11, 11, sx, sy, sr[4:0]);
                    sOutputPosX <= vOutX;
                    sOutputPosY <= vOutY;
                    sClock <= 1'b1;
                    #1000;
                end
            end
        end
        sSimulationActive <= 1'b0;
        $finish;
    end

endmodule
