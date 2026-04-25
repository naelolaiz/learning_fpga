// Verilog mirror of Debounce.vhd (originally from nandland.com).
//
// Holds the output stable until the input has been the new value for
// DEBOUNCE_LIMIT consecutive clock cycles. Default 250 000 ticks at
// 25 MHz = 10 ms — same value the VHDL uses.

module Debounce #(
    parameter integer DEBOUNCE_LIMIT = 250_000
) (
    input  wire i_Clk,
    input  wire i_Switch,
    output wire o_Switch
);

    reg [31:0] r_Count = 32'd0;
    reg        r_State = 1'b0;

    always @(posedge i_Clk) begin
        if (i_Switch != r_State && r_Count < DEBOUNCE_LIMIT) begin
            r_Count <= r_Count + 32'd1;
        end else if (r_Count == DEBOUNCE_LIMIT) begin
            r_State <= i_Switch;
            r_Count <= 32'd0;
        end else begin
            r_Count <= 32'd0;
        end
    end

    assign o_Switch = r_State;

endmodule
