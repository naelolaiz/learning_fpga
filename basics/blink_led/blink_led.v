// Verilog mirror of blink_led.vhd.
//
// Precise-period blinker: a counter wraps at exactly
// CLOCKS_TO_OVERFLOW cycles, and on each wrap a 1-bit `pulse`
// register toggles. `led` follows `pulse`.
//
// Full on/off period: 2 * CLOCKS_TO_OVERFLOW / f_clk.
// Cost: two register cells (multi-bit counter + one-bit pulse),
// plus a comparator and a mux. Each counter bit is a flip-flop.
// For a simpler single-vector-register version that fixes the
// period to a power of two, see `blink_led_minimal.v`.

module blink_led #(
    parameter integer CLOCKS_TO_OVERFLOW = 50_000_000
) (
    input  wire clk,
    output wire led
);

    reg pulse = 1'b0;
    reg [31:0] count = 32'd0;

    always @(posedge clk) begin
        if (count == CLOCKS_TO_OVERFLOW - 1) begin
            count <= 32'd0;
            pulse <= ~pulse;
        end else begin
            count <= count + 32'd1;
        end
    end

    assign led = pulse;

endmodule
