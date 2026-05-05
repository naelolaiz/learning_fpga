`timescale 1ns / 1ps

// Verilog mirror of test/tb_vga_smoke.vhd — same two contracts:
//   * the strict-less-than box test ("Square" procedure in VgaUtils)
//   * the Font_Rom synchronous read at NUL and at 'A' row 7
// kept 1:1 so a VHDL-vs-Verilog regression on either contract surfaces
// in this run too. Verilog has no procedure/concurrent equivalent of
// the VHDL Square procedure, so the inequality is `assign`ed inline.

module tb_vga_smoke;
    localparam CLK_HALF = 10;       // 50 MHz, matches the vga_clk on the board
    localparam SQ_SIZE  = 10;

    reg              tbClock = 0;
    reg              sSimulationActive = 1;
    integer          tbStage = 0;

    reg  signed [31:0] sqHCur = 0, sqVCur = 0;
    reg  signed [31:0] sqHPos = 0, sqVPos = 0;
    wire             sqShouldDraw;

    reg  [10:0]      romAddr = 11'd0;
    wire [7:0]       romRow;

    // Mirrors VgaUtils.Square — strict-less-than on both axes.
    assign sqShouldDraw = (sqHCur >  sqHPos)
                       && (sqHCur <  sqHPos + SQ_SIZE)
                       && (sqVCur >  sqVPos)
                       && (sqVCur <  sqVPos + SQ_SIZE);

    font_rom dut_rom (
        .clk     (tbClock),
        .addr    (romAddr),
        .fontRow (romRow)
    );

    always begin
        if (!sSimulationActive) begin
            tbClock = 1'b0;
            #(2 * CLK_HALF);
        end else begin
            #CLK_HALF tbClock = ~tbClock;
        end
    end

    // Synchronous-read helper: drive the address, wait one rising
    // edge, sample. Identical contract to tb_vga_smoke.vhd's read_rom.
    task read_rom(input [10:0] address);
    begin
        romAddr = address;
        @(posedge tbClock);
        #1;
    end
    endtask

    initial begin
        $dumpfile(`FST_OUT);
        // Explicit signal list instead of $dumpvars(0, tb_vga_smoke) so the
        // dump excludes (a) dut_rom.rom[0:2047], whose 2048-element initial
        // block goes through 2048 delta cycles at t=0 and shows X during
        // them, and (b) the read_rom task's `address` argument, which is X
        // whenever the task is not actively executing. Both would render as
        // red bars at the start of the waveform even though they don't
        // affect the assertions. The VHDL flow has neither problem because
        // GHDL applies signal defaults at elaboration and doesn't trace
        // VHDL procedure-local variables in the FST.
        $dumpvars(0, tbClock, sSimulationActive, tbStage,
                     sqHCur, sqVCur, sqHPos, sqVPos, sqShouldDraw,
                     romAddr, romRow);

        // ---------- Stage 1: Square boundary semantics ----------
        tbStage = 1;
        sqHPos  = 100;
        sqVPos  = 50;

        sqHCur = 105; sqVCur = 55;  #1;
        if (sqShouldDraw !== 1'b1) begin
            $display("FAIL stage 1a: cursor strictly inside the box should draw");
            $fatal;
        end

        sqHCur = 100; sqVCur = 55;  #1;     // left edge — strict, no draw
        if (sqShouldDraw !== 1'b0) begin
            $display("FAIL stage 1b: cursor on left edge must not draw (strict <)");
            $fatal;
        end

        sqHCur = 110; sqVCur = 55;  #1;     // right edge (hpos+size)
        if (sqShouldDraw !== 1'b0) begin
            $display("FAIL stage 1c: cursor on right edge must not draw (strict <)");
            $fatal;
        end

        sqHCur = 200; sqVCur = 200; #1;     // far outside
        if (sqShouldDraw !== 1'b0) begin
            $display("FAIL stage 1d: cursor far outside should not draw");
            $fatal;
        end

        // ---------- Stage 2: NUL glyph rows are all zero ----------
        tbStage = 2;
        begin : nul_sweep
            integer r;
            for (r = 0; r < 16; r = r + 1) begin
                read_rom(r[10:0]);
                if (romRow !== 8'b00000000) begin
                    $display("FAIL stage 2: NUL row %0d expected 0, got %b", r, romRow);
                    $fatal;
                end
            end
        end

        // ---------- Stage 3: 'A' (0x41) row 7 = 11111110 ----------
        tbStage = 3;
        read_rom(11'(8'h41) * 16 + 7);
        if (romRow !== 8'b11111110) begin
            $display("FAIL stage 3: 'A' row 7 expected 11111110, got %b", romRow);
            $fatal;
        end

        // ---------- Stage 4: waveform sweep ----------
        tbStage = 4;
        sqHPos = 20;
        sqVPos = 20;
        sqVCur = 25;
        begin : sweep
            integer x;
            for (x = 10; x <= 40; x = x + 1) begin
                sqHCur = x;
                #(4 * CLK_HALF);
            end
        end

        tbStage = 99;
        #(4 * CLK_HALF);
        sSimulationActive = 0;
        $finish;
    end
endmodule
