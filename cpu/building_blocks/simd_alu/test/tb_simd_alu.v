// tb_simd_alu.v - Verilog mirror of tb_simd_alu.vhd.
// Same golden vectors, same expected results, same lane-boundary
// saturation cases.

`timescale 1ns/1ps
`default_nettype none

module tb_simd_alu;

    reg  [31:0] a = 32'b0;
    reg  [31:0] b = 32'b0;
    reg  [3:0]  op = 4'b0;
    wire [31:0] result;
    wire [3:0]  flags;

    simd_alu dut (.a(a), .b(b), .op(op), .result(result), .flags(flags));

    initial begin
        $dumpfile(`FST_OUT);
        // Selective dump: testbench top + everything under dut, but
        // skip task locals (`check.tag/.exp_f/.exp_r`) which are
        // X-initialised until the first task call and would paint
        // visible red bands in the rendered waveform.
        $dumpvars(1, tb_simd_alu);
        $dumpvars(0, dut);
    end

    integer errors = 0;

    task check;
        input [255:0] tag;
        input [31:0]  exp_r;
        input [3:0]   exp_f;
        begin
            if (result !== exp_r) begin
                $display("%0s: result expected %h got %h", tag, exp_r, result);
                errors = errors + 1;
            end
            if (flags !== exp_f) begin
                $display("%0s: flags expected %b got %b", tag, exp_f, flags);
                errors = errors + 1;
            end
        end
    endtask

    initial begin

        // ====== 4 × 8-bit lanes ======

        // ADD wrap
        a = 32'h04030201; b = 32'h40302010; op = 4'b0000;
        #1; check("4x8 add wrap",  32'h44332211, 4'b0000);

        // ADD sat
        a = 32'hF010807F; b = 32'h10F08001; op = 4'b0001;
        #1; check("4x8 add sat",   32'h0000807F, 4'b0011);

        // SUB wrap
        a = 32'h40302010; b = 32'h05050505; op = 4'b0010;
        #1; check("4x8 sub wrap",  32'h3B2B1B0B, 4'b0000);

        // SUB sat
        a = 32'hFF007F80; b = 32'h8080FF01; op = 4'b0011;
        #1; check("4x8 sub sat",   32'h7F7F7F80, 4'b0111);

        // MIN: a={-1, 5, 10, -100} vs b={2, 3, 10, 50} → {-1, 3, 10, -100}
        a = 32'h9C0A05FF; b = 32'h320A0302; op = 4'b0100;
        #1; check("4x8 min",       32'h9C0A03FF, 4'b0000);

        // MAX
        a = 32'h9C0A05FF; b = 32'h320A0302; op = 4'b0110;
        #1; check("4x8 max",       32'h320A0502, 4'b0000);

        // ====== 2 × 16-bit lanes ======

        a = 32'h56781234; b = 32'h20001000; op = 4'b1000;
        #1; check("2x16 add wrap", 32'h76782234, 4'b0000);

        a = 32'h80007FFF; b = 32'h80000001; op = 4'b1001;
        #1; check("2x16 add sat",  32'h80007FFF, 4'b0011);

        a = 32'h00200010; b = 32'h00050005; op = 4'b1010;
        #1; check("2x16 sub wrap", 32'h001B000B, 4'b0000);

        a = 32'h7FFF8000; b = 32'hFFFF0001; op = 4'b1011;
        #1; check("2x16 sub sat",  32'h7FFF8000, 4'b0011);

        a = 32'h0005FFFF; b = 32'hFFFE0001; op = 4'b1100;
        #1; check("2x16 min",      32'hFFFEFFFF, 4'b0000);

        a = 32'h0005FFFF; b = 32'hFFFE0001; op = 4'b1110;
        #1; check("2x16 max",      32'h00050001, 4'b0000);

        if (errors != 0) $fatal(1, "tb_simd_alu: %0d errors", errors);
        $display("tb_simd_alu: all cases passed");
        $finish;
    end

endmodule

`default_nettype wire
