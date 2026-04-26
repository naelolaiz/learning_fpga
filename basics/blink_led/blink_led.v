// Verilog mirror of blink_led.vhd.
//
// Toggles `led` every CLOCKS_TO_OVERFLOW cycles of `clk`. Minimal
// example — for the same counter wired together with buttons / logic
// gates, see basics/glossary.

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
