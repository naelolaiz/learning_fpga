// Verilog testbench mirror of tb_glossary.vhd.
//
// Same stimulus, same checks, same s-prefixed signal names so the two
// waveforms render identically in the gallery.

`timescale 1ns/1ps

module tb_glossary;

    reg        sClock  = 1'b0;
    reg        sA      = 1'b0;
    reg        sB      = 1'b0;
    reg        sSel    = 1'b0;
    reg [1:0]  sSel4   = 2'b00;
    reg [3:0]  sSel4Oh = 4'b0000;
    reg [3:0]  sAv     = 4'b0000;
    reg [3:0]  sBv     = 4'b0000;
    reg        sRst    = 1'b0;
    reg        sEn     = 1'b0;

    wire       o_and, o_or, o_not, o_xor;
    wire       o_nand, o_nor, o_xnor;
    wire       o_reduce_or, o_reduce_and, o_reduce_xor, o_reduce_bool;
    wire       o_logic_not, o_logic_and, o_logic_or;
    wire       o_mux2, o_mux4, o_pmux;
    wire [3:0] o_add, o_sub, o_neg, o_pos;
    wire [7:0] o_mul;
    wire       o_eq, o_ne, o_lt, o_gt, o_ge, o_le;
    wire [3:0] o_shl, o_shr, o_sshr, o_shift;
    wire       o_dff, o_dffe, o_dffr, o_dlatch;
    wire [3:0] o_counter;
    wire       o_mem;

    reg sSimulationActive = 1'b1;

    glossary dut (
        .a(sA), .b(sB), .sel(sSel), .sel4(sSel4), .sel4_oh(sSel4Oh),
        .av(sAv), .bv(sBv),
        .clk(sClock), .rst(sRst), .en(sEn),
        .o_and(o_and),   .o_or(o_or),   .o_not(o_not),   .o_xor(o_xor),
        .o_nand(o_nand), .o_nor(o_nor), .o_xnor(o_xnor),
        .o_reduce_or  (o_reduce_or),
        .o_reduce_and (o_reduce_and),
        .o_reduce_xor (o_reduce_xor),
        .o_reduce_bool(o_reduce_bool),
        .o_logic_not  (o_logic_not),
        .o_logic_and  (o_logic_and),
        .o_logic_or   (o_logic_or),
        .o_mux2(o_mux2), .o_mux4(o_mux4), .o_pmux(o_pmux),
        .o_add(o_add), .o_sub(o_sub), .o_mul(o_mul),
        .o_neg(o_neg), .o_pos(o_pos),
        .o_eq(o_eq), .o_ne(o_ne), .o_lt(o_lt),
        .o_gt(o_gt), .o_ge(o_ge), .o_le(o_le),
        .o_shl(o_shl), .o_shr(o_shr), .o_sshr(o_sshr), .o_shift(o_shift),
        .o_dff(o_dff), .o_dffe(o_dffe), .o_dffr(o_dffr),
        .o_dlatch(o_dlatch), .o_counter(o_counter),
        .o_mem(o_mem)
    );

    // 50 MHz clock — gated by sSimulationActive to mirror the VHDL TB.
    always #10 if (sSimulationActive) sClock = ~sClock;

    initial begin
        $dumpfile(`FST_OUT);
        $dumpvars(1, tb_glossary);
        $dumpvars(1, dut);
    end

    initial begin : driver
        sA = 1'b1; sB = 1'b0; sSel = 1'b1;
        sSel4   = 2'b10;
        sSel4Oh = 4'b0100;
        sAv = 4'b1100; sBv = 4'b0011;
        #1;

        if (o_and  !== (sA & sB))  $fatal(1, "o_and");
        if (o_or   !== (sA | sB))  $fatal(1, "o_or");
        if (o_not  !== ~sA)        $fatal(1, "o_not");
        if (o_xor  !== (sA ^ sB))  $fatal(1, "o_xor");
        if (o_nand !== ~(sA & sB)) $fatal(1, "o_nand");
        if (o_nor  !== ~(sA | sB)) $fatal(1, "o_nor");
        if (o_xnor !== ~(sA ^ sB)) $fatal(1, "o_xnor");

        if (o_reduce_or   !== 1'b1) $fatal(1, "o_reduce_or");
        if (o_reduce_and  !== 1'b0) $fatal(1, "o_reduce_and");
        if (o_reduce_xor  !== 1'b0) $fatal(1, "o_reduce_xor");
        if (o_reduce_bool !== 1'b1) $fatal(1, "o_reduce_bool");

        if (o_logic_not !== 1'b0) $fatal(1, "o_logic_not (av != 0)");
        if (o_logic_and !== 1'b1) $fatal(1, "o_logic_and (both nz)");
        if (o_logic_or  !== 1'b1) $fatal(1, "o_logic_or (any nz)");

        if (o_mux2 !== sA)        $fatal(1, "o_mux2 (sel=1 -> a)");
        if (o_mux4 !== sAv[2])    $fatal(1, "o_mux4 (sel4=10 -> av[2])");
        if (o_pmux !== sAv[2])    $fatal(1, "o_pmux (sel4_oh=0100 -> av[2])");

        if (o_add !== 4'b1111)    $fatal(1, "o_add (12+3=15)");
        if (o_sub !== 4'b1001)    $fatal(1, "o_sub (12-3=9)");
        if (o_mul !== 8'h24)      $fatal(1, "o_mul (12*3=36)");
        if (o_neg !== 4'b0100)    $fatal(1, "o_neg (-12 mod 16 = 4)");
        if (o_pos !== sAv)        $fatal(1, "o_pos (+av identity)");

        if (o_eq !== 1'b0) $fatal(1, "o_eq");
        if (o_ne !== 1'b1) $fatal(1, "o_ne");
        if (o_lt !== 1'b0) $fatal(1, "o_lt (12<3 false)");
        if (o_gt !== 1'b1) $fatal(1, "o_gt (12>3)");
        if (o_ge !== 1'b1) $fatal(1, "o_ge (12>=3)");
        if (o_le !== 1'b0) $fatal(1, "o_le (12<=3 false)");

        if (o_shl   !== 4'b1000) $fatal(1, "o_shl (1100<<1)");
        if (o_shr   !== 4'b0110) $fatal(1, "o_shr (1100>>1)");
        if (o_sshr  !== 4'b1110) $fatal(1, "o_sshr (signed 1100>>>1)");
        if (o_shift !== 4'b0000) $fatal(1, "o_shift (1100<<3)");

        // D-latch transparency
        sEn = 1'b1; sA = 1'b1;
        #1;
        if (o_dlatch !== 1'b1) $fatal(1, "o_dlatch transparent on en=1");
        sEn = 1'b0; sA = 1'b0;
        #1;
        if (o_dlatch !== 1'b1) $fatal(1, "o_dlatch must hold when en=0");

        // Sequential block
        sA = 1'b1; sRst = 1'b0; sEn = 1'b1;
        @(posedge sClock); #1;
        if (o_dff     !== 1'b1)    $fatal(1, "o_dff after first edge");
        if (o_dffe    !== 1'b1)    $fatal(1, "o_dffe after first edge with en=1");
        if (o_dffr    !== 1'b1)    $fatal(1, "o_dffr after first edge no rst");
        if (o_counter !== 4'b0001) $fatal(1, "o_counter after first edge");

        sA = 1'b0; sEn = 1'b0;
        @(posedge sClock); #1;
        if (o_dff     !== 1'b0)    $fatal(1, "o_dff after second edge (a=0)");
        if (o_dffe    !== 1'b1)    $fatal(1, "o_dffe must hold when en=0");
        if (o_dffr    !== 1'b0)    $fatal(1, "o_dffr after second edge (a=0)");
        if (o_counter !== 4'b0010) $fatal(1, "o_counter after second edge");

        sRst = 1'b1;
        @(posedge sClock); #1;
        if (o_dffr    !== 1'b0)    $fatal(1, "o_dffr after rst");
        if (o_counter !== 4'b0000) $fatal(1, "o_counter after rst");

        $display("Simulation done!");
        sSimulationActive = 1'b0;
        $finish;
    end

endmodule
