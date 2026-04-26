// Verilog mirror of tb_text.vhd.
//
// Short-window TB (10 ms) for the scrolling-text demo.
// inputButtons all-high (no scroll-pause).
//
// Asserts:
//   (A) cableSelect is always one-hot-inverted (exactly one '0').
//   (B) sevenSegments is never undefined ('x'/'z').
//   (C) By end-of-sim, every one of the four digits has been
//       selected at least once by the mux.

`timescale 1ns/1ps

module tb_text;

    localparam time TEST_DURATION = 10_000_000;  // 10 ms in ns

    reg        sClock50MHz   = 1'b0;
    reg  [3:0] sInputButtons = 4'b1111;
    wire [7:0] sSevenSegments;
    wire [3:0] sCableSelect;

    reg sSeenDigit0 = 1'b0;
    reg sSeenDigit1 = 1'b0;
    reg sSeenDigit2 = 1'b0;
    reg sSeenDigit3 = 1'b0;

    reg sSimulationActive = 1'b1;

    test dut (
        .clock         (sClock50MHz),
        .inputButtons  (sInputButtons),
        .sevenSegments (sSevenSegments),
        .cableSelect   (sCableSelect)
    );

    always #10 if (sSimulationActive) sClock50MHz = ~sClock50MHz;

    function automatic is_one_hot_inverted(input [3:0] v);
        is_one_hot_inverted = ((v == 4'b1110) || (v == 4'b1101)
                            || (v == 4'b1011) || (v == 4'b0111));
    endfunction

    // (A) and (B): continuous invariants. Each waits a short settle
    // window so the DUT has driven its outputs out of reset before
    // the checks begin.
    initial begin : assert_A_one_hot
        #200;
        forever begin
            @(sCableSelect);
            if (!is_one_hot_inverted(sCableSelect))
                $fatal(1, "cableSelect violated one-hot-inverted invariant: %b", sCableSelect);
        end
    end

    initial begin : assert_B_defined
        #200;
        forever begin
            @(sSevenSegments);
            if (^sSevenSegments === 1'bx)
                $fatal(1, "sevenSegments contains an undefined bit: %b", sSevenSegments);
        end
    end

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
        $dumpvars(1, tb_text);
        $dumpvars(1, dut);
    end

    initial begin : driver
        #(TEST_DURATION);

        if (!(sSeenDigit0 && sSeenDigit1 && sSeenDigit2 && sSeenDigit3))
            $fatal(1, "mux stuck: seen digits = %b%b%b%b",
                   sSeenDigit0, sSeenDigit1, sSeenDigit2, sSeenDigit3);

        $display("tb_text simulation done!");
        sSimulationActive = 1'b0;
        $finish;
    end

endmodule
