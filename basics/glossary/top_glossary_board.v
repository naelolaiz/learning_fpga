// Verilog mirror of top_glossary_board.vhd. See that file for the
// LED mapping rationale and the pointer to the sibling project
// `basics/logic_styles` for the coding-style tutorial.

`default_nettype none

module top_glossary_board (
    input  wire       clk,
    input  wire       button1,   // active-low; PIN_88 / KEY1
    input  wire       button2,   // active-low; PIN_89 / KEY2
    output wire [3:0] leds
);

    wire a = ~button1;
    wire b = ~button2;

    wire w_and, w_or, w_xor, w_xnor;

    glossary glossary_inst (
        .a            (a),
        .b            (b),
        .sel          (1'b0),
        .sel4         (2'b00),
        .av           (4'b0000),
        .bv           (4'b0000),
        .clk          (clk),
        .rst          (1'b1),
        .en           (1'b0),
        .o_and        (w_and),
        .o_or         (w_or),
        .o_not        (),
        .o_xor        (w_xor),
        .o_nand       (),
        .o_nor        (),
        .o_xnor       (w_xnor),
        .o_reduce_or  (),
        .o_reduce_and (),
        .o_reduce_xor (),
        .o_mux2       (),
        .o_mux4       (),
        .o_add        (),
        .o_sub        (),
        .o_eq         (),
        .o_lt         (),
        .o_shl        (),
        .o_shr        (),
        .o_dff        (),
        .o_dffe       (),
        .o_dffr       (),
        .o_counter    ()
    );

    assign leds[0] = w_and;
    assign leds[1] = w_or;
    assign leds[2] = w_xor;
    assign leds[3] = w_xnor;

endmodule

`default_nettype wire
