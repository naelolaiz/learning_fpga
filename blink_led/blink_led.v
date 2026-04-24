// Verilog mirror of blink_led.vhd.
//
// Toggles `led` every CLOCKS_TO_OVERFLOW cycles of `clk`; `led2` is the
// XNOR of the same toggle with `button1` (the button is active-low on
// the board, so unpressed = 1 leaves led2 in phase with led).

module blink_led #(
    parameter integer CLOCKS_TO_OVERFLOW = 50_000_000
) (
    input  wire clk,
    input  wire button1,
    output wire led,
    output wire led2
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

    assign led  = pulse;
    assign led2 = ~(pulse ^ button1);

endmodule
