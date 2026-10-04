// sprite.v — Verilog mirror of sprite.vhd.
//
// VHDL uses record-typed generics (Pos2D, Speed2D, RotationSpeed,
// GravityAcceleration, Size2D). Verilog has no records, so each record
// field is exposed as its own integer parameter with a ``_X`` / ``_Y`` /
// ``_PERIOD`` suffix. Instantiators pass them individually.

`timescale 1ns/1ps

`include "trigonometric_functions.vh"

module sprite #(
    parameter integer SCREEN_WIDTH                   = 800,
    parameter integer SCREEN_HEIGHT                  = 600,
    parameter integer SPRITE_WIDTH                   = 7,
    parameter integer SCALE                          = 3,
    parameter integer SPRITE_CONTENT_LEN             = 49,
    parameter [SPRITE_CONTENT_LEN-1:0] SPRITE_CONTENT =
        49'b1001001_0101010_0011100_1111111_0011100_0101010_1001001,
    parameter integer INITIAL_ROTATION               = 0,
    parameter integer INITIAL_ROTATION_INDEX_INC     = 1,
    parameter integer INITIAL_ROTATION_UPDATE_PERIOD = 0,
    parameter integer INITIAL_POSITION_X             = 0,
    parameter integer INITIAL_POSITION_Y             = 0,
    parameter integer INITIAL_SPEED_X                = 0,
    parameter integer INITIAL_SPEED_Y                = 0,
    parameter integer INITIAL_SPEED_UPDATE_PERIOD    = 0,
    parameter integer GRAVITY_ENABLED                = 0,
    parameter integer GRAVITY_Y_INCREMENTS           = 1,
    parameter integer GRAVITY_UPDATE_PERIOD          = 3000000
) (
    input  wire       inClock,
    input  wire       inEnabled,
    input  wire signed [31:0] inCursorX,
    input  wire signed [31:0] inCursorY,
    input  wire       inColision,
    output wire       outShouldDraw
);

    // Sprite-size / half-scaled constants (VHDL SPRITE_SIZE record).
    localparam integer SPRITE_HEIGHT          = SPRITE_CONTENT_LEN / SPRITE_WIDTH;
    localparam integer C_HALF_SCALED_WIDTH    = SPRITE_WIDTH  * SCALE / 2;
    localparam integer C_HALF_SCALED_HEIGHT   = SPRITE_HEIGHT * SCALE / 2;

    // Unpack SPRITE_CONTENT into a 2D-indexable rom. The VHDL generic
    // is a string literal whose index 0 is its FIRST character, so row
    // `r`, column `c` of sSpriteContent is character r*SPRITE_WIDTH + c
    // counted from the left. A Verilog literal numbers its bits from
    // the right, hence the mirrored index: the literal reads the same
    // in both languages, top row first, leftmost pixel first.
    // Kept as a packed array of rows so the read in ProcessPosition is
    // a plain index, not a full vector slice.
    reg [SPRITE_WIDTH-1:0] sSpriteContent [0:SPRITE_HEIGHT-1];
    integer initI, initJ;
    initial begin
        for (initI = 0; initI < SPRITE_HEIGHT; initI = initI + 1) begin
            for (initJ = 0; initJ < SPRITE_WIDTH; initJ = initJ + 1) begin
                sSpriteContent[initI][initJ] =
                    SPRITE_CONTENT[SPRITE_CONTENT_LEN - 1
                                   - (initI * SPRITE_WIDTH + initJ)];
            end
        end
    end

    reg signed [31:0] sSpritePosX = INITIAL_POSITION_X;
    reg signed [31:0] sSpritePosY = INITIAL_POSITION_Y;
    reg signed [31:0] sCenterPosX = 0;
    reg signed [31:0] sCenterPosY = 0;

    reg signed [31:0] sCurrentSpeedX             = INITIAL_SPEED_X;
    reg signed [31:0] sCurrentSpeedY             = INITIAL_SPEED_Y;
    reg signed [31:0] sCurrentRotationIndexInc   = INITIAL_ROTATION_INDEX_INC;

    reg [4:0] sRotation = INITIAL_ROTATION[4:0];
    reg       sShouldDraw = 1'b0;
    assign outShouldDraw = sShouldDraw;

    // --- rotateSprite process ---------------------------------------------
    reg [31:0] counterForSpriteRotationUpdate = 0;
    reg [4:0]  indexForSpriteRotation         = INITIAL_ROTATION[4:0];
    always @(posedge inClock) begin
        if (counterForSpriteRotationUpdate == INITIAL_ROTATION_UPDATE_PERIOD) begin
            counterForSpriteRotationUpdate <= 0;
            if ($signed(sCurrentRotationIndexInc) > 0) begin
                if (indexForSpriteRotation == 5'd31)
                    indexForSpriteRotation <= 5'd0;
                else
                    indexForSpriteRotation <= indexForSpriteRotation + sCurrentRotationIndexInc[4:0];
            end else if ($signed(sCurrentRotationIndexInc) < 0) begin
                if (indexForSpriteRotation == 5'd0)
                    indexForSpriteRotation <= 5'd31;
                else
                    indexForSpriteRotation <= indexForSpriteRotation + sCurrentRotationIndexInc[4:0];
            end
        end else begin
            counterForSpriteRotationUpdate <= counterForSpriteRotationUpdate + 1;
        end
        sRotation <= indexForSpriteRotation;
    end

    // --- moveSprite process -----------------------------------------------
    reg [31:0] counterForSpritePositionUpdate     = 0;
    reg [31:0] counterForVelocityUpdateByGravity  = 0;
    reg signed [31:0] nextPositionToTestX;
    reg signed [31:0] nextPositionToTestY;
    reg signed [31:0] workingSpeedX;
    reg signed [31:0] workingSpeedY;
    reg               collisionDetected;
    always @(posedge inClock) begin
        workingSpeedX = sCurrentSpeedX;
        workingSpeedY = sCurrentSpeedY;

        if (GRAVITY_ENABLED != 0) begin
            if (counterForVelocityUpdateByGravity == GRAVITY_UPDATE_PERIOD) begin
                counterForVelocityUpdateByGravity <= 0;
                workingSpeedY = workingSpeedY + GRAVITY_Y_INCREMENTS;
            end else begin
                counterForVelocityUpdateByGravity <= counterForVelocityUpdateByGravity + 1;
            end
        end

        if (counterForSpritePositionUpdate == INITIAL_SPEED_UPDATE_PERIOD) begin
            counterForSpritePositionUpdate <= 0;
            collisionDetected = 1'b0;
            nextPositionToTestX = sSpritePosX + workingSpeedX;
            nextPositionToTestY = sSpritePosY + workingSpeedY;
            if ((nextPositionToTestX - C_HALF_SCALED_WIDTH  <= 0) ||
                (nextPositionToTestX + C_HALF_SCALED_WIDTH  >= SCREEN_WIDTH)) begin
                workingSpeedX    = -workingSpeedX;
                collisionDetected = 1'b1;
            end
            if ((nextPositionToTestY - C_HALF_SCALED_HEIGHT <= 0) ||
                (nextPositionToTestY + C_HALF_SCALED_HEIGHT >= SCREEN_HEIGHT)) begin
                workingSpeedY    = -workingSpeedY;
                if ((GRAVITY_ENABLED != 0) && (workingSpeedY > 1))
                    workingSpeedY = 32'sd1;
                collisionDetected = 1'b1;
            end
            sSpritePosX <= sSpritePosX + workingSpeedX;
            sSpritePosY <= sSpritePosY + workingSpeedY;
            if (collisionDetected || (inColision && sShouldDraw))
                sCurrentRotationIndexInc <= -sCurrentRotationIndexInc;
            if (inColision && sShouldDraw) begin
                workingSpeedX = -workingSpeedX;
                workingSpeedY = -workingSpeedY;
            end
        end else begin
            counterForSpritePositionUpdate <= counterForSpritePositionUpdate + 1;
        end

        sCurrentSpeedX <= workingSpeedX;
        sCurrentSpeedY <= workingSpeedY;
    end

    // --- Should the pixel under the cursor be drawn? ----------------------
    // Answered over three clock edges, so outShouldDraw lags the cursor
    // by three clocks:
    //
    //   edge 1   CursorToSprite (combinational) feeds sprite_rotator,
    //            which registers the four LUT products
    //   edge 2   sprite_rotator registers the rotated position
    //   edge 3   ProcessPosition looks the rotated position up in the
    //            sprite content and registers sShouldDraw
    //
    // Every sprite has the same lag, so sprites stay aligned with each
    // other; whoever drives the cursor compensates for it once.

    // --- CursorToSprite process -------------------------------------------
    // Is the cursor inside the sprite's (unrotated, scaled) bounding
    // box, and where is it in sprite pixels with the origin at the
    // sprite's centre?
    // always_comb (not always @*) so the outputs are computed at time 0,
    // before any input has changed.
    reg               sCursorInBox;
    reg signed [31:0] sCursorLocalX;
    reg signed [31:0] sCursorLocalY;
    always_comb begin
        if ((inCursorX < (sCenterPosX - C_HALF_SCALED_WIDTH))  ||
            (inCursorX > (sCenterPosX + C_HALF_SCALED_WIDTH))  ||
            (inCursorY < (sCenterPosY - C_HALF_SCALED_HEIGHT)) ||
            (inCursorY > (sCenterPosY + C_HALF_SCALED_HEIGHT))) begin
            sCursorInBox  = 1'b0;
            sCursorLocalX = 32'sd0;
            sCursorLocalY = 32'sd0;
        end else begin
            sCursorInBox  = inEnabled;
            sCursorLocalX = translateOriginToCenterOfSprite_x(SPRITE_WIDTH,
                                (inCursorX - (sCenterPosX - C_HALF_SCALED_WIDTH))  / SCALE);
            sCursorLocalY = translateOriginToCenterOfSprite_y(SPRITE_HEIGHT,
                                (inCursorY - (sCenterPosY - C_HALF_SCALED_HEIGHT)) / SCALE);
        end
    end

    wire               sRotatedValid;
    wire signed [31:0] sRotatedPosX;
    wire signed [31:0] sRotatedPosY;

    sprite_rotator rotator (
        .inClock      (inClock),
        .inValid      (sCursorInBox),
        .inPositionX  (sCursorLocalX),
        .inPositionY  (sCursorLocalY),
        .inRotation   (sRotation),
        .outValid     (sRotatedValid),
        .outPositionX (sRotatedPosX),
        .outPositionY (sRotatedPosY)
    );

    // --- ProcessPosition process ------------------------------------------
    // Rotation-aware lookup into sSpriteContent.
    reg signed [31:0] vTransX;
    reg signed [31:0] vTransY;
    always @(posedge inClock) begin
        if (!inEnabled) begin
            sShouldDraw <= 1'b0;
        end else begin
            sCenterPosX <= sSpritePosX;
            sCenterPosY <= sSpritePosY;

            if (!sRotatedValid) begin
                sShouldDraw <= 1'b0;
            end else begin
                vTransX = translateOriginBackToFirstBitCorner_x(SPRITE_WIDTH,  sRotatedPosX);
                vTransY = translateOriginBackToFirstBitCorner_y(SPRITE_HEIGHT, sRotatedPosY);

                if ((vTransX < 0) || (vTransX > SPRITE_WIDTH  - 1) ||
                    (vTransY < 0) || (vTransY > SPRITE_HEIGHT - 1)) begin
                    sShouldDraw <= 1'b0;
                end else begin
                    sShouldDraw <= sSpriteContent[vTransY[31:0]][vTransX[31:0]];
                end
            end
        end
    end

endmodule
