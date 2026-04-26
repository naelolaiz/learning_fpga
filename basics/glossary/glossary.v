// Verilog mirror of glossary.vhd — same port shape, same behaviour.
// Read alongside build/glossary_v.svg to map each netlistsvg shape to
// its cell.

`default_nettype none

module glossary (
    input  wire        a,
    input  wire        b,
    input  wire        sel,
    input  wire [1:0]  sel4,
    input  wire [3:0]  av,
    input  wire [3:0]  bv,
    input  wire        clk,
    input  wire        rst,
    input  wire        en,

    output wire        o_and,
    output wire        o_or,
    output wire        o_not,
    output wire        o_xor,
    output wire        o_nand,
    output wire        o_nor,
    output wire        o_xnor,

    output wire        o_reduce_or,
    output wire        o_reduce_and,
    output wire        o_reduce_xor,

    output wire        o_mux2,
    output wire        o_mux4,

    output wire [3:0]  o_add,
    output wire [3:0]  o_sub,
    output wire        o_eq,
    output wire        o_lt,
    output wire [3:0]  o_shl,
    output wire [3:0]  o_shr,

    output wire        o_dff,
    output wire        o_dffe,
    output wire        o_dffr,
    output wire [3:0]  o_counter
);

    assign o_and  =  (a & b);
    assign o_or   =  (a | b);
    assign o_not  =  ~a;
    assign o_xor  =  (a ^ b);
    assign o_nand = ~(a & b);
    assign o_nor  = ~(a | b);
    assign o_xnor = ~(a ^ b);

    assign o_reduce_or  = | av;
    assign o_reduce_and = & av;
    assign o_reduce_xor = ^ av;

    assign o_mux2 = sel ? a : b;
    assign o_mux4 = (sel4 == 2'b00) ? av[0] :
                    (sel4 == 2'b01) ? av[1] :
                    (sel4 == 2'b10) ? av[2] :
                                      av[3];

    assign o_add = av + bv;
    assign o_sub = av - bv;
    assign o_eq  = (av == bv);
    assign o_lt  = (av <  bv);
    assign o_shl = av << 1;
    assign o_shr = av >> 1;

    reg       r_dff     = 1'b0;
    reg       r_dffe    = 1'b0;
    reg       r_dffr    = 1'b0;
    reg [3:0] r_counter = 4'd0;

    always @(posedge clk) r_dff <= a;

    always @(posedge clk)
        if (en) r_dffe <= a;

    always @(posedge clk)
        if (rst) r_dffr <= 1'b0;
        else     r_dffr <= a;

    always @(posedge clk)
        if (rst) r_counter <= 4'd0;
        else     r_counter <= r_counter + 4'd1;

    assign o_dff     = r_dff;
    assign o_dffe    = r_dffe;
    assign o_dffr    = r_dffr;
    assign o_counter = r_counter;

endmodule

`default_nettype wire
