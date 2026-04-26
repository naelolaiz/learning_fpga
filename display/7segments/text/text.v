// Verilog mirror of test.vhd (7segments scrolling-text demo).
//
// Two clock-derived counters drive the display:
//   counterForMux       wraps every ~2 ms, advances enabledDigit
//   counterForScrolling wraps every ~SCROLL_MAX cycles (160 ms by
//                       default), advances stringOffset
//
// inputButtons[0] is wired as an active-low scroll-pause: while held,
// the scroll-tick freezes. The mux keeps running so the display
// stays lit. Buttons 1..3 are pinned in the .qsf for future use.
//
// sevenSegments is 8 bits: [6:0] drives the seven cathodes,
// [7] is the decimal point. The '.' character lights only the DP.

module text #(
    parameter integer SCROLL_MAX = 8_000_000  // 8E6 / 50E6 = 160 ms scroll period on hardware
) (
    input  wire       clock,
    input  wire [3:0] inputButtons,
    output reg  [7:0] sevenSegments,
    output reg  [3:0] cableSelect
);

    localparam integer MUX_MAX    = 100_000;   // 100E3 / 50E6 = 2 ms per digit
    localparam integer STRING_LEN = 33;        // length of STRING_TO_PRINT

    // Verilog packs string literals MSB-first: STRING_TO_PRINT[8*N-1 -: 8] is
    // the leftmost character. The string_char function below abstracts the
    // indexing so callers use a friendly 0-based index from the left.
    localparam [STRING_LEN*8-1:0] STRING_TO_PRINT = "_-+-_- Hello FPGA Wworld _-+-==- ";

    reg [17:0] counterForMux       = 18'd0;   // wide enough for MUX_MAX
    reg [31:0] counterForScrolling = 32'd0;   // wide enough for any SCROLL_MAX
    reg [1:0]  enabledDigit        = 2'd0;
    reg [$clog2(STRING_LEN)-1:0] stringOffset = 0;
    reg [7:0]  charForDigit;

    function automatic [7:0] string_char(input integer idx);
        // Wrap idx inside STRING_LEN, then pick the byte.
        integer wrapped;
        begin
            wrapped     = idx % STRING_LEN;
            string_char = STRING_TO_PRINT[(STRING_LEN-1-wrapped)*8 +: 8];
        end
    endfunction

    // Mux + scroll counters. inputButtons[0] is active-low; held = scroll paused.
    always @(posedge clock) begin
        // Mux tick (always running, regardless of pause).
        if (counterForMux == MUX_MAX - 1) begin
            counterForMux <= 18'd0;
            enabledDigit  <= enabledDigit + 2'd1;
        end else begin
            counterForMux <= counterForMux + 18'd1;
        end

        // Scroll tick: paused while inputButtons[0] is held low.
        if (inputButtons[0] == 1'b1) begin
            if (counterForScrolling == SCROLL_MAX - 1) begin
                counterForScrolling <= 32'd0;
                if (stringOffset == STRING_LEN - 1)
                    stringOffset <= 0;
                else
                    stringOffset <= stringOffset + 1'd1;
            end else begin
                counterForScrolling <= counterForScrolling + 32'd1;
            end
        end
    end

    // Anode mux: 2:4 active-low decoder.
    always_comb begin
        case (enabledDigit)
            2'd0:    cableSelect = 4'b1110;
            2'd1:    cableSelect = 4'b1101;
            2'd2:    cableSelect = 4'b1011;
            default: cableSelect = 4'b0111;
        endcase
    end

    // Pick the character for the currently-active digit. The mux rotates
    // 0..3 left-to-right but text reads right-to-left across the physical
    // layout; (3 - enabledDigit) reverses the selection so the leftmost
    // digit shows the earliest character of the visible window.
    always_comb begin
        charForDigit = string_char(stringOffset + (3 - enabledDigit));
    end

    // ASCII-to-7-segment decode. Bit 7 is the decimal point;
    // bits[6:0] are the cathodes a..g (active-low, common-anode).
    always_comb begin
        case (charForDigit)
            "0":      sevenSegments = 8'b11000000;
            "1":      sevenSegments = 8'b11111001;
            "2":      sevenSegments = 8'b10100100;
            "3":      sevenSegments = 8'b10110000;
            "4":      sevenSegments = 8'b10011001;
            "5":      sevenSegments = 8'b10010010;
            "6":      sevenSegments = 8'b10000010;
            "7":      sevenSegments = 8'b11111000;
            "8":      sevenSegments = 8'b10000000;
            "9":      sevenSegments = 8'b10010000;
            "=":      sevenSegments = 8'b11110110;
            "+":      sevenSegments = 8'b11111110;
            "-":      sevenSegments = 8'b10111111;
            "_":      sevenSegments = 8'b11110111;
            " ":      sevenSegments = 8'b11111111;
            "'":      sevenSegments = 8'b11111101;
            ",":      sevenSegments = 8'b11111011;
            ".":      sevenSegments = 8'b01111111;
            "A":      sevenSegments = 8'b10001000;
            "a":      sevenSegments = 8'b00100000;
            "B":      sevenSegments = 8'b10000011;
            "b":      sevenSegments = 8'b10000011;
            "C":      sevenSegments = 8'b11000110;
            "c":      sevenSegments = 8'b10100111;
            "D":      sevenSegments = 8'b10100001;
            "d":      sevenSegments = 8'b10100001;
            "E":      sevenSegments = 8'b10000110;
            "e":      sevenSegments = 8'b10000100;
            "F":      sevenSegments = 8'b10001110;
            "f":      sevenSegments = 8'b10001110;
            "G":      sevenSegments = 8'b10010000;
            "g":      sevenSegments = 8'b10010000;
            "H":      sevenSegments = 8'b10001001;
            "h":      sevenSegments = 8'b10001011;
            "I":      sevenSegments = 8'b11001111;
            "i":      sevenSegments = 8'b11101111;
            "J":      sevenSegments = 8'b11110001;
            "j":      sevenSegments = 8'b11110001;
            "L":      sevenSegments = 8'b11000111;
            "l":      sevenSegments = 8'b11001111;
            "M":      sevenSegments = 8'b11001100;  // first half of a 2-digit M
            "m":      sevenSegments = 8'b11011000;  // second half
            "N":      sevenSegments = 8'b10101011;
            "n":      sevenSegments = 8'b10101011;
            "O":      sevenSegments = 8'b11000000;
            "o":      sevenSegments = 8'b10100011;
            "P":      sevenSegments = 8'b10001100;
            "p":      sevenSegments = 8'b10001100;
            "Q":      sevenSegments = 8'b01000000;
            "q":      sevenSegments = 8'b01000000;
            "R":      sevenSegments = 8'b10101111;
            "r":      sevenSegments = 8'b10101111;
            "S":      sevenSegments = 8'b10010010;
            "s":      sevenSegments = 8'b10010010;
            "T":      sevenSegments = 8'b10001111;
            "t":      sevenSegments = 8'b10001111;
            "U":      sevenSegments = 8'b11000001;
            "u":      sevenSegments = 8'b11100011;
            "W":      sevenSegments = 8'b11000011;  // first half of a 2-digit W
            "w":      sevenSegments = 8'b11100001;  // second half
            "X":      sevenSegments = 8'b11110000;  // first half of a 2-digit X
            "x":      sevenSegments = 8'b11000110;  // second half
            "Y":      sevenSegments = 8'b10011011;  // first half of a 2-digit y
            "y":      sevenSegments = 8'b10101101;  // second half
            "Z":      sevenSegments = 8'b10100100;
            "z":      sevenSegments = 8'b10100100;
            default:  sevenSegments = 8'b11111111;
        endcase
    end

endmodule
