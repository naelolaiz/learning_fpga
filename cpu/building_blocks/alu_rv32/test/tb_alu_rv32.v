// tb_alu_rv32.v - Verilog mirror of tb_alu_rv32.vhd.
//
// Same scenarios, same boundary cases. The `check` task wraps op +
// operands + expected so each scenario reads as one line.

`timescale 1ns/1ps

module tb_alu_rv32;

    reg  [31:0] sA  = 32'd0;
    reg  [31:0] sB  = 32'd0;
    reg  [3:0]  sOp = 4'd0;
    wire [31:0] sR;
    wire        sZero;

    alu_rv32 dut (
        .a      (sA),
        .b      (sB),
        .op     (sOp),
        .result (sR),
        .zero   (sZero)
    );

    initial begin
        $dumpfile(`FST_OUT);
        $dumpvars(1, tb_alu_rv32);
        $dumpvars(1, dut);
    end

    task check (
        input [31:0] av,
        input [31:0] bv,
        input [3:0]  opv,
        input [31:0] exp,
        input [127:0] tag
    );
        begin
            sA  = av;
            sB  = bv;
            sOp = opv;
            #1;
            if (sR !== exp)
                $fatal(1, "%0s: expected %h, got %h", tag, exp, sR);
        end
    endtask

    initial begin : driver
        // ADD
        check(32'h00000001, 32'h00000002, 4'b0000, 32'h00000003, "ADD basic");
        check(32'hFFFFFFFF, 32'h00000001, 4'b0000, 32'h00000000, "ADD wrap");
        if (sZero !== 1'b1) $fatal(1, "zero flag should fire on ADD wrap to 0");

        // SUB
        check(32'h00000005, 32'h00000003, 4'b0001, 32'h00000002, "SUB basic");
        check(32'h00000000, 32'h00000001, 4'b0001, 32'hFFFFFFFF, "SUB negative wrap");

        // AND/OR/XOR
        check(32'hAAAAAAAA, 32'h55555555, 4'b0010, 32'h00000000, "AND alt bits");
        check(32'hAAAAAAAA, 32'h55555555, 4'b0011, 32'hFFFFFFFF, "OR  alt bits");
        check(32'hFFFFFFFF, 32'h0F0F0F0F, 4'b0100, 32'hF0F0F0F0, "XOR pattern");

        // SLL
        check(32'hDEADBEEF, 32'h00000000, 4'b0101, 32'hDEADBEEF, "SLL by 0");
        check(32'h00000001, 32'h0000001F, 4'b0101, 32'h80000000, "SLL by 31");

        // SRL / SRA
        check(32'hFFFFFFFF, 32'h0000001F, 4'b0110, 32'h00000001, "SRL by 31 logical");
        check(32'hFFFFFFFF, 32'h0000001F, 4'b0111, 32'hFFFFFFFF, "SRA by 31 sign-fill");
        check(32'hFFFFFFF8, 32'h00000001, 4'b0111, 32'hFFFFFFFC, "SRA -8 by 1");

        // SLT / SLTU
        check(32'hFFFFFFFF, 32'h00000001, 4'b1000, 32'h00000001, "SLT  -1 < 1");
        check(32'h00000001, 32'hFFFFFFFF, 4'b1000, 32'h00000000, "SLT   1 < -1 false");
        check(32'h00000001, 32'hFFFFFFFF, 4'b1001, 32'h00000001, "SLTU  1 < big");
        check(32'hFFFFFFFF, 32'h00000001, 4'b1001, 32'h00000000, "SLTU  big < 1 false");

        // Illegal op
        check(32'hDEADBEEF, 32'hCAFEBABE, 4'b1111, 32'h00000000, "Illegal -> 0");
        if (sZero !== 1'b1) $fatal(1, "zero flag should fire on illegal-op zero result");

        $display("alu_rv32 simulation done!");
        $finish;
    end

endmodule
