// Verilog mirror of AlarmTrigger.vhd.
//
// Compares the running clock's BCD vs the user-set alarm BCD and
// produces an intermittent buzzer signal:
//   * compare bits 23..4 (above seconds-units) -- a single match holds
//     for ~10 simulated seconds before seconds-tens advances past it;
//   * `tone & gate` (~400 Hz tone AND-gated by 1 Hz square) when matched;
//   * `1'b0` (driven low) when not matched.
//
// The 2022 source emitted 'Z' on the no-match branch; see the matching
// note in AlarmTrigger.vhd for why both flows now drive '0' instead.

module AlarmTrigger (
    input  wire [23:0] mainBcd,
    input  wire [23:0] alarmBcd,
    input  wire        tone,
    input  wire        gate,
    output wire        buzzerOut
);

    assign buzzerOut = (alarmBcd[23:4] == mainBcd[23:4]) ? (tone & gate)
                                                         : 1'b0;

endmodule
