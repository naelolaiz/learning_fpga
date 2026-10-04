// tb_vga_sprites_top.v — Verilog mirror of tb_vga_sprites_top.vhd.
//
// Runs the real board top, top_level_vga_test, and checks where a
// sprite lands on the screen using only rgb, hsync and vsync.
//
// The big smiley (sprite 3) sits still at the screen centre with no
// rotation, 25 screen pixels per sprite pixel. On a scan line through
// its top row ("00011111000") the picture is one white run of 125
// pixels and black everywhere else:
//
//   left edge of the sprite's box   320 - 137          = cursor x 183
//   three blank sprite pixels       183 + 3 * 25       = cursor x 258
//   cursor 0 is at hcount 155, and the sprite's answer reaches the
//   rgb pins two pixels after the cursor it belongs to   +157
//
// so the run covers hcount 415 .. 539. A change in the sprite's
// latency that is not matched by the look-ahead in the top moves the
// run and fails this test.

`timescale 1ns/1ps

module tb_vga_sprites_top;

    localparam integer CLK_PERIOD   = 20;               // 50 MHz board clock
    localparam integer PIXEL_PERIOD = 2 * CLK_PERIOD;   // 25 MHz pixel clock
    localparam integer LINE_PIXELS  = 800;

    // vcount 140 = cursor y 110, inside the sprite's top row
    // (cursor y 103 .. 127).
    localparam integer TEST_LINE   = 140;
    localparam integer FIRST_WHITE = 415;
    localparam integer LAST_WHITE  = 539;

    reg        tbClock = 1'b0;
    wire [2:0] tbRgb;
    wire       tbHsync;
    wire       tbVsync;

    integer tbLine       = 0;       // lines since power-up (= vcount)
    integer tbPixel      = 0;       // hcount on the line under test
    reg     tbChecking   = 1'b0;
    integer tbWhiteCount = 0;
    time    tbLineStart  = 0;

    reg sSimulationActive = 1'b1;

    top_level_vga_test dut (
        .clk   (tbClock),
        .rgb   (tbRgb),
        .hsync (tbHsync),
        .vsync (tbVsync)
    );

    always #(CLK_PERIOD/2) if (sSimulationActive) tbClock = ~tbClock;

    // Only the pins and the testbench's own bookkeeping: the three
    // sprites underneath would make the dump enormous.
    initial begin
        $dumpfile(`FST_OUT);
        $dumpvars(1, tb_vga_sprites_top);
    end

    initial begin : monitor
        // hsync falls when hcount wraps to 0, which is also when vcount
        // advances: n falling edges after power-up, vcount is n. Step
        // past time 0 first, where hsync settling from x to 0 would
        // count as a falling edge.
        #1;
        while (tbLine < TEST_LINE) begin
            @(negedge tbHsync);
            if (tbLine != 0 && $time - tbLineStart != LINE_PIXELS * PIXEL_PERIOD)
                $fatal(1, "scan line is not %0d pixels long", LINE_PIXELS);
            tbLineStart = $time;
            tbLine      = tbLine + 1;
        end

        if (tbVsync !== 1'b1)
            $fatal(1, "vsync should be inactive (high) on a visible line");

        // Sample every pixel of the line in the middle of its period.
        tbChecking = 1'b1;
        #(PIXEL_PERIOD / 2);
        for (tbPixel = 0; tbPixel < LINE_PIXELS; tbPixel = tbPixel + 1) begin
            if (tbPixel >= FIRST_WHITE && tbPixel <= LAST_WHITE) begin
                if (tbRgb !== 3'b111)
                    $fatal(1, "hcount %0d: expected the sprite (white), got %b", tbPixel, tbRgb);
                tbWhiteCount = tbWhiteCount + 1;
            end else if (tbRgb !== 3'b000) begin
                $fatal(1, "hcount %0d: expected black outside the sprite, got %b", tbPixel, tbRgb);
            end
            #(PIXEL_PERIOD);
        end
        tbChecking = 1'b0;

        if (tbWhiteCount != 5 * 25)
            $fatal(1, "the sprite's top row should be 125 pixels wide");

        $display("vga_sprites top simulation done!");
        sSimulationActive = 1'b0;
        $finish;
    end

endmodule
