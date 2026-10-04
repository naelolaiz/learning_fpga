// tb_sprite_rotator.v — Verilog mirror of tb_sprite_rotator.vhd.
//
// Checks sprite_rotator against the combinational rotate_x / rotate_y
// functions it pipelines. One request enters per clock: every position
// of an 11x11 sprite (-5..5 on each axis) at each of the 32 rotation
// steps, with every fifth request sent with inValid low. The testbench
// keeps a two-deep delay line of the reference and on every clock
// checks that outValid is inValid from two clocks earlier and, when it
// is high, that outPosition matches the reference.

`timescale 1ns/1ps

`include "trigonometric_functions.vh"

module tb_sprite_rotator;

    localparam integer CLK_PERIOD = 20;
    localparam integer LIMIT      = 5;

    reg               tbClock     = 1'b0;
    reg               tbValid     = 1'b0;
    reg signed [31:0] tbPositionX = 32'sd0;
    reg signed [31:0] tbPositionY = 32'sd0;
    reg        [4:0]  tbRotation  = 5'd0;
    wire              tbOutValid;
    wire signed [31:0] tbOutPositionX;
    wire signed [31:0] tbOutPositionY;

    // Reference, delayed to line up with the DUT's two stages.
    reg signed [31:0] tbRef1X     = 32'sd0;
    reg signed [31:0] tbRef1Y     = 32'sd0;
    reg signed [31:0] tbRef2X     = 32'sd0;
    reg signed [31:0] tbRef2Y     = 32'sd0;
    reg               tbRefValid1 = 1'b0;
    reg               tbRefValid2 = 1'b0;

    integer tbSent    = 0;      // valid requests sent
    integer tbChecked = 0;      // valid results compared

    integer vRot   = 0;
    integer vX     = 0;
    integer vY     = 0;
    integer vCount = 0;

    reg sSimulationActive = 1'b1;

    sprite_rotator dut (
        .inClock      (tbClock),
        .inValid      (tbValid),
        .inPositionX  (tbPositionX),
        .inPositionY  (tbPositionY),
        .inRotation   (tbRotation),
        .outValid     (tbOutValid),
        .outPositionX (tbOutPositionX),
        .outPositionY (tbOutPositionY)
    );

    always #(CLK_PERIOD/2) if (sSimulationActive) tbClock = ~tbClock;

    initial begin
        $dumpfile(`FST_OUT);
        $dumpvars(1, tb_sprite_rotator);
        $dumpvars(1, dut);
    end

    // Just before each edge the DUT outputs belong to the request
    // sampled two edges ago, which is what tbRef2* holds.
    always @(posedge tbClock) begin
        tbRef1X     <= rotate_x(11, 11, tbPositionX, tbPositionY, tbRotation);
        tbRef1Y     <= rotate_y(11, 11, tbPositionX, tbPositionY, tbRotation);
        tbRefValid1 <= tbValid;
        tbRef2X     <= tbRef1X;
        tbRef2Y     <= tbRef1Y;
        tbRefValid2 <= tbRefValid1;

        if (tbOutValid !== tbRefValid2)
            $fatal(1, "outValid is not inValid delayed by two clocks");
        if (tbRefValid2) begin
            if (tbOutPositionX !== tbRef2X || tbOutPositionY !== tbRef2Y)
                $fatal(1, "rotator output (%0d, %0d) differs from rotate (%0d, %0d)",
                       tbOutPositionX, tbOutPositionY, tbRef2X, tbRef2Y);
            tbChecked <= tbChecked + 1;
        end
    end

    // Inputs change on falling edges, clear of the edge the DUT samples.
    initial begin : stim
        @(negedge tbClock);

        for (vRot = 0; vRot < 32; vRot = vRot + 1) begin
            for (vY = -LIMIT; vY <= LIMIT; vY = vY + 1) begin
                for (vX = -LIMIT; vX <= LIMIT; vX = vX + 1) begin
                    tbRotation  = vRot[4:0];
                    tbPositionX = vX;
                    tbPositionY = vY;
                    if (vCount % 5 == 4) begin
                        tbValid = 1'b0;
                    end else begin
                        tbValid = 1'b1;
                        tbSent  = tbSent + 1;
                    end
                    vCount = vCount + 1;
                    @(negedge tbClock);
                end
            end
        end

        // Let the last requests drain through both stages.
        tbValid = 1'b0;
        #(4 * CLK_PERIOD);

        if (tbChecked != tbSent)
            $fatal(1, "checked %0d results for %0d valid requests", tbChecked, tbSent);
        if (!(tbSent > 3000))
            $fatal(1, "sweep sent too few requests");

        $display("sprite_rotator simulation done!");
        sSimulationActive = 1'b0;
        $finish;
    end

endmodule
