// Verilog mirror of tb_counter.vhd.
//
// The DUT multiplexes one of four digits onto a shared 7-segment
// display, cycling through them via cableSelect (active-low,
// one-hot-inverted) every ~2 ms. sevenSegments carries the seven
// cathode lines (also active-low) encoding the digit currently
// selected.
//
// Three things are asserted (matches the VHDL TB):
//   (A) cableSelect is always one-hot-inverted (exactly one '0').
//   (B) sevenSegments is always one of the 16 valid BCD encodings.
//   (C) By end-of-sim, each of the four digits has been selected at
//       least once by the mux (rules out a stuck multiplexer).

`timescale 1ns/1ps

module tb_counter;

    // Shorter than the VHDL TB (150 ms) but long enough to rotate
    // through all four digits: mux period is 2 ms at 50 MHz, so
    // 10 ms covers one full rotation and the start of the next.
    // Keeps iverilog's runtime + VCD size manageable in CI.
    localparam time TEST_DURATION = 10_000_000;  // 10 ms in ns
    reg        sClock50MHz   = 1'b0;
    wire [6:0] sSevenSegments;
    wire [3:0] sCableSelect;

    // Seen-flags fed by track_digits_seen; checked at end of sim.
    reg sSeenDigit0 = 1'b0;
    reg sSeenDigit1 = 1'b0;
    reg sSeenDigit2 = 1'b0;
    reg sSeenDigit3 = 1'b0;

    reg sSimulationActive = 1'b1;

    counter dut (
        .clock         (sClock50MHz),
        .sevenSegments (sSevenSegments),
        .cableSelect   (sCableSelect)
    );

    always #10 if (sSimulationActive) sClock50MHz = ~sClock50MHz;

    // (A) cableSelect must have exactly one '0'.
    function automatic is_one_hot_inverted(input [3:0] v);
        is_one_hot_inverted = ((v == 4'b1110) || (v == 4'b1101)
                            || (v == 4'b1011) || (v == 4'b0111));
    endfunction

    // (B) sevenSegments must be one of the 16 encodings produced by
    // the DUT's combinational decoder. Listed here, not imported,
    // so the TB doubles as documentation of the expected encoding.
    function automatic is_valid_7seg(input [6:0] v);
        case (v)
            7'b1000000, 7'b1111001, 7'b0100100, 7'b0110000,
            7'b0011001, 7'b0010010, 7'b0000010, 7'b1111000,
            7'b0000000, 7'b0010000, 7'b0001000, 7'b0000011,
            7'b1000110, 7'b0100001, 7'b0000110, 7'b0001110:
                is_valid_7seg = 1'b1;
            default:
                is_valid_7seg = 1'b0;
        endcase
    endfunction

    // (A) and (B): continuous invariants. Each process waits a short
    // settle window at t=0 so the DUT has driven its outputs out of
    // their undefined reset values before the checks begin, then
    // fires on every change of the observed signal — mirrors the VHDL
    // TB's sequential assertion processes.
    initial begin : assert_A_one_hot
        #200;
        forever begin
            @(sCableSelect);
            if (!is_one_hot_inverted(sCableSelect))
                $fatal(1, "cableSelect violated one-hot-inverted invariant: %b", sCableSelect);
        end
    end

    initial begin : assert_B_valid_encoding
        #200;
        forever begin
            @(sSevenSegments);
            if (!is_valid_7seg(sSevenSegments))
                $fatal(1, "sevenSegments is not a valid BCD encoding: %b", sSevenSegments);
        end
    end

    // Track which digits have been selected so far. Sampling on the
    // clock edge (rather than an `always @(sCableSelect)` on change)
    // guarantees we catch the initial value even if the simulator
    // doesn't emit a change event for the undefined->valid drive at t=0.
    initial begin : track_digits_seen
        #200;
        forever begin
            @(posedge sClock50MHz);
            case (sCableSelect)
                4'b1110: sSeenDigit0 <= 1'b1;
                4'b1101: sSeenDigit1 <= 1'b1;
                4'b1011: sSeenDigit2 <= 1'b1;
                4'b0111: sSeenDigit3 <= 1'b1;
                default: ;
            endcase
        end
    end

    initial begin
        $dumpfile(`VCD_OUT);
        $dumpvars(1, tb_counter);
        $dumpvars(1, dut);
    end

    initial begin : driver
        #(TEST_DURATION);

        // (C) Mux must have rotated through all four digits.
        if (!(sSeenDigit0 && sSeenDigit1 && sSeenDigit2 && sSeenDigit3))
            $fatal(1, "mux stuck: seen digits = %b%b%b%b",
                   sSeenDigit0, sSeenDigit1, sSeenDigit2, sSeenDigit3);

        $display("tb_counter simulation done!");
        sSimulationActive = 1'b0;
        $finish;
    end

endmodule
