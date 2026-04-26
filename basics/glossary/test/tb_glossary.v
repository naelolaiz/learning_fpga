// Verilog testbench mirror of tb_glossary.vhd.
//
// Same stimulus, same checks, same s-prefixed signal names so the two
// waveforms render identically in the gallery.

`timescale 1ns/1ps

module tb_glossary;

    reg        sClock = 1'b0;
    reg        sA     = 1'b0;
    reg        sB     = 1'b0;
    reg        sSel   = 1'b0;
    reg [1:0]  sSel4  = 2'b00;
    reg [3:0]  sAv    = 4'b0000;
    reg [3:0]  sBv    = 4'b0000;
    reg        sRst   = 1'b0;
    reg        sEn    = 1'b0;

    wire       o_and, o_or, o_not, o_xor;
    wire       o_nand, o_nor, o_xnor;
    wire       o_reduce_or, o_reduce_and, o_reduce_xor;
    wire       o_mux2, o_mux4;
    wire [3:0] o_add, o_sub, o_shl, o_shr;
    wire       o_eq, o_lt;
    wire       o_dff, o_dffe, o_dffr;
    wire [3:0] o_counter;

    reg sSimulationActive = 1'b1;

    glossary dut (
        .a(sA), .b(sB), .sel(sSel), .sel4(sSel4),
        .av(sAv), .bv(sBv),
        .clk(sClock), .rst(sRst), .en(sEn),
        .o_and(o_and), .o_or(o_or), .o_not(o_not), .o_xor(o_xor),
        .o_nand(o_nand), .o_nor(o_nor), .o_xnor(o_xnor),
        .o_reduce_or(o_reduce_or),
        .o_reduce_and(o_reduce_and),
        .o_reduce_xor(o_reduce_xor),
        .o_mux2(o_mux2), .o_mux4(o_mux4),
        .o_add(o_add), .o_sub(o_sub),
        .o_eq(o_eq), .o_lt(o_lt),
        .o_shl(o_shl), .o_shr(o_shr),
        .o_dff(o_dff), .o_dffe(o_dffe), .o_dffr(o_dffr),
        .o_counter(o_counter)
    );

    // 50 MHz clock — gated by sSimulationActive to mirror the VHDL TB.
    always #10 if (sSimulationActive) sClock = ~sClock;

    initial begin
        $dumpfile(`VCD_OUT);
        $dumpvars(1, tb_glossary);
        $dumpvars(1, dut);
    end

    initial begin : driver
        sA = 1'b1; sB = 1'b0; sSel = 1'b1;
        sSel4 = 2'b10;
        sAv = 4'b1100; sBv = 4'b0011;
        #1;

        if (o_and  !== (sA & sB))  $fatal(1, "o_and");
        if (o_or   !== (sA | sB))  $fatal(1, "o_or");
        if (o_not  !== ~sA)        $fatal(1, "o_not");
        if (o_xor  !== (sA ^ sB))  $fatal(1, "o_xor");
        if (o_nand !== ~(sA & sB)) $fatal(1, "o_nand");
        if (o_nor  !== ~(sA | sB)) $fatal(1, "o_nor");
        if (o_xnor !== ~(sA ^ sB)) $fatal(1, "o_xnor");

        if (o_reduce_or  !== 1'b1) $fatal(1, "o_reduce_or");
        if (o_reduce_and !== 1'b0) $fatal(1, "o_reduce_and");
        if (o_reduce_xor !== 1'b0) $fatal(1, "o_reduce_xor");

        if (o_mux2 !== sA)         $fatal(1, "o_mux2 (sel=1 -> a)");
        if (o_mux4 !== sAv[2])     $fatal(1, "o_mux4 (sel4=10 -> av[2])");

        if (o_add !== 4'b1111)     $fatal(1, "o_add (12+3=15)");
        if (o_sub !== 4'b1001)     $fatal(1, "o_sub (12-3=9)");
        if (o_eq  !== 1'b0)        $fatal(1, "o_eq");
        if (o_lt  !== 1'b0)        $fatal(1, "o_lt (12<3 false)");
        if (o_shl !== 4'b1000)     $fatal(1, "o_shl (1100<<1)");
        if (o_shr !== 4'b0110)     $fatal(1, "o_shr (1100>>1)");

        sRst = 1'b0; sEn = 1'b1;
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
