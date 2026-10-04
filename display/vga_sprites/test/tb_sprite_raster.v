// tb_sprite_raster.v — Verilog mirror of tb_sprite_raster.vhd.
//
// Scans a whole small screen past a rotated, stationary sprite and
// compares every pixel with a reference computed in one step (bounding
// box, scale, centre, the combinational rotate_x / rotate_y, content
// lookup), delayed by the sprite's three clocks of latency. Pins down
// both the picture and the latency.
//
// The sprite is an "F": no rotation or mirroring maps it onto itself,
// so an image drawn upside down or mirrored fails too.

`timescale 1ns/1ps

`include "trigonometric_functions.vh"

module tb_sprite_raster;

    localparam integer CLK_PERIOD = 20;

    localparam integer SCREEN_W = 48;
    localparam integer SCREEN_H = 36;
    localparam integer CENTER_X = 24;
    localparam integer CENTER_Y = 18;
    localparam integer WIDTH    = 5;
    localparam integer HEIGHT   = 5;
    localparam integer SCALE    = 3;
    localparam integer ROTATION = 3;        // 3/32 of a turn
    localparam integer LATENCY  = 3;

    localparam integer HALF_W = WIDTH  * SCALE / 2;
    localparam integer HALF_H = HEIGHT * SCALE / 2;

    // Row by row, top row first; within a row the leftmost pixel is
    // the leftmost digit.
    function automatic content_at(input integer x, input integer y);
        reg [WIDTH-1:0] row;
        begin
            case (y)
                0:       row = 5'b11111;
                1:       row = 5'b10000;
                2:       row = 5'b11100;
                3:       row = 5'b10000;
                default: row = 5'b10000;
            endcase
            content_at = row[WIDTH - 1 - x];
        end
    endfunction

    // What the sprite should answer for a cursor position.
    function automatic expected_draw(input integer cx, input integer cy);
        integer px, py, rx, ry;
        begin
            if (cx < CENTER_X - HALF_W || cx > CENTER_X + HALF_W ||
                cy < CENTER_Y - HALF_H || cy > CENTER_Y + HALF_H) begin
                expected_draw = 1'b0;
            end else begin
                px = (cx - (CENTER_X - HALF_W)) / SCALE;
                py = (cy - (CENTER_Y - HALF_H)) / SCALE;
                px = translateOriginToCenterOfSprite_x(WIDTH,  px);
                py = translateOriginToCenterOfSprite_y(HEIGHT, py);
                rx = rotate_x(WIDTH, HEIGHT, px, py, ROTATION[4:0]);
                ry = rotate_y(WIDTH, HEIGHT, px, py, ROTATION[4:0]);
                rx = translateOriginBackToFirstBitCorner_x(WIDTH,  rx);
                ry = translateOriginBackToFirstBitCorner_y(HEIGHT, ry);
                if (rx < 0 || rx > WIDTH - 1 || ry < 0 || ry > HEIGHT - 1)
                    expected_draw = 1'b0;
                else
                    expected_draw = content_at(rx, ry);
            end
        end
    endfunction

    reg               tbClock    = 1'b0;
    reg signed [31:0] tbCursorX  = 32'sd0;
    reg signed [31:0] tbCursorY  = 32'sd0;
    reg               tbScanning = 1'b0;
    wire              tbShouldDraw;

    // Reference answers and "this slot holds a scanned pixel" flags,
    // delayed to line up with the sprite's output. Bit 0 is the newest.
    reg [LATENCY-1:0] tbExpected = {LATENCY{1'b0}};
    reg [LATENCY-1:0] tbArmed    = {LATENCY{1'b0}};

    integer tbChecked = 0;      // pixels compared
    integer tbDrawn   = 0;      // of those, pixels drawn

    integer vX = 0;
    integer vY = 0;

    reg sSimulationActive = 1'b1;

    sprite #(
        .SCREEN_WIDTH                   (SCREEN_W),
        .SCREEN_HEIGHT                  (SCREEN_H),
        .SPRITE_WIDTH                   (WIDTH),
        .SCALE                          (SCALE),
        .SPRITE_CONTENT_LEN             (WIDTH * HEIGHT),
        .SPRITE_CONTENT                 (25'b11111_10000_11100_10000_10000),
        .INITIAL_ROTATION               (ROTATION),
        .INITIAL_ROTATION_INDEX_INC     (0),        // hold the rotation
        .INITIAL_ROTATION_UPDATE_PERIOD (0),
        .INITIAL_POSITION_X             (CENTER_X),
        .INITIAL_POSITION_Y             (CENTER_Y),
        .INITIAL_SPEED_X                (0),        // stand still
        .INITIAL_SPEED_Y                (0),
        .INITIAL_SPEED_UPDATE_PERIOD    (1000)
    ) dut (
        .inClock       (tbClock),
        .inEnabled     (1'b1),
        .inCursorX     (tbCursorX),
        .inCursorY     (tbCursorY),
        .inColision    (1'b0),
        .outShouldDraw (tbShouldDraw)
    );

    always #(CLK_PERIOD/2) if (sSimulationActive) tbClock = ~tbClock;

    // sprite.v keeps the VHDL process variables as module-scope regs,
    // some without a reset value; list the signals worth dumping so the
    // waveform matches the VHDL twin.
    initial begin
        $dumpfile(`FST_OUT);
        $dumpvars(1, tb_sprite_raster);
        $dumpvars(0, dut.inClock, dut.outShouldDraw,
                     dut.sRotation, dut.sCursorInBox,
                     dut.sCursorLocalX, dut.sCursorLocalY,
                     dut.sRotatedValid, dut.sRotatedPosX, dut.sRotatedPosY,
                     dut.sShouldDraw);
    end

    // Just before each edge, outShouldDraw belongs to the cursor sampled
    // LATENCY edges ago, which is what the oldest delay slot holds.
    always @(posedge tbClock) begin
        tbExpected <= {tbExpected[LATENCY-2:0], expected_draw(tbCursorX, tbCursorY)};
        tbArmed    <= {tbArmed[LATENCY-2:0],    tbScanning};

        if (tbArmed[LATENCY-1]) begin
            if (tbShouldDraw !== tbExpected[LATENCY-1])
                $fatal(1, "pixel mismatch %0d pixels into the scan: sprite says %b, reference says %b",
                       tbChecked, tbShouldDraw, tbExpected[LATENCY-1]);
            tbChecked <= tbChecked + 1;
            if (tbShouldDraw)
                tbDrawn <= tbDrawn + 1;
        end
    end

    // The cursor moves on falling edges, clear of the edge the sprite
    // samples on, one pixel per clock in raster order.
    initial begin : stim
        // Let the sprite latch its position before scanning.
        #(4 * CLK_PERIOD);
        @(negedge tbClock);

        for (vY = 0; vY < SCREEN_H; vY = vY + 1) begin
            for (vX = 0; vX < SCREEN_W; vX = vX + 1) begin
                tbCursorX  = vX;
                tbCursorY  = vY;
                tbScanning = 1'b1;
                @(negedge tbClock);
            end
        end
        tbScanning = 1'b0;

        // Drain the pipeline.
        #((LATENCY + 2) * CLK_PERIOD);

        if (tbChecked != SCREEN_W * SCREEN_H)
            $fatal(1, "compared %0d pixels, expected %0d", tbChecked, SCREEN_W * SCREEN_H);
        // The F has 11 pixels at SCALE 3, so about 99 screen pixels; a
        // blank or solid image would also "match" a broken reference.
        if (!(tbDrawn > 40 && tbDrawn < 140))
            $fatal(1, "implausible number of drawn pixels: %0d", tbDrawn);

        $display("sprite raster simulation done!");
        sSimulationActive = 1'b0;
        $finish;
    end

endmodule
