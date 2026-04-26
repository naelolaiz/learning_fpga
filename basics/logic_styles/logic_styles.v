// Verilog mirror of logic_styles.vhd. See that file for the full
// "when to use combinational vs. sequential vs. latch + which init
// strategy is portable" commentary; this file just shows the same
// constructs in Verilog syntax. The companion project
// `basics/glossary` is the gallery of bare gate primitives; this
// project is the coding-style layer above those cells.

`default_nettype none

module logic_styles (
    input  wire a,
    input  wire b,
    input  wire clk,
    input  wire rst,    // active-high synchronous reset (for seq_sync_reset_a)
    input  wire en,     // transparent-latch enable (for latch_intentional_a)

    // COMBINATIONAL: two equivalent good forms.
    output wire comb_op_and,
    output reg  comb_proc_good_and,

    // COMBINATIONAL, WRONG: incomplete `if` -> synthesizer infers a latch.
    output reg  comb_proc_latch_and,

    // SEQUENTIAL: three init strategies side-by-side.
    output reg  seq_no_init_a,
    output reg  seq_decl_init_a,
    output reg  seq_sync_reset_a,

    // LATCH (intentional, level-sensitive).
    output reg  latch_intentional_a
);

    // --------------- COMBINATIONAL (operator) ----------------------
    assign comb_op_and = a & b;

    // --------------- COMBINATIONAL (always @*, GOOD) ---------------
    always @(*) begin
        if (a == 1'b1 && b == 1'b1) comb_proc_good_and = 1'b1;
        else                        comb_proc_good_and = 1'b0;
    end

    // --------------- COMBINATIONAL (always @*, BAD: LATCH) ---------
    // The `if` has no `else` -> synthesizer infers a latch.
    // DO NOT write your combinational logic this way.
    always @(*) begin
        if (a) comb_proc_latch_and = b;
        // missing `else` is the bug being demonstrated
    end

    // --------------- SEQUENTIAL: no init, no reset -----------------
    // No `reg ... = 1'b0;` initializer and no reset branch. In
    // simulation `seq_no_init_a` is `1'bx` until the first rising
    // edge samples a defined `a` into it. On Cyclone IV the
    // bitstream loads FFs to `1'b0` at power-up by default — i.e.
    // hardware happens to behave better than sim here, hiding the
    // bug. Don't rely on it.
    always @(posedge clk) begin
        seq_no_init_a <= a;
    end

    // --------------- SEQUENTIAL: declaration init ------------------
    // The `reg ... = 1'b1;` initializer (Verilog 2001+ syntax) gives
    // the simulator a known starting value AND, on Cyclone IV, bakes
    // that value into the FF's power-up state in the bitstream.
    // Convenient; not portable across FPGA families, never portable
    // to ASIC.
    initial seq_decl_init_a = 1'b1;
    always @(posedge clk) begin
        seq_decl_init_a <= a;
    end

    // --------------- SEQUENTIAL: explicit synchronous reset --------
    // Portable across every FPGA and ASIC target, and re-armable at
    // runtime. Use this whenever the consumer needs to clear the
    // register on demand (counters, FSMs, FIFOs).
    always @(posedge clk) begin
        if (rst) seq_sync_reset_a <= 1'b1;
        else     seq_sync_reset_a <= a;
    end

    // --------------- LATCH (intentional, level-sensitive) ---------
    always @(*) begin
        if (en) latch_intentional_a = a;
        // No `else`: this IS the latch.
    end

endmodule

`default_nettype wire
