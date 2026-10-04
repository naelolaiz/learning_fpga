// sprite_rotator.v — Verilog mirror of sprite_rotator.vhd.
//
// Pipelined version of rotate_x / rotate_y from
// trigonometric_functions.vh:
//
//   x' = cos(r)*x - sin(r)*y
//   y' = sin(r)*x + cos(r)*y
//
//   stage 1   registers the four products cos*x, sin*y, sin*x, cos*y
//   stage 2   registers the two sums
//
// outPosition* / outValid lag inPosition* / inValid by two clocks; a
// new request can enter every clock. Positions are relative to the
// centre of rotation and each axis must fit in a signed byte
// (-128 .. 127). The block knows nothing about the sprite it serves,
// which is what lets one rotator be shared by several sprites.

`timescale 1ns/1ps

`include "trigonometric_functions.vh"

module sprite_rotator (
    input  wire               inClock,
    input  wire               inValid,
    input  wire signed [31:0] inPositionX,      // centre-relative
    input  wire signed [31:0] inPositionY,
    input  wire        [4:0]  inRotation,       // 32 steps per turn
    output wire               outValid,
    output wire signed [31:0] outPositionX,
    output wire signed [31:0] outPositionY
);

    // Stage 1 registers.
    reg signed [7:0] sCosX   = 8'sd0;
    reg signed [7:0] sSinY   = 8'sd0;
    reg signed [7:0] sSinX   = 8'sd0;
    reg signed [7:0] sCosY   = 8'sd0;
    reg              sValid1 = 1'b0;

    // Stage 2 registers.
    reg signed [31:0] sPositionX = 32'sd0;
    reg signed [31:0] sPositionY = 32'sd0;
    reg               sValid2    = 1'b0;

    always @(posedge inClock) begin
        // Stage 1: multiply.
        sCosX   <= $signed(multiplyByCosLUT(inRotation, inPositionX[7:0]));
        sSinY   <= $signed(multiplyBySinLUT(inRotation, inPositionY[7:0]));
        sSinX   <= $signed(multiplyBySinLUT(inRotation, inPositionX[7:0]));
        sCosY   <= $signed(multiplyByCosLUT(inRotation, inPositionY[7:0]));
        sValid1 <= inValid;

        // Stage 2: add.
        sPositionX <= sCosX - sSinY;
        sPositionY <= sSinX + sCosY;
        sValid2    <= sValid1;
    end

    assign outPositionX = sPositionX;
    assign outPositionY = sPositionY;
    assign outValid     = sValid2;

endmodule
