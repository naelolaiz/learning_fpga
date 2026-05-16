// tb_immgen_rv32.v - Verilog mirror of tb_immgen_rv32.vhd.
//
// Same hand-encoded RV32I instructions, same expected immediates.

`timescale 1ns/1ps

module tb_immgen_rv32;

    reg  [31:0] sInstr = 32'h0;
    reg  [2:0]  sFmt   = 3'b000;
    wire [31:0] sImm;

    immgen_rv32 dut (
        .instr (sInstr),
        .fmt   (sFmt),
        .imm   (sImm)
    );

    initial begin
        $dumpfile(`FST_OUT);
        $dumpvars(1, tb_immgen_rv32);
        $dumpvars(1, dut);
    end

    task check (
        input [31:0] instr_v,
        input [2:0]  fmt_v,
        input [31:0] exp,
        input [255:0] tag
    );
        begin
            sInstr = instr_v;
            sFmt   = fmt_v;
            #1;
            if (sImm !== exp)
                $fatal(1, "%0s: instr=%h fmt=%b expected %h, got %h",
                       tag, instr_v, fmt_v, exp, sImm);
        end
    endtask

    initial begin : driver
        // I-type
        check(32'hFFF00093, 3'b000, 32'hFFFFFFFF, "ADDI x1,x0,-1");
        check(32'h7FF00093, 3'b000, 32'h000007FF, "ADDI x1,x0,+0x7FF");
        check(32'h80000093, 3'b000, 32'hFFFFF800, "ADDI x1,x0,-0x800");

        // S-type
        check(32'h0051A823, 3'b001, 32'h00000010, "SW x5,16(x3)");
        check(32'hFE51AFA3, 3'b001, 32'hFFFFFFFF, "SW x5,-1(x3)");

        // B-type
        check(32'h00208663, 3'b010, 32'h0000000C, "BEQ x1,x2,+12");
        check(32'hFE208EE3, 3'b010, 32'hFFFFFFFC, "BEQ x1,x2,-4");

        // U-type
        check(32'h12345237, 3'b011, 32'h12345000, "LUI x4,0x12345");
        check(32'hFFFFF237, 3'b011, 32'hFFFFF000, "LUI x4,0xFFFFF");

        // J-type
        check(32'h008000EF, 3'b100, 32'h00000008, "JAL x1,+8");
        check(32'hFF9FF0EF, 3'b100, 32'hFFFFFFF8, "JAL x1,-8");

        // Illegal fmt
        check(32'hDEADBEEF, 3'b111, 32'h00000000, "Illegal fmt");

        $display("immgen_rv32 simulation done!");
        $finish;
    end

endmodule
