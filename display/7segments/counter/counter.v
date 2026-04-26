// Verilog mirror of test.vhd (7segments counter demo).
//
// Drives a 4-digit multiplexed 7-segment display: each digit lights for
// ~2 ms in turn (counterForMux), and the displayed value increments by
// one every ~62.5 ms (counterForCounter). The result is a base-16
// counter ticking on the rightmost digit, with carry propagating to the
// digits to the left.

module counter (
    input  wire       clock,
    output reg  [6:0] sevenSegments,
    output reg  [3:0] cableSelect
);

    localparam integer NUMBER_OF_DIGITS = 4;
    localparam integer BITS_PER_NIBBLE  = 4;

    // Match the VHDL ranges (3_125_000 / 100_000).
    localparam integer COUNTER_MAX = 3_125_000;
    localparam integer MUX_MAX     = 100_000;

    reg [22:0] counterForCounter = 23'd0;   // wide enough for COUNTER_MAX
    reg [17:0] counterForMux     = 18'd0;   // wide enough for MUX_MAX

    reg [NUMBER_OF_DIGITS*BITS_PER_NIBBLE-1:0] numberToDisplay = 16'd0;
    reg [1:0] enabledDigit = 2'd0;
    reg [BITS_PER_NIBBLE-1:0] currentDigitValue;

    always @(posedge clock) begin
        // Multiplex tick.
        if (counterForMux == MUX_MAX - 1) begin
            counterForMux <= 18'd0;
            if (enabledDigit == NUMBER_OF_DIGITS - 1)
                enabledDigit <= 2'd0;
            else
                enabledDigit <= enabledDigit + 2'd1;
        end else begin
            counterForMux <= counterForMux + 18'd1;
        end

        // Number-to-display tick.
        if (counterForCounter == COUNTER_MAX - 1) begin
            counterForCounter <= 23'd0;
            numberToDisplay   <= numberToDisplay + 16'd1;
        end else begin
            counterForCounter <= counterForCounter + 23'd1;
        end
    end

    // Anode mux + nibble select.
    always_comb begin
        // Active-low one-hot for the four digits.
        case (enabledDigit)
            2'd0: cableSelect = 4'b1110;
            2'd1: cableSelect = 4'b1101;
            2'd2: cableSelect = 4'b1011;
            default: cableSelect = 4'b0111;
        endcase
        // Pick the nibble for the currently-active digit.
        currentDigitValue =
            numberToDisplay[(enabledDigit*BITS_PER_NIBBLE) +: BITS_PER_NIBBLE];
    end

    // 7-segment decode (active-low segments, common-anode).
    always_comb begin
        case (currentDigitValue)
            4'h0: sevenSegments = 7'b1000000;
            4'h1: sevenSegments = 7'b1111001;
            4'h2: sevenSegments = 7'b0100100;
            4'h3: sevenSegments = 7'b0110000;
            4'h4: sevenSegments = 7'b0011001;
            4'h5: sevenSegments = 7'b0010010;
            4'h6: sevenSegments = 7'b0000010;
            4'h7: sevenSegments = 7'b1111000;
            4'h8: sevenSegments = 7'b0000000;
            4'h9: sevenSegments = 7'b0010000;
            4'hA: sevenSegments = 7'b0001000;
            4'hB: sevenSegments = 7'b0000011;
            4'hC: sevenSegments = 7'b1000110;
            4'hD: sevenSegments = 7'b0100001;
            4'hE: sevenSegments = 7'b0000110;
            default: sevenSegments = 7'b0001110;   // F
        endcase
    end

endmodule
