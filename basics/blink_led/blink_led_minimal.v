// The "absolute minimum" blinking-LED -- Verilog mirror of
// blink_led_minimal.vhd. See that file for the side-by-side
// commentary against `blink_led.v`. Summary:
//
//   * `blink_led` has TWO flip-flops (counter + separate `pulse`
//     register) so the period is exactly `CLOCKS_TO_OVERFLOW` cycles.
//   * `blink_led_minimal` (this file) has ONE flip-flop -- the
//     counter -- and the LED is the counter's top bit. Period is
//     fixed at 2^WIDTH / f_clk (a power of two, not arbitrary).
//
// The diagram for this module (build/blink_led_minimal.svg) shows
// a single register cell vs. two for the sibling. Use this whenever
// the exact blink rate isn't required.

module blink_led_minimal #(
    // Counter width. LED period = 2^WIDTH cycles of clk
    // (MSB toggles every 2^(WIDTH-1)).
    parameter integer WIDTH = 25
) (
    input  wire clk,
    output wire led
);

    reg [WIDTH-1:0] counter = {WIDTH{1'b0}};

    always @(posedge clk) begin
        counter <= counter + 1'b1;
    end

    // Top bit of the free-running counter is the LED. No separate
    // pulse flip-flop, no overflow compare -- compare with
    // blink_led.v to see what each line costs in cells.
    assign led = counter[WIDTH-1];

endmodule
