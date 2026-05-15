// tb_decoder_rv32.v - Verilog mirror of tb_decoder_rv32.vhd.
//
// Same instruction encodings, same expected control vectors. Each
// scenario is one task call; on a mismatch the failing field is
// printed via $fatal so a regression is easy to localise.

`timescale 1ns/1ps

module tb_decoder_rv32;

    // Constants matching decoder_rv32.v
    localparam [2:0] FMT_I    = 3'b000;
    localparam [2:0] FMT_S    = 3'b001;
    localparam [2:0] FMT_B    = 3'b010;
    localparam [2:0] FMT_U    = 3'b011;
    localparam [2:0] FMT_J    = 3'b100;
    localparam [3:0] ALU_ADD  = 4'b0000;
    localparam [3:0] ALU_SUB  = 4'b0001;
    localparam [3:0] ALU_AND  = 4'b0010;
    localparam [3:0] ALU_OR   = 4'b0011;
    localparam [3:0] ALU_XOR  = 4'b0100;
    localparam [3:0] ALU_SLL  = 4'b0101;
    localparam [3:0] ALU_SRL  = 4'b0110;
    localparam [3:0] ALU_SRA  = 4'b0111;
    localparam [3:0] ALU_SLT  = 4'b1000;
    localparam [3:0] ALU_SLTU = 4'b1001;

    reg  [31:0] sInstr = 32'h0;
    wire [4:0]  sRs1, sRs2, sRd;
    wire [2:0]  sFmt;
    wire [3:0]  sAluOp;
    wire        sSrcA, sSrcB;
    wire        sMemR, sMemW;
    wire        sRegW;
    wire [1:0]  sWbSrc;
    wire        sBr, sJal, sJalr, sIll;

    decoder_rv32 dut (
        .instr     (sInstr),
        .rs1       (sRs1),  .rs2       (sRs2),  .rd       (sRd),
        .imm_fmt   (sFmt),
        .alu_op    (sAluOp),
        .alu_src_a (sSrcA), .alu_src_b (sSrcB),
        .mem_read  (sMemR), .mem_write (sMemW),
        .reg_write (sRegW),
        .wb_src    (sWbSrc),
        .is_branch (sBr),   .is_jal    (sJal), .is_jalr (sJalr),
        .illegal   (sIll)
    );

    initial begin
        $dumpfile(`FST_OUT);
        $dumpvars(1, tb_decoder_rv32);
        $dumpvars(1, dut);
    end

    task check (
        input [31:0]  instr_v,
        input [4:0]   x_rs1,
        input [4:0]   x_rs2,
        input [4:0]   x_rd,
        input [2:0]   x_fmt,
        input [3:0]   x_alu,
        input         x_srcA,
        input         x_srcB,
        input         x_memR,
        input         x_memW,
        input         x_regW,
        input [1:0]   x_wb,
        input         x_br,
        input         x_jal,
        input         x_jalr,
        input         x_ill,
        input [255:0] tag
    );
        begin
            sInstr = instr_v;
            #1;
            if (sRs1   !== x_rs1)  $fatal(1, "%0s rs1   mismatch: got %b, exp %b", tag, sRs1,   x_rs1);
            if (sRs2   !== x_rs2)  $fatal(1, "%0s rs2   mismatch: got %b, exp %b", tag, sRs2,   x_rs2);
            if (sRd    !== x_rd)   $fatal(1, "%0s rd    mismatch: got %b, exp %b", tag, sRd,    x_rd);
            if (sFmt   !== x_fmt)  $fatal(1, "%0s fmt   mismatch: got %b, exp %b", tag, sFmt,   x_fmt);
            if (sAluOp !== x_alu)  $fatal(1, "%0s alu   mismatch: got %b, exp %b", tag, sAluOp, x_alu);
            if (sSrcA  !== x_srcA) $fatal(1, "%0s srcA  mismatch: got %b, exp %b", tag, sSrcA,  x_srcA);
            if (sSrcB  !== x_srcB) $fatal(1, "%0s srcB  mismatch: got %b, exp %b", tag, sSrcB,  x_srcB);
            if (sMemR  !== x_memR) $fatal(1, "%0s memR  mismatch: got %b, exp %b", tag, sMemR,  x_memR);
            if (sMemW  !== x_memW) $fatal(1, "%0s memW  mismatch: got %b, exp %b", tag, sMemW,  x_memW);
            if (sRegW  !== x_regW) $fatal(1, "%0s regW  mismatch: got %b, exp %b", tag, sRegW,  x_regW);
            if (sWbSrc !== x_wb)   $fatal(1, "%0s wbSrc mismatch: got %b, exp %b", tag, sWbSrc, x_wb);
            if (sBr    !== x_br)   $fatal(1, "%0s br    mismatch: got %b, exp %b", tag, sBr,    x_br);
            if (sJal   !== x_jal)  $fatal(1, "%0s jal   mismatch: got %b, exp %b", tag, sJal,   x_jal);
            if (sJalr  !== x_jalr) $fatal(1, "%0s jalr  mismatch: got %b, exp %b", tag, sJalr,  x_jalr);
            if (sIll   !== x_ill)  $fatal(1, "%0s ill   mismatch: got %b, exp %b", tag, sIll,   x_ill);
        end
    endtask

    initial begin : driver
        // R-type ALU
        check(32'h002081B3, 5'd1,  5'd2,  5'd3,  FMT_I, ALU_ADD,  1'b0, 1'b0, 1'b0, 1'b0, 1'b1, 2'b00, 1'b0, 1'b0, 1'b0, 1'b0, "ADD x3,x1,x2");
        check(32'h402081B3, 5'd1,  5'd2,  5'd3,  FMT_I, ALU_SUB,  1'b0, 1'b0, 1'b0, 1'b0, 1'b1, 2'b00, 1'b0, 1'b0, 1'b0, 1'b0, "SUB x3,x1,x2");
        check(32'h0020F1B3, 5'd1,  5'd2,  5'd3,  FMT_I, ALU_AND,  1'b0, 1'b0, 1'b0, 1'b0, 1'b1, 2'b00, 1'b0, 1'b0, 1'b0, 1'b0, "AND x3,x1,x2");
        check(32'h4020D1B3, 5'd1,  5'd2,  5'd3,  FMT_I, ALU_SRA,  1'b0, 1'b0, 1'b0, 1'b0, 1'b1, 2'b00, 1'b0, 1'b0, 1'b0, 1'b0, "SRA x3,x1,x2");
        check(32'h0020D1B3, 5'd1,  5'd2,  5'd3,  FMT_I, ALU_SRL,  1'b0, 1'b0, 1'b0, 1'b0, 1'b1, 2'b00, 1'b0, 1'b0, 1'b0, 1'b0, "SRL x3,x1,x2");
        check(32'h0020A1B3, 5'd1,  5'd2,  5'd3,  FMT_I, ALU_SLT,  1'b0, 1'b0, 1'b0, 1'b0, 1'b1, 2'b00, 1'b0, 1'b0, 1'b0, 1'b0, "SLT x3,x1,x2");

        // I-type ALU
        // ADDI's instr[24:20] = 4 here (imm[4:0]) — extracted raw.
        check(32'h06408193, 5'd1,  5'd4,  5'd3,  FMT_I, ALU_ADD,  1'b0, 1'b1, 1'b0, 1'b0, 1'b1, 2'b00, 1'b0, 1'b0, 1'b0, 1'b0, "ADDI x3,x1,100");
        check(32'h4050D193, 5'd1,  5'd5,  5'd3,  FMT_I, ALU_SRA,  1'b0, 1'b1, 1'b0, 1'b0, 1'b1, 2'b00, 1'b0, 1'b0, 1'b0, 1'b0, "SRAI x3,x1,5");
        check(32'h0050D193, 5'd1,  5'd5,  5'd3,  FMT_I, ALU_SRL,  1'b0, 1'b1, 1'b0, 1'b0, 1'b1, 2'b00, 1'b0, 1'b0, 1'b0, 1'b0, "SRLI x3,x1,5");

        // LOAD
        check(32'h0000A183, 5'd1,  5'd0,  5'd3,  FMT_I, ALU_ADD,  1'b0, 1'b1, 1'b1, 1'b0, 1'b1, 2'b01, 1'b0, 1'b0, 1'b0, 1'b0, "LW x3,0(x1)");
        check(32'h00008183, 5'd1,  5'd0,  5'd3,  FMT_I, ALU_ADD,  1'b0, 1'b1, 1'b1, 1'b0, 1'b1, 2'b01, 1'b0, 1'b0, 1'b0, 1'b1, "LB x3,0(x1) (illegal)");

        // STORE
        check(32'h0020A223, 5'd1,  5'd2,  5'd4,  FMT_S, ALU_ADD,  1'b0, 1'b1, 1'b0, 1'b1, 1'b0, 2'b00, 1'b0, 1'b0, 1'b0, 1'b0, "SW x2,4(x1)");
        check(32'h00209223, 5'd1,  5'd2,  5'd4,  FMT_S, ALU_ADD,  1'b0, 1'b1, 1'b0, 1'b1, 1'b0, 2'b00, 1'b0, 1'b0, 1'b0, 1'b1, "SH x2,4(x1) (illegal)");

        // BRANCH
        check(32'h00208663, 5'd1,  5'd2,  5'd12, FMT_B, ALU_ADD,  1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 2'b00, 1'b1, 1'b0, 1'b0, 1'b0, "BEQ x1,x2,+12");
        check(32'h0020C663, 5'd1,  5'd2,  5'd12, FMT_B, ALU_ADD,  1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 2'b00, 1'b1, 1'b0, 1'b0, 1'b0, "BLT x1,x2,+12");

        // JAL / JALR
        // JAL's instr[24:20] = 8 here (part of J-imm bit-scatter).
        check(32'h008000EF, 5'd0,  5'd8,  5'd1,  FMT_J, ALU_ADD,  1'b0, 1'b0, 1'b0, 1'b0, 1'b1, 2'b10, 1'b0, 1'b1, 1'b0, 1'b0, "JAL x1,+8");
        check(32'h004100E7, 5'd2,  5'd4,  5'd1,  FMT_I, ALU_ADD,  1'b0, 1'b1, 1'b0, 1'b0, 1'b1, 2'b10, 1'b0, 1'b0, 1'b1, 1'b0, "JALR x1,x2,4");

        // LUI / AUIPC
        // For both, instr[19:15] = 8 and instr[24:20] = 3 (these
        // bits are the middle of the U-immediate's encoding —
        // extracted raw by the decoder).
        // LUI uses wb_src=11 (imm passthrough), so alu_op/src_a/src_b
        // are defaults (the writeback mux bypasses the ALU).
        check(32'h12345237, 5'd8,  5'd3,  5'd4,  FMT_U, ALU_ADD,  1'b0, 1'b0, 1'b0, 1'b0, 1'b1, 2'b11, 1'b0, 1'b0, 1'b0, 1'b0, "LUI x4,0x12345");
        check(32'h12345217, 5'd8,  5'd3,  5'd4,  FMT_U, ALU_ADD,  1'b1, 1'b1, 1'b0, 1'b0, 1'b1, 2'b00, 1'b0, 1'b0, 1'b0, 1'b0, "AUIPC x4,0x12345");

        // Truly unknown opcode (custom-0)
        check(32'h0000000B, 5'd0,  5'd0,  5'd0,  FMT_I, ALU_ADD,  1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 2'b00, 1'b0, 1'b0, 1'b0, 1'b1, "Unknown opcode");

        $display("decoder_rv32 simulation done!");
        $finish;
    end

endmodule
