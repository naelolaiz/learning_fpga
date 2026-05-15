// Verilog mirror of glossary.vhd — same port shape, same behaviour.
// Read alongside build/glossary_v.svg to map each netlistsvg shape to
// its cell.
//
// The intentional D-latch and the small inline RAM both expand the
// glossary beyond yosys's "easy" primitives:
//   * the latch needs `GHDL_SYNTH_EXTRA := --latches` in the Makefile
//     (only affects the VHDL flow; iverilog/yosys-Verilog accept
//     latches by default but route them through the same $dlatch
//     cell type);
//   * the RAM is a small 8 × 1-bit single-port synchronous memory —
//     enough for yosys to lift to a `$mem_v2` cell rather than
//     flatten to flip-flops.

`default_nettype none

module glossary (
    input  wire        a,
    input  wire        b,
    input  wire        sel,
    input  wire [1:0]  sel4,
    input  wire [3:0]  av,
    input  wire [3:0]  bv,
    input  wire [3:0]  sel4_oh,
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
    output wire        o_reduce_bool,

    output wire        o_logic_not,
    output wire        o_logic_and,
    output wire        o_logic_or,

    output wire        o_mux2,
    output wire        o_mux4,
    output reg         o_pmux = 1'b0,

    output wire [3:0]  o_add,
    output wire [3:0]  o_sub,
    output wire [7:0]  o_mul,
    output wire [3:0]  o_neg,
    output wire [3:0]  o_pos,

    output wire        o_eq,
    output wire        o_ne,
    output wire        o_lt,
    output wire        o_gt,
    output wire        o_ge,
    output wire        o_le,

    output wire [3:0]  o_shl,
    output wire [3:0]  o_shr,
    output wire [3:0]  o_sshr,
    output wire [3:0]  o_shift,

    output wire        o_dff,
    output wire        o_dffe,
    output wire        o_dffr,
    output reg         o_dlatch = 1'b0,
    output wire [3:0]  o_counter,

    output wire        o_mem
);

    assign o_and  =  (a & b);
    assign o_or   =  (a | b);
    assign o_not  =  ~a;
    assign o_xor  =  (a ^ b);
    assign o_nand = ~(a & b);
    assign o_nor  = ~(a | b);
    assign o_xnor = ~(a ^ b);

    assign o_reduce_or   = | av;
    assign o_reduce_and  = & av;
    assign o_reduce_xor  = ^ av;
    assign o_reduce_bool = (av != 4'd0);

    assign o_logic_not = !av;
    assign o_logic_and = av && bv;
    assign o_logic_or  = av || bv;

    assign o_mux2 = sel ? a : b;
    assign o_mux4 = (sel4 == 2'b00) ? av[0] :
                    (sel4 == 2'b01) ? av[1] :
                    (sel4 == 2'b10) ? av[2] :
                                      av[3];

    // Parallel mux on a one-hot select. yosys recognises the per-bit
    // case statement as $pmux rather than a chain of $mux.
    always @* begin
        case (sel4_oh)
            4'b0001: o_pmux = av[0];
            4'b0010: o_pmux = av[1];
            4'b0100: o_pmux = av[2];
            4'b1000: o_pmux = av[3];
            default: o_pmux = 1'b0;
        endcase
    end

    assign o_add = av + bv;
    assign o_sub = av - bv;
    assign o_mul = av * bv;
    assign o_neg = -$signed({1'b0, av});
    assign o_pos = av;

    assign o_eq = (av == bv);
    assign o_ne = (av != bv);
    assign o_lt = (av <  bv);
    assign o_gt = (av >  bv);
    assign o_ge = (av >= bv);
    assign o_le = (av <= bv);

    assign o_shl   = av << 1;
    assign o_shr   = av >> 1;
    assign o_sshr  = $signed(av) >>> 1;
    assign o_shift = av << bv[1:0];

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

    // Intentional D-latch. The always block is sensitive to en and a;
    // when en is low, the missing else means the synthesiser must hold
    // the last value — that's a level-sensitive latch.
    always @* begin
        if (en) o_dlatch = a;
    end

    always @(posedge clk)
        if (rst) r_counter <= 4'd0;
        else     r_counter <= r_counter + 4'd1;

    assign o_dff     = r_dff;
    assign o_dffe    = r_dffe;
    assign o_dffr    = r_dffr;
    assign o_counter = r_counter;

    // 8 × 1-bit single-port synchronous RAM. Same shape as the VHDL
    // twin. Address = {sel, sel4}, data-in = a, we = en. yosys lifts
    // to $mem_v2. Both the array and the read-data register are
    // explicitly initialised so the testbench waveform doesn't show
    // an X-band on `o_mem` / `mem_dout` before the first write — the
    // VHDL twin already initialises its `mem_arr` / `mem_dout` to
    // '0', and this matches that.
    reg [0:0] mem  [0:7];
    reg       mem_dout = 1'b0;
    wire [2:0] mem_addr = {sel, sel4};

    integer mem_i;
    initial for (mem_i = 0; mem_i < 8; mem_i = mem_i + 1) mem[mem_i] = 1'b0;

    always @(posedge clk) begin
        if (en) mem[mem_addr] <= a;
        mem_dout <= mem[mem_addr];
    end

    assign o_mem = mem_dout;

endmodule

`default_nettype wire
