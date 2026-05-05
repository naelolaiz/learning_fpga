// nco_sine.v - Verilog mirror of nco_sine.vhd.
//
// 32-bit phase accumulator; top 14 bits index `sincos_lut`. Output
// frequency at a clock rate Fclk:
//   Fout = (phase_inc / 2**32) * Fclk
// Driven from LRCLK (Fclk = sample rate), `phase_inc` directly
// encodes "Hz at the current sample rate".

module nco_sine (
    input  wire        clk,
    input  wire        reset,
    input  wire [31:0] phase_inc,
    output wire [15:0] sin_out          // signed
);

    reg  [31:0] phase_acc = 32'd0;
    wire [13:0] lut_addr  = phase_acc[31:18];

    always @(posedge clk or posedge reset) begin
        if (reset)
            phase_acc <= 32'd0;
        else
            phase_acc <= phase_acc + phase_inc;
    end

    sincos_lut lut (
        .clk     (clk),
        .addr    (lut_addr),
        .sin_out (sin_out)
    );

endmodule
