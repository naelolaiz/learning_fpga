// top_level_vga_test.v — Verilog mirror of top_level_vga_test.vhd.
//
// Three rotating smileys on a 640x480 VGA screen: the board's 50 MHz
// clock is halved for the pixel clock, VgaController produces the sync
// signals and the scan position, and each sprite answers whether the
// pixel under the cursor belongs to it. The three answers are mixed
// into one 3-bit colour.

`timescale 1ns/1ps

module top_level_vga_test (
    input  wire       clk,      // Pin 23, 50 MHz from the onboard oscillator
    output wire [2:0] rgb,      // Pins 106, 105 and 104
    output wire       hsync,    // Pin 101
    output wire       vsync     // Pin 103
);

    localparam integer SCREEN_WIDTH    = 640;
    localparam integer SCREEN_HEIGHT   = 480;
    localparam integer SCREEN_MARGIN_X = 155;
    localparam integer SCREEN_MARGIN_Y = 30;

    // A sprite answers three clocks after the cursor it is shown: two
    // more than when the rotation was done in a single step. Showing
    // the sprites the cursor two pixels ahead keeps the picture where
    // it was.
    localparam integer SPRITE_LOOKAHEAD = 2;

    // We need 25 MHz for the VGA so we divide the input clock by 2.
    reg vga_clk = 1'b0;
    always @(posedge clk) vga_clk <= ~vga_clk;

    wire [10:0] hpos;
    wire [10:0] vpos;
    wire signed [31:0] cursorX = $signed({21'd0, hpos}) - SCREEN_MARGIN_X + SPRITE_LOOKAHEAD;
    wire signed [31:0] cursorY = $signed({21'd0, vpos}) - SCREEN_MARGIN_Y;

    wire should_draw_square1;
    wire should_draw_square2;
    wire should_draw_square3;

    sprite #(
        .SCREEN_WIDTH                   (SCREEN_WIDTH),
        .SCREEN_HEIGHT                  (SCREEN_HEIGHT),
        .INITIAL_ROTATION               (8),
        .INITIAL_POSITION_X             (200),
        .INITIAL_POSITION_Y             (200),
        .INITIAL_SPEED_X                (1),
        .INITIAL_SPEED_Y                (1),
        .INITIAL_SPEED_UPDATE_PERIOD    (300000),
        .SPRITE_WIDTH                   (11),
        .SCALE                          (4),
        .SPRITE_CONTENT_LEN             (121),
        .SPRITE_CONTENT                 ({11'b00011111000,
                                          11'b00100000100,
                                          11'b01000000010,
                                          11'b10010001001,
                                          11'b10000000001,
                                          11'b10000100001,
                                          11'b10100000101,
                                          11'b10010001001,
                                          11'b01001110010,
                                          11'b00100000100,
                                          11'b00011111000}),
        .INITIAL_ROTATION_INDEX_INC     (1),
        .INITIAL_ROTATION_UPDATE_PERIOD (1000000)
    ) mySprite (
        .inClock       (vga_clk),
        .inEnabled     (1'b1),
        .inCursorX     (cursorX),
        .inCursorY     (cursorY),
        .inColision    (should_draw_square2),
        .outShouldDraw (should_draw_square1)
    );

    sprite #(
        .SCREEN_WIDTH                   (SCREEN_WIDTH),
        .SCREEN_HEIGHT                  (SCREEN_HEIGHT),
        .INITIAL_ROTATION               (4),
        .INITIAL_POSITION_X             (500),
        .INITIAL_POSITION_Y             (300),
        .INITIAL_SPEED_X                (1),
        .INITIAL_SPEED_Y                (-1),
        .INITIAL_SPEED_UPDATE_PERIOD    (600000),
        .SPRITE_WIDTH                   (11),
        .SCALE                          (3),
        .SPRITE_CONTENT_LEN             (121),
        .SPRITE_CONTENT                 ({11'b00011111000,
                                          11'b00100000100,
                                          11'b01000000010,
                                          11'b10010001001,
                                          11'b10000100001,
                                          11'b10000000001,
                                          11'b10011111001,
                                          11'b10100000101,
                                          11'b01000000010,
                                          11'b00100000100,
                                          11'b00011111000}),
        .INITIAL_ROTATION_INDEX_INC     (-1),
        .INITIAL_ROTATION_UPDATE_PERIOD (1200000)
    ) mySprite2 (
        .inClock       (vga_clk),
        .inEnabled     (1'b1),
        .inCursorX     (cursorX),
        .inCursorY     (cursorY),
        .inColision    (should_draw_square1),
        .outShouldDraw (should_draw_square2)
    );

    sprite #(
        .SCREEN_WIDTH                   (SCREEN_WIDTH),
        .SCREEN_HEIGHT                  (SCREEN_HEIGHT),
        .INITIAL_ROTATION               (0),
        .INITIAL_POSITION_X             (320),
        .INITIAL_POSITION_Y             (240),
        .INITIAL_SPEED_X                (0),
        .INITIAL_SPEED_Y                (0),
        .INITIAL_SPEED_UPDATE_PERIOD    (10000),
        .SPRITE_WIDTH                   (11),
        .SCALE                          (25),
        .SPRITE_CONTENT_LEN             (121),
        .SPRITE_CONTENT                 ({11'b00011111000,
                                          11'b00100000100,
                                          11'b01000000010,
                                          11'b10010001001,
                                          11'b10000000001,
                                          11'b10000100001,
                                          11'b10100000101,
                                          11'b10010001001,
                                          11'b01001110010,
                                          11'b00100000100,
                                          11'b00011111000}),
        .INITIAL_ROTATION_INDEX_INC     (-1),
        .INITIAL_ROTATION_UPDATE_PERIOD (15000000)
    ) mySprite3 (
        .inClock       (vga_clk),
        .inEnabled     (1'b1),
        .inCursorX     (cursorX),
        .inCursorY     (cursorY),
        .inColision    (should_draw_square2),
        .outShouldDraw (should_draw_square3)
    );

    // Mix the three sprites into one colour: sprite 1 green, sprite 2
    // adds blue, sprite 3 inverts whatever is underneath.
    reg [2:0] tempColorSum = 3'b000;
    reg [2:0] rgb_input    = 3'b000;
    always @(posedge vga_clk) begin
        tempColorSum = 3'b000;
        if (should_draw_square1)
            tempColorSum = 3'b010;
        if (should_draw_square2)
            tempColorSum = tempColorSum | 3'b001;
        if (should_draw_square3)
            tempColorSum = ~tempColorSum;
        rgb_input <= tempColorSum;
    end

    VgaController controller (
        .clk     (vga_clk),
        .rgb_in  (rgb_input),
        .rgb_out (rgb),
        .hsync   (hsync),
        .vsync   (vsync),
        .hpos    (hpos),
        .vpos    (vpos)
    );

endmodule
