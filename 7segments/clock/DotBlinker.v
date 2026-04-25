// Verilog mirror of DotBlinker.vhd.
//
// Drives the middle-digit decimal-point blink signal:
//   isHHMMMode = 1'b0 (MMSS view): dotOut tracks oneSecondPeriodSquare
//                                  -> 1 transition per rising AND
//                                     falling edge of the 1 Hz square.
//   isHHMMMode = 1'b1 (HHMM view): dotOut toggles only on rising edges
//                                  -> half the rate of the MMSS path.

module DotBlinker (
    input  wire oneSecondPeriodSquare,
    input  wire isHHMMMode,
    output wire dotOut
);

    reg toggled = 1'b0;

    // Edge-triggered toggle for the HHMM half-rate path. The VHDL mirror
    // uses an explicit `rising_edge(...)` process — `posedge` here is the
    // Verilog spelling of the same thing.
    always @(posedge oneSecondPeriodSquare) begin
        toggled <= ~toggled;
    end

    assign dotOut = (isHHMMMode == 1'b0) ? oneSecondPeriodSquare : toggled;

endmodule
