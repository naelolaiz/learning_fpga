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

    // Unpack SPRITE_CONTENT into a 2D-indexable rom. Row `r`, column `c`
    // of the VHDL sSpriteContent maps to SPRITE_CONTENT[r*SPRITE_WIDTH + c].
    // Kept as a packed array of rows so the read in ProcessPosition is
    // a plain index, not a full vector slice.
    reg [SPRITE_WIDTH-1:0] sSpriteContent [0:SPRITE_HEIGHT-1];
    integer initI, initJ;
    initial begin
        for (initI = 0; initI < SPRITE_HEIGHT; initI = initI + 1) begin
            for (initJ = 0; initJ < SPRITE_WIDTH; initJ = initJ + 1) begin
                sSpriteContent[initI][initJ] =
                    SPRITE_CONTENT[initI * SPRITE_WIDTH + initJ];
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
    reg [4:0]  indexForSpriteRotation         = 0;
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

    // --- ProcessPosition process ------------------------------------------
    // Cursor miss / hit check + rotation-aware lookup into sSpriteContent.
    reg signed [31:0] vCursorX;
    reg signed [31:0] vCursorY;
    reg signed [31:0] vTransX;
    reg signed [31:0] vTransY;
    always @(posedge inClock) begin
        if (!inEnabled) begin
            sShouldDraw <= 1'b0;
        end else begin
            sCenterPosX <= sSpritePosX;
            sCenterPosY <= sSpritePosY;

            vCursorX = inCursorX;
            vCursorY = inCursorY;

            if ((vCursorX < (sCenterPosX - C_HALF_SCALED_WIDTH))  ||
                (vCursorX > (sCenterPosX + C_HALF_SCALED_WIDTH))  ||
                (vCursorY < (sCenterPosY - C_HALF_SCALED_HEIGHT)) ||
                (vCursorY > (sCenterPosY + C_HALF_SCALED_HEIGHT))) begin
                sShouldDraw <= 1'b0;
            end else begin
                vTransX = (vCursorX - (sCenterPosX - C_HALF_SCALED_WIDTH))  / SCALE;
                vTransY = (vCursorY - (sCenterPosY - C_HALF_SCALED_HEIGHT)) / SCALE;
                vTransX = translateOriginToCenterOfSprite_x(SPRITE_WIDTH,  vTransX);
                vTransY = translateOriginToCenterOfSprite_y(SPRITE_HEIGHT, vTransY);
                // rotate() takes the two axes together; in Verilog we
                // materialise one axis at a time through the two helper
                // functions. Each uses the ORIGINAL vTransX/vTransY —
                // same as the VHDL, which reads position.x/position.y
                // of the pre-rotation variable.
                begin : rotate_block
                    reg signed [31:0] preX, preY;
                    preX = vTransX;
                    preY = vTransY;
                    vTransX = rotate_x(SPRITE_WIDTH, SPRITE_HEIGHT, preX, preY, sRotation);
                    vTransY = rotate_y(SPRITE_WIDTH, SPRITE_HEIGHT, preX, preY, sRotation);
                end
                vTransX = translateOriginBackToFirstBitCorner_x(SPRITE_WIDTH,  vTransX);
                vTransY = translateOriginBackToFirstBitCorner_y(SPRITE_HEIGHT, vTransY);

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
