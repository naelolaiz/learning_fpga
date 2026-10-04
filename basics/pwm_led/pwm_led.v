// pwm_led.v - Verilog mirror of pwm_led.vhd.
//
// Pulse-width-modulated LED driver. The WIDTH-bit `duty` input picks
// the on-fraction of every 2**WIDTH-tick window (0 = off).
// At WIDTH=8, duty=255 is 255/256 high, with one low clock interval.

module pwm_led #(
    parameter integer WIDTH = 8
) (
    input  wire             clk,
    input  wire [WIDTH-1:0] duty,
    output wire             pwm_out
);

    reg [WIDTH-1:0] counter = {WIDTH{1'b0}};

    always @(posedge clk) begin
        counter <= counter + 1'b1;
    end

    assign pwm_out = (counter < duty);

endmodule
