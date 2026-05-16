// Verilog mirror of tl_simulator_writer.vhd.
//
// Drives 5 outLines (one per row) so the *clock* itself appears on the
// pin only when the matching row of a 5x5 character bitmap is lit. With
// the right column timing the result, captured in a logic analyser as
// a single trace per pin, draws "HE110W" — the original author's hello.
//
// Note: Verilog has no equivalent of VHDL's `string` generic. The
// character sequence is hard-coded the same way the VHDL does it: a
// case statement that selects the row pattern by character index.
// `STRING_LENGTH` is the only knob — extend the case below if you
// change it.

module tl_simulator_writer #(
    parameter integer STRING_LENGTH = 12   // matches "Hello world!"
) (
    input  wire       inClock,
    output wire [4:0] outLines,
    output reg        done
);

    localparam integer cCharHorLength               = 5;
    localparam integer cClocksForColumn             = 5;
    localparam integer cColumnSeparatorBetweenChars = 1;

    // Packed 2D array (SystemVerilog) rather than the unpacked
    // `reg [4:0] sCurrentChar [0:4]` form: yosys's memory_collect
    // treats unpacked arrays as memories, and for this 25-bit-total
    // glyph buffer that triggers a "Replacing memory ... with list
    // of registers" warning (the array is too small for BRAM, so
    // yosys converts it to FFs anyway — the warning is informational
    // but counts toward the project's zero-warning goal). A packed
    // declaration expresses the same shape but as a single flat
    // register, so yosys skips memory inference entirely. Access
    // patterns (`sCurrentChar[row]`, `sCurrentChar[row][bit]`) are
    // unchanged.
    reg [4:0][4:0] sCurrentChar;
    reg [4:0]  sOutRow;
    reg        sCurrentBlank;

    // The VHDL twin keeps these as process *variables*; GHDL does not
    // surface them in the FST dump. They live at module scope here for
    // yosys compatibility (static locals inside a named always block
    // are not yet accepted by the yosys SV frontend) — the testbench
    // hides them via an explicit $dumpvars signal list so the two
    // waveforms still show the same signal set.
    integer vCurrentCharIdx                 = 1;
    integer vCountForSeparatorBetweenChars  = 0;
    integer vCounterForClocksForColumn      = 0;
    integer vCharHorIndex                   = 0;

    initial begin
        sOutRow       = 5'b00000;
        sCurrentBlank = 1'b0;
        done          = 1'b0;
        sCurrentChar  = 25'b0;   // packed array: a single flat literal zeroes all 5 rows
    end

    always @(posedge inClock) begin
        done <= 1'b0;

        if (vCounterForClocksForColumn == cClocksForColumn - 1 || sCurrentBlank) begin
            vCounterForClocksForColumn <= 0;
            if (vCharHorIndex == cCharHorLength - 1 || sCurrentBlank) begin
                vCharHorIndex <= 0;
                if (vCurrentCharIdx == STRING_LENGTH) begin
                    vCurrentCharIdx <= 1;
                    done            <= 1'b1;
                end else begin
                    if (vCountForSeparatorBetweenChars == cColumnSeparatorBetweenChars) begin
                        vCountForSeparatorBetweenChars <= 0;
                        vCurrentCharIdx    <= vCurrentCharIdx + 1;
                        sCurrentBlank      <= 1'b0;
                    end else begin
                        sCurrentBlank      <= 1'b1;
                        vCountForSeparatorBetweenChars <= vCountForSeparatorBetweenChars + 1;
                    end
                end
            end else begin
                vCharHorIndex <= vCharHorIndex + 1;
            end
        end else begin
            vCounterForClocksForColumn <= vCounterForClocksForColumn + 1;
        end

        // Character bitmap selection — same patterns as the VHDL.
        case (vCurrentCharIdx)
            1: begin
                sCurrentChar[0] <= 5'b10001;
                sCurrentChar[1] <= 5'b10001;
                sCurrentChar[2] <= 5'b11111;
                sCurrentChar[3] <= 5'b10001;
                sCurrentChar[4] <= 5'b10001;
            end
            2: begin
                sCurrentChar[0] <= 5'b11111;
                sCurrentChar[1] <= 5'b10000;
                sCurrentChar[2] <= 5'b11100;
                sCurrentChar[3] <= 5'b10000;
                sCurrentChar[4] <= 5'b11111;
            end
            3, 4, 10: begin
                sCurrentChar[0] <= 5'b10000;
                sCurrentChar[1] <= 5'b10000;
                sCurrentChar[2] <= 5'b10000;
                sCurrentChar[3] <= 5'b10000;
                sCurrentChar[4] <= 5'b11111;
            end
            5, 8: begin
                sCurrentChar[0] <= 5'b01110;
                sCurrentChar[1] <= 5'b10001;
                sCurrentChar[2] <= 5'b10001;
                sCurrentChar[3] <= 5'b10001;
                sCurrentChar[4] <= 5'b01110;
            end
            7: begin
                sCurrentChar[0] <= 5'b10001;
                sCurrentChar[1] <= 5'b10001;
                sCurrentChar[2] <= 5'b10001;
                sCurrentChar[3] <= 5'b10101;
                sCurrentChar[4] <= 5'b01010;
            end
            9: begin
                sCurrentChar[0] <= 5'b11100;
                sCurrentChar[1] <= 5'b10010;
                sCurrentChar[2] <= 5'b11100;
                sCurrentChar[3] <= 5'b10010;
                sCurrentChar[4] <= 5'b10001;
            end
            11: begin
                sCurrentChar[0] <= 5'b11110;
                sCurrentChar[1] <= 5'b10001;
                sCurrentChar[2] <= 5'b10001;
                sCurrentChar[3] <= 5'b10001;
                sCurrentChar[4] <= 5'b11110;
            end
            default: begin
                sCurrentChar[0] <= 5'b00000;
                sCurrentChar[1] <= 5'b00000;
                sCurrentChar[2] <= 5'b00000;
                sCurrentChar[3] <= 5'b00000;
                sCurrentChar[4] <= 5'b00000;
            end
        endcase

        // Unrolled per-row update — iverilog rejects variable indexing
        // into a packed 2D array (the `sCurrentChar[i]` form below
        // needed a runtime `i`), so the loop is expanded to five
        // explicit constant-indexed statements. The packed array is
        // what dodges yosys's "Replacing memory ... with list of
        // registers" warning; the unroll is the trade-off.
        if (sCurrentBlank) sOutRow[0] <= 1'b0;
        else               sOutRow[0] <= sCurrentChar[0][cCharHorLength - 1 - vCharHorIndex];
        if (sCurrentBlank) sOutRow[1] <= 1'b0;
        else               sOutRow[1] <= sCurrentChar[1][cCharHorLength - 1 - vCharHorIndex];
        if (sCurrentBlank) sOutRow[2] <= 1'b0;
        else               sOutRow[2] <= sCurrentChar[2][cCharHorLength - 1 - vCharHorIndex];
        if (sCurrentBlank) sOutRow[3] <= 1'b0;
        else               sOutRow[3] <= sCurrentChar[3][cCharHorLength - 1 - vCharHorIndex];
        if (sCurrentBlank) sOutRow[4] <= 1'b0;
        else               sOutRow[4] <= sCurrentChar[4][cCharHorLength - 1 - vCharHorIndex];
    end

    // Combinational gating: each output is the clock when its row is on.
    // Per-bit continuous assigns (rather than an always_comb with
    // constant bit-selects) — iverilog warns about the latter as a
    // not-yet-supported form.
    assign outLines[4] = sOutRow[0] ? inClock : 1'b0;
    assign outLines[3] = sOutRow[1] ? inClock : 1'b0;
    assign outLines[2] = sOutRow[2] ? inClock : 1'b0;
    assign outLines[1] = sOutRow[3] ? inClock : 1'b0;
    assign outLines[0] = sOutRow[4] ? inClock : 1'b0;

endmodule
