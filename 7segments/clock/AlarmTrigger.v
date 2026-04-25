// Verilog mirror of AlarmTrigger.vhd.
//
// Compares the running clock's BCD vs the user-set alarm BCD and
// produces an intermittent buzzer signal:
//   * compare bits 23..4 (above seconds-units) -- a single match holds
//     for ~10 simulated seconds before seconds-tens advances past it;
//   * `tone & gate` (~400 Hz tone AND-gated by 1 Hz square) when matched;
//   * `1'bz` (high impedance) when not matched.
//
// Reproduces the original commit 083576f intermittent-tone pattern as a
// standalone module so testbenches can stimulate match/mismatch cases
// without spinning the BCD cascades.

module AlarmTrigger (
    input  wire [23:0] mainBcd,
    input  wire [23:0] alarmBcd,
    input  wire        tone,
    input  wire        gate,
    output wire        buzzerOut
);

    // The compare and the gate output the same 'Z' fallback as the VHDL
    // mirror (the 2022 design relied on the FPGA pin floating between
    // alarms; we keep the same semantics in simulation).
    assign buzzerOut = (alarmBcd[23:4] == mainBcd[23:4]) ? (tone & gate)
                                                          : 1'bz;

endmodule
