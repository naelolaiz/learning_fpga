// Verilog mirror of tb_random_generator.vhd.
//
// Short-window TB (10 ms) for the random-hex display.
// inputButtons all-high (no freeze). DIVIDER_MAX / ENABLE_HIGH are
// compressed via parameter override so several refresh cycles fit
// in the window.
//
// Asserts:
//   (A) cableSelect is always one-hot-inverted (exactly one '0').
//   (B) sevenSegments is always one of the 16 valid hex encodings.
//   (C) By end-of-sim, every digit has been mux-selected at least
//       once.

`timescale 1ns/1ps

module tb_random_generator;

    localparam time TEST_DURATION = 10_000_000;  // 10 ms in ns

    localparam integer SIM_DIVIDER = 2_500;
    localparam integer SIM_GATE    = 200;

    reg        sClock50MHz   = 1'b0;
    reg  [3:0] sInputButtons = 4'b1111;
    wire [6:0] sSevenSegments;
    wire [3:0] sCableSelect;
    wire [3:0] sLeds;

    reg sSeenDigit0 = 1'b0;
    reg sSeenDigit1 = 1'b0;
    reg sSeenDigit2 = 1'b0;
    reg sSeenDigit3 = 1'b0;

    reg sSimulationActive = 1'b1;

    random_generator #(
        .DIVIDER_MAX (SIM_DIVIDER),
        .ENABLE_HIGH (SIM_GATE)
    ) dut (
        .clock         (sClock50MHz),
        .inputButtons  (sInputButtons),
        .sevenSegments (sSevenSegments),
        .cableSelect   (sCableSelect),
        .leds          (sLeds)
    );

    always #10 if (sSimulationActive) sClock50MHz = ~sClock50MHz;

    function automatic is_one_hot_inverted(input [3:0] v);
        is_one_hot_inverted = ((v == 4'b1110) || (v == 4'b1101)
                            || (v == 4'b1011) || (v == 4'b0111));
    endfunction

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
                $fatal(1, "sevenSegments is not a valid hex encoding: %b", sSevenSegments);
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
        $dumpvars(1, tb_random_generator);
        $dumpvars(1, dut);
    end

    initial begin : driver
        #(TEST_DURATION);

        if (!(sSeenDigit0 && sSeenDigit1 && sSeenDigit2 && sSeenDigit3))
            $fatal(1, "mux stuck: seen digits = %b%b%b%b",
                   sSeenDigit0, sSeenDigit1, sSeenDigit2, sSeenDigit3);

        $display("tb_random_generator simulation done!");
        sSimulationActive = 1'b0;
        $finish;
    end

endmodule
