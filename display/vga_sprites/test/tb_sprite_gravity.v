// tb_sprite_gravity.v — Verilog mirror of tb_sprite_gravity.vhd.
//
// Exercises the `sprite` module with GRAVITY_ENABLED=1 via the same
// cause-and-effect pattern as the VHDL TB:
//   Stage 1: cursor at the sprite's initial center -> outShouldDraw = 1.
//   Stage 2: after 300 us of gravity accumulation, cursor back at the
//            original center -> outShouldDraw = 0 (sprite has fallen
//            out of that pixel).
//
// Record-typed VHDL generics are flattened into individual ``_X`` / ``_Y``
// parameters (no records in Verilog).

`timescale 1ns/1ps

module tb_sprite_gravity;

    localparam integer CLK_PERIOD  = 20;
    localparam integer SCREEN_W    = 60;
    localparam integer SCREEN_H    = 40;
    localparam integer INIT_CENT_X = 30;
    localparam integer INIT_CENT_Y = 8;

    reg               tbClock            = 1'b0;
    reg  signed [31:0] tbCursorX         = 32'd0;
    reg  signed [31:0] tbCursorY         = 32'd0;
    wire              tbShouldDraw;
    reg               sSimulationActive  = 1'b1;
    reg  [7:0]        tbStage            = 8'd0;

    sprite #(
        .SCREEN_WIDTH                  (SCREEN_W),
        .SCREEN_HEIGHT                 (SCREEN_H),
        .SPRITE_WIDTH                  (3),
        .SCALE                         (1),
        .SPRITE_CONTENT_LEN            (9),
        .SPRITE_CONTENT                (9'b010_111_010),
        .INITIAL_ROTATION              (0),
        .INITIAL_ROTATION_INDEX_INC    (0),
        .INITIAL_ROTATION_UPDATE_PERIOD(0),
        .INITIAL_POSITION_X            (INIT_CENT_X),
        .INITIAL_POSITION_Y            (INIT_CENT_Y),
        .INITIAL_SPEED_X               (0),
        .INITIAL_SPEED_Y               (0),
        .INITIAL_SPEED_UPDATE_PERIOD   (20),
        .GRAVITY_ENABLED               (1),
        .GRAVITY_Y_INCREMENTS          (1),
        .GRAVITY_UPDATE_PERIOD         (10)
    ) dut (
        .inClock       (tbClock),
        .inEnabled     (1'b1),
        .inCursorX     (tbCursorX),
        .inCursorY     (tbCursorY),
        .inColision    (1'b0),
        .outShouldDraw (tbShouldDraw)
    );

    always #(CLK_PERIOD/2) if (sSimulationActive) tbClock = ~tbClock;

    // VHDL's sprite process variables (counters, nextPositionToTest,
    // currentSpeed, collisionDetected, indexForSpriteRotation, etc.) do
    // not appear in GHDL's VCD. sprite.v keeps them as module-scope regs
    // for yosys compatibility — list the signals we actually want dumped
    // here so the waveform matches the VHDL twin.
    initial begin
        $dumpfile(`VCD_OUT);
        $dumpvars(1, tb_sprite_gravity);
        $dumpvars(0, dut.inClock, dut.inEnabled, dut.inColision,
                     dut.outShouldDraw,
                     dut.sSpritePosX, dut.sSpritePosY,
                     dut.sRotation, dut.sShouldDraw);
    end

    initial begin : driver
        // Stage 1 — cursor on initial center; outShouldDraw should rise.
        tbStage   <= 8'd1;
        tbCursorX <= INIT_CENT_X;
        tbCursorY <= INIT_CENT_Y;
        #(10 * CLK_PERIOD);
        if (tbShouldDraw !== 1'b1)
            $fatal(1, "gravity TB stage 1: cursor at sprite center should draw, but outShouldDraw is 0");

        // Stage 2 — let gravity pull the sprite clear of the initial pixel.
        tbStage <= 8'd2;
        #(300_000);                     // 300 us

        tbCursorX <= INIT_CENT_X;       // re-sample original center
        tbCursorY <= INIT_CENT_Y;
        #(4 * CLK_PERIOD);
        if (tbShouldDraw !== 1'b0)
            $fatal(1, "gravity TB stage 2: sprite has not moved off the original center after 300 us -- gravity path regressed?");

        tbStage <= 8'd99;
        #(2 * CLK_PERIOD);
        sSimulationActive <= 1'b0;
        $finish;
    end

endmodule
