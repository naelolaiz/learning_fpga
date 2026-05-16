// riscv_singlecycle.v  (cpu/riscv_soc/ variant) - Verilog mirror.
//
// Same single-cycle RV32I datapath as cpu/riscv_singlecycle/ — but
// with the DMEM exposed as an external bus so the SoC top can
// multiplex it with memory-mapped peripherals. The IMEM stays
// internal (programs baked in at elaboration via IMEM_INIT).
//
// See the VHDL twin's header for the external-bus contract and the
// combinational-read constraint inherited from the single-cycle
// design.

`default_nettype none
`timescale 1ns/1ps

module riscv_singlecycle #(
    parameter integer IMEM_ADDR_W = 10,
    parameter         IMEM_INIT   = ""
) (
    input  wire        clk,
    input  wire        rst,

    // External DMEM bus.
    output wire [31:0] dmem_addr,
    output wire [31:0] dmem_wdata,
    output wire        dmem_we,
    output wire        dmem_re,
    input  wire [31:0] dmem_rdata,

    // Debug.
    output wire [31:0] dbg_pc,
    output wire [31:0] dbg_instr,
    output wire        dbg_reg_we,
    output wire [4:0]  dbg_reg_waddr,
    output wire [31:0] dbg_reg_wdata
);

    localparam integer IMEM_DEPTH = 1 << IMEM_ADDR_W;
    localparam [31:0]  NOP_INSTR  = 32'h00000013;

    reg [31:0] imem [0:IMEM_DEPTH-1];
    integer    init_fh;
    integer    init_lines;
    integer    init_rc;
    reg [31:0] init_word;
    integer    i;
    initial begin
        for (i = 0; i < IMEM_DEPTH; i = i + 1) imem[i] = NOP_INSTR;
        if (IMEM_INIT != "") begin
            // Two-pass: count file words, then $readmemh the exact
            // range. See cpu/riscv_singlecycle/riscv_singlecycle.v
            // for the rationale (silences the "not enough words"
            // warning that fires when the program is shorter than
            // IMEM_DEPTH, which it almost always is).
            init_fh    = $fopen(IMEM_INIT, "r");
            init_lines = 0;
            while (!$feof(init_fh)) begin
                init_rc = $fscanf(init_fh, "%h\n", init_word);
                if (init_rc == 1) init_lines = init_lines + 1;
            end
            $fclose(init_fh);
            if (init_lines > 0)
                $readmemh(IMEM_INIT, imem, 0, init_lines - 1);
        end
    end

    reg  [31:0] pc;
    wire [31:0] pc_plus_4   = pc + 32'd4;
    wire [31:0] pc_plus_imm;
    wire [31:0] next_pc;
    wire [31:0] instr       = imem[pc[IMEM_ADDR_W+1:2]];

    wire [4:0]  d_rs1, d_rs2, d_rd;
    wire [2:0]  d_imm_fmt;
    wire [3:0]  d_alu_op;
    wire        d_alu_src_a, d_alu_src_b;
    wire        d_mem_read, d_mem_write, d_reg_write;
    wire [1:0]  d_wb_src;
    wire        d_is_branch, d_is_jal, d_is_jalr, d_illegal;

    wire [2:0]  instr_funct3 = instr[14:12];

    wire [31:0] rs1_data, rs2_data;
    wire [31:0] imm;

    wire [31:0] alu_a = d_alu_src_a ? pc  : rs1_data;
    wire [31:0] alu_b = d_alu_src_b ? imm : rs2_data;
    wire [31:0] alu_result;
    wire        alu_zero;

    reg  [31:0] wb_data;
    reg         branch_taken;
    wire        take_branch = d_is_branch & branch_taken;

    always @(posedge clk) begin
        if (rst) pc <= 32'b0;
        else     pc <= next_pc;
    end

    decoder_rv32 decoder (
        .instr(instr),
        .rs1(d_rs1), .rs2(d_rs2), .rd(d_rd),
        .imm_fmt(d_imm_fmt),
        .alu_op(d_alu_op),
        .alu_src_a(d_alu_src_a),
        .alu_src_b(d_alu_src_b),
        .mem_read(d_mem_read),
        .mem_write(d_mem_write),
        .reg_write(d_reg_write),
        .wb_src(d_wb_src),
        .is_branch(d_is_branch),
        .is_jal(d_is_jal),
        .is_jalr(d_is_jalr),
        .illegal(d_illegal)
    );

    immgen_rv32 immgen (
        .instr(instr), .fmt(d_imm_fmt), .imm(imm)
    );

    regfile_rv32 regfile (
        .clk(clk),
        .we(d_reg_write),
        .waddr(d_rd),
        .wdata(wb_data),
        .raddr1(d_rs1), .rdata1(rs1_data),
        .raddr2(d_rs2), .rdata2(rs2_data)
    );

    alu_rv32 alu (
        .a(alu_a), .b(alu_b), .op(d_alu_op),
        .result(alu_result), .zero(alu_zero)
    );

    always @(*) begin
        case (instr_funct3)
            3'b000:  branch_taken = (rs1_data == rs2_data);
            3'b001:  branch_taken = (rs1_data != rs2_data);
            3'b100:  branch_taken = ($signed(rs1_data) <  $signed(rs2_data));
            3'b101:  branch_taken = ($signed(rs1_data) >= $signed(rs2_data));
            3'b110:  branch_taken = (rs1_data <  rs2_data);
            3'b111:  branch_taken = (rs1_data >= rs2_data);
            default: branch_taken = 1'b0;
        endcase
    end

    assign pc_plus_imm = pc + imm;
    assign next_pc     = d_is_jalr               ? {alu_result[31:1], 1'b0} :
                         (d_is_jal || take_branch) ? pc_plus_imm :
                                                     pc_plus_4;

    // External DMEM bus.
    assign dmem_addr  = alu_result;
    assign dmem_wdata = rs2_data;
    assign dmem_we    = d_mem_write;
    assign dmem_re    = d_mem_read;

    always @(*) begin
        case (d_wb_src)
            2'b00:   wb_data = alu_result;
            2'b01:   wb_data = dmem_rdata;
            2'b10:   wb_data = pc_plus_4;
            2'b11:   wb_data = imm;
            default: wb_data = alu_result;
        endcase
    end

    assign dbg_pc        = pc;
    assign dbg_instr     = instr;
    assign dbg_reg_we    = d_reg_write;
    assign dbg_reg_waddr = d_rd;
    assign dbg_reg_wdata = wb_data;

endmodule

`default_nettype wire
