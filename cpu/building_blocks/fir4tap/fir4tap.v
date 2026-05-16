// fir4tap.v - Verilog mirror of fir4tap.vhd.
//
// See the VHDL twin for data widths, Q1.8 coefficient format, the
// 2-cycle latency contract, and the bit-slice convention.

`default_nettype none

module fir4tap (
    input  wire        clk,
    input  wire        rst,

    input  wire signed [8:0]  coeff_0,
    input  wire signed [8:0]  coeff_1,
    input  wire signed [8:0]  coeff_2,
    input  wire signed [8:0]  coeff_3,

    input  wire signed [15:0] sample_in,
    input  wire               sample_valid,

    output reg  signed [15:0] result,
    output reg                result_valid
);

    // Packed 2D array (SystemVerilog) instead of the unpacked
    // `reg signed [15:0] samples [0:3]` form: yosys's memory_collect
    // would otherwise classify the 64-bit buffer as a memory
    // candidate, find it too small to map to BRAM, fall back to
    // flip-flops AND warn. Packed makes it one flat register from
    // the start. Same idiom as tools/simulator_writer/.
    reg signed [3:0][15:0] samples;
    reg                    valid_d1;

    initial begin
        samples      = 64'sd0;
        result       = 16'sd0;
        result_valid = 1'b0;
        valid_d1     = 1'b0;
    end

    // Combinational MAC. Per-product wires give each multiply its
    // own explicit 25-bit signed result, so the implicit-width
    // rules of `*` on signed operands of different widths don't
    // surprise us (Verilog computes at the wider operand's width
    // and truncates — we'd rather state the width up front). Each
    // product then sign-extends to 27 bits for the 4-term sum.
    wire signed [24:0] prod_0 = $signed(samples[0]) * $signed(coeff_0);
    wire signed [24:0] prod_1 = $signed(samples[1]) * $signed(coeff_1);
    wire signed [24:0] prod_2 = $signed(samples[2]) * $signed(coeff_2);
    wire signed [24:0] prod_3 = $signed(samples[3]) * $signed(coeff_3);

    wire signed [26:0] mac_sum =
        $signed({{2{prod_0[24]}}, prod_0}) +
        $signed({{2{prod_1[24]}}, prod_1}) +
        $signed({{2{prod_2[24]}}, prod_2}) +
        $signed({{2{prod_3[24]}}, prod_3});

    always @(posedge clk) begin
        if (rst) begin
            samples      <= 64'sd0;     // packed: one flat zero literal
            valid_d1     <= 1'b0;
            result_valid <= 1'b0;
            result       <= 16'sd0;
        end else begin
            // Two-stage matching delay for result_valid.
            valid_d1     <= sample_valid;
            result_valid <= valid_d1;
            if (sample_valid) begin
                samples[0] <= sample_in;
                samples[1] <= samples[0];
                samples[2] <= samples[1];
                samples[3] <= samples[2];
            end
            if (valid_d1)
                result <= mac_sum[23:8];   // Q1.8: integer-domain = mac_sum >> 8
        end
    end

endmodule

`default_nettype wire
