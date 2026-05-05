// tone_gen.v - Verilog mirror of tone_gen.vhd.
//
// Half-scale square wave on a 24-bit signed bus, toggled every
// TOGGLE_HALF_CYCLES rising edges of clk. Driven from LRCLK,
// produces F_tone = Fs / (2 * TOGGLE_HALF_CYCLES).

module tone_gen #(
    parameter integer TOGGLE_HALF_CYCLES = 96
) (
    input  wire        clk,
    input  wire        reset,                // active-high
    output wire [23:0] sample
);

    reg [31:0] counter = 32'd0;
    reg        level   = 1'b0;

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            counter <= 32'd0;
            level   <= 1'b0;
        end else if (counter == TOGGLE_HALF_CYCLES-1) begin
            counter <= 32'd0;
            level   <= ~level;
        end else begin
            counter <= counter + 32'd1;
        end
    end

    assign sample = level ? 24'h400000 : 24'hC00000;

endmodule
