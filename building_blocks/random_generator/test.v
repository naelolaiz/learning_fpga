// Verilog mirror of test.vhd (random-hex display).
//
// A slow gating divider (DIVIDER_MAX cycles) pulses the LFSR's enable
// input high for ENABLE_HIGH cycles every period; new random bytes
// from the LFSR are shifted into numberToDisplay on each rising edge
// of valid while the gate is open. Between pulses the displayed
// value is stable.
//
// Note vs. the VHDL version: that one uses neoTRNG (real entropy on
// hardware, LFSR fallback in sim) gated by IS_SIM. The Verilog mirror
// uses the same LFSR for both — simpler to follow, and on the display
// the visual behaviour is equivalent (random-looking hex digits
// rolling at the gate-divider rate).
//
// Generics:
//   DIVIDER_MAX  Period of the gating divider in clock cycles.
//                Defaulted for hardware (140 ms cycle); the testbench
//                overrides to ~50 us so multiple update cycles fit
//                in a short sim window.
//   ENABLE_HIGH  How many cycles per period the gate is open.
//                Long enough that the LFSR emits at least the two
//                valid bytes needed to refresh the 16-bit shift
//                register.
//
// inputButtons[0] is wired as an active-low freeze: while held,
// new bytes from the LFSR are ignored and the displayed value sticks.

module test #(
    parameter integer DIVIDER_MAX = 7_000_000,  // 7E6  / 50E6 = 140 ms cycle on hardware
    parameter integer ENABLE_HIGH = 1000        // 20 us gate open per cycle on hardware
) (
    input  wire       clock,
    input  wire [3:0] inputButtons,
    output reg  [6:0] sevenSegments,
    output reg  [3:0] cableSelect,
    output wire [3:0] leds
);

    localparam integer MUX_MAX = 100_000;       // 100E3 / 50E6 = 2 ms per digit

    reg [17:0] counterForMux       = 18'd0;
    reg [31:0] counterForGenerator = 32'd0;

    reg  [1:0]  enabledDigit     = 2'd0;
    reg  [15:0] numberToDisplay  = 16'd0;
    reg  [3:0]  currentDigitValue;

    reg         sClockForRandom = 1'b0;
    wire [7:0]  sRndData;
    wire        sRndValid;
    reg         sRndValidPrev   = 1'b0;

    lfsr lfsr_inst (
        .clk    (clock),
        .enable (sClockForRandom),
        .data   (sRndData),
        .valid  (sRndValid)
    );

    // Gating divider: enable is high for ENABLE_HIGH cycles, low for
    // (DIVIDER_MAX - ENABLE_HIGH).
    always @(posedge clock) begin
        if (counterForGenerator == DIVIDER_MAX - 1)
            counterForGenerator <= 32'd0;
        else
            counterForGenerator <= counterForGenerator + 32'd1;

        sClockForRandom <= (counterForGenerator < ENABLE_HIGH);
    end

    assign leds = {3'b000, sClockForRandom};

    // Synchronous edge detector on sRndValid: shift in a fresh byte
    // whenever the LFSR signals valid data, except while the freeze
    // button is held low.
    always @(posedge clock) begin
        sRndValidPrev <= sRndValid;
        if (sRndValid && !sRndValidPrev && inputButtons[0]) begin
            numberToDisplay <= {sRndData, numberToDisplay[15:8]};
        end
    end

    // Mux tick.
    always @(posedge clock) begin
        if (counterForMux == MUX_MAX - 1) begin
            counterForMux <= 18'd0;
            enabledDigit  <= enabledDigit + 2'd1;
        end else begin
            counterForMux <= counterForMux + 18'd1;
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

    // Pick the nibble for the currently-active digit. Indexed part-
    // select keeps iverilog quiet (a case with constant `[N:M]` slices
    // triggers a "sorry: constant selects in always_* …" warning).
    always_comb begin
        currentDigitValue = numberToDisplay[(enabledDigit*4) +: 4];
    end

    // Hex 0..F to 7-segment (active-low cathodes, common-anode).
    always_comb begin
        case (currentDigitValue)
            4'h0:    sevenSegments = 7'b1000000;
            4'h1:    sevenSegments = 7'b1111001;
            4'h2:    sevenSegments = 7'b0100100;
            4'h3:    sevenSegments = 7'b0110000;
            4'h4:    sevenSegments = 7'b0011001;
            4'h5:    sevenSegments = 7'b0010010;
            4'h6:    sevenSegments = 7'b0000010;
            4'h7:    sevenSegments = 7'b1111000;
            4'h8:    sevenSegments = 7'b0000000;
            4'h9:    sevenSegments = 7'b0010000;
            4'hA:    sevenSegments = 7'b0001000;
            4'hB:    sevenSegments = 7'b0000011;
            4'hC:    sevenSegments = 7'b1000110;
            4'hD:    sevenSegments = 7'b0100001;
            4'hE:    sevenSegments = 7'b0000110;
            default: sevenSegments = 7'b0001110;   // F
        endcase
    end

endmodule
