// mode_blink — Verilog mirror of mode_blink.vhd.
//
//   toggleMode = 0 → signalOut tracks signalIn directly (full-rate
//                    blink — one transition per rising AND each
//                    falling edge of signalIn).
//   toggleMode = 1 → signalOut toggles only on rising edges of
//                    signalIn (half-rate blink).
//
// Originally lived as DotBlinker inside the 7-segments clock
// project. The logic is generic; renamed and lifted out.

module mode_blink (
    input  wire signalIn,
    input  wire toggleMode,
    output wire signalOut
);

    reg toggled = 1'b0;

    always @(posedge signalIn)
        toggled <= ~toggled;

    assign signalOut = (toggleMode == 1'b0) ? signalIn : toggled;

endmodule
