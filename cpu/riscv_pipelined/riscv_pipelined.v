// riscv_pipelined.v - Verilog mirror of riscv_pipelined.vhd.
//
// 5-stage IF/ID/EX/MEM/WB pipeline. See the VHDL twin's header for
// the pipeline organisation, hazard responses, and forwarding rules.
//
// Verilog-specific notes:
//   * VHDL records become flat individual `reg` per field — clunkier
//     to read but stable across iverilog -g2012 and yosys's SV
//     frontend. Names follow the same convention: <stage>_<field>
//     for the latched register, <stage>_<field>_n for the
//     combinational next-state wire.
//   * IMEM via $readmemh, same idiom as the standalone single-cycle
//     Verilog twin.

`default_nettype none
`timescale 1ns/1ps

module riscv_pipelined #(
    parameter integer IMEM_ADDR_W = 10,
    parameter integer DMEM_ADDR_W = 10,
    parameter         IMEM_INIT   = ""
) (
    input  wire        clk,
    input  wire        rst,

    output wire [31:0] dbg_pc,
    output wire [31:0] dbg_instr,
    output wire        dbg_reg_we,
    output wire [4:0]  dbg_reg_waddr,
    output wire [31:0] dbg_reg_wdata
);

    // ---------------------------------------------------------------
    // IMEM / DMEM (same idiom as the single-cycle Verilog twin)
    // ---------------------------------------------------------------
    localparam integer IMEM_DEPTH = 1 << IMEM_ADDR_W;
    localparam integer DMEM_DEPTH = 1 << DMEM_ADDR_W;
    localparam [31:0]  NOP_INSTR  = 32'h00000013;

    reg [31:0] imem [0:IMEM_DEPTH-1];
    reg [31:0] dmem [0:DMEM_DEPTH-1];
    integer    init_fh;
    integer    init_lines;
    integer    init_rc;
    reg [31:0] init_word;
    integer i, j;
    initial begin
        for (i = 0; i < IMEM_DEPTH; i = i + 1) imem[i] = NOP_INSTR;
        for (j = 0; j < DMEM_DEPTH; j = j + 1) dmem[j] = 32'b0;
        if (IMEM_INIT != "") begin
            // Two-pass: count file words, then $readmemh the exact
            // range. See cpu/riscv_singlecycle/riscv_singlecycle.v
            // for the rationale.
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

    // ---------------------------------------------------------------
    // IF stage
    // ---------------------------------------------------------------
    reg  [31:0] pc;
    wire [31:0] pc_plus_4 = pc + 32'd4;
    wire [31:0] pc_next;
    wire [31:0] if_instr  = imem[pc[IMEM_ADDR_W+1:2]];

    // Pipeline regs + next-state for IF/ID
    reg  [31:0] if_id_pc;
    reg  [31:0] if_id_pc_plus_4;
    reg  [31:0] if_id_instr;
    wire [31:0] if_id_pc_n, if_id_pc_plus_4_n, if_id_instr_n;

    // ---------------------------------------------------------------
    // ID stage signals
    // ---------------------------------------------------------------
    wire [4:0]  id_d_rs1, id_d_rs2, id_d_rd;
    wire [2:0]  id_d_imm_fmt;
    wire [3:0]  id_d_alu_op;
    wire        id_d_alu_src_a, id_d_alu_src_b;
    wire        id_d_mem_read, id_d_mem_write, id_d_reg_write;
    wire [1:0]  id_d_wb_src;
    wire        id_d_is_branch, id_d_is_jal, id_d_is_jalr, id_d_illegal;
    wire [31:0] id_rs1_data, id_rs2_data, id_imm;

    // ID/EX pipeline regs
    reg  [31:0] id_ex_pc, id_ex_pc_plus_4, id_ex_instr;
    reg  [31:0] id_ex_rs1_val, id_ex_rs2_val, id_ex_imm;
    reg  [4:0]  id_ex_rs1_idx, id_ex_rs2_idx, id_ex_rd;
    reg  [3:0]  id_ex_alu_op;
    reg  [2:0]  id_ex_funct3;
    reg         id_ex_alu_src_a, id_ex_alu_src_b;
    reg         id_ex_reg_write, id_ex_mem_read, id_ex_mem_write;
    reg  [1:0]  id_ex_wb_src;
    reg         id_ex_is_branch, id_ex_is_jal, id_ex_is_jalr;

    wire [31:0] id_ex_pc_n, id_ex_pc_plus_4_n, id_ex_instr_n;
    wire [31:0] id_ex_rs1_val_n, id_ex_rs2_val_n, id_ex_imm_n;
    wire [4:0]  id_ex_rs1_idx_n, id_ex_rs2_idx_n, id_ex_rd_n;
    wire [3:0]  id_ex_alu_op_n;
    wire [2:0]  id_ex_funct3_n;
    wire        id_ex_alu_src_a_n, id_ex_alu_src_b_n;
    wire        id_ex_reg_write_n, id_ex_mem_read_n, id_ex_mem_write_n;
    wire [1:0]  id_ex_wb_src_n;
    wire        id_ex_is_branch_n, id_ex_is_jal_n, id_ex_is_jalr_n;

    // ---------------------------------------------------------------
    // EX stage signals
    // ---------------------------------------------------------------
    wire [1:0]  fwd_a, fwd_b;
    wire [31:0] ex_a_forwarded, ex_b_forwarded;
    wire [31:0] ex_alu_a, ex_alu_b;
    wire [31:0] ex_alu_result;
    wire        ex_alu_zero;
    reg         ex_branch_cmp;
    wire        ex_branch_taken;
    wire        ex_take_branch, ex_take_jump;
    wire [31:0] ex_branch_target, ex_jalr_target;

    // EX/MEM pipeline regs
    reg  [31:0] ex_mem_pc_plus_4, ex_mem_instr;
    reg  [31:0] ex_mem_alu_result, ex_mem_store_data;
    reg  [4:0]  ex_mem_rd;
    reg         ex_mem_reg_write, ex_mem_mem_read, ex_mem_mem_write;
    reg  [1:0]  ex_mem_wb_src;

    wire [31:0] ex_mem_pc_plus_4_n, ex_mem_instr_n;
    wire [31:0] ex_mem_alu_result_n, ex_mem_store_data_n;
    wire [4:0]  ex_mem_rd_n;
    wire        ex_mem_reg_write_n, ex_mem_mem_read_n, ex_mem_mem_write_n;
    wire [1:0]  ex_mem_wb_src_n;

    // ---------------------------------------------------------------
    // MEM stage
    // ---------------------------------------------------------------
    wire [DMEM_ADDR_W-1:0] mem_dmem_addr = ex_mem_alu_result[DMEM_ADDR_W+1:2];
    wire [31:0] mem_dmem_rdata = dmem[mem_dmem_addr];

    // MEM/WB pipeline regs
    reg  [31:0] mem_wb_pc_plus_4, mem_wb_instr;
    reg  [31:0] mem_wb_alu_result, mem_wb_mem_data;
    reg  [4:0]  mem_wb_rd;
    reg         mem_wb_reg_write;
    reg  [1:0]  mem_wb_wb_src;

    wire [31:0] mem_wb_pc_plus_4_n, mem_wb_instr_n;
    wire [31:0] mem_wb_alu_result_n, mem_wb_mem_data_n;
    wire [4:0]  mem_wb_rd_n;
    wire        mem_wb_reg_write_n;
    wire [1:0]  mem_wb_wb_src_n;

    // ---------------------------------------------------------------
    // WB stage
    // ---------------------------------------------------------------
    reg  [31:0] wb_data;

    // ---------------------------------------------------------------
    // Hazard responses (combinational)
    // ---------------------------------------------------------------
    wire stall, flush;

    // ===============================================================
    // IF
    // ===============================================================
    always @(posedge clk) begin
        if (rst)        pc <= 32'b0;
        else if (!stall) pc <= pc_next;
    end

    // Next PC.
    assign pc_next = (id_ex_is_jalr && ex_take_jump) ? ex_jalr_target :
                     (ex_take_branch || ex_take_jump) ? ex_branch_target :
                                                        pc_plus_4;

    // IF/ID next-state: flush → NOP, stall → freeze, else latch.
    assign if_id_pc_n        = flush ? 32'b0     : (stall ? if_id_pc        : pc);
    assign if_id_pc_plus_4_n = flush ? 32'b0     : (stall ? if_id_pc_plus_4 : pc_plus_4);
    assign if_id_instr_n     = flush ? NOP_INSTR : (stall ? if_id_instr     : if_instr);

    // ===============================================================
    // ID
    // ===============================================================
    decoder_rv32 decoder (
        .instr(if_id_instr),
        .rs1(id_d_rs1), .rs2(id_d_rs2), .rd(id_d_rd),
        .imm_fmt(id_d_imm_fmt),
        .alu_op(id_d_alu_op),
        .alu_src_a(id_d_alu_src_a),
        .alu_src_b(id_d_alu_src_b),
        .mem_read(id_d_mem_read),
        .mem_write(id_d_mem_write),
        .reg_write(id_d_reg_write),
        .wb_src(id_d_wb_src),
        .is_branch(id_d_is_branch),
        .is_jal(id_d_is_jal),
        .is_jalr(id_d_is_jalr),
        .illegal(id_d_illegal)
    );

    immgen_rv32 immgen (
        .instr(if_id_instr), .fmt(id_d_imm_fmt), .imm(id_imm)
    );

    regfile_rv32 regfile (
        .clk(clk),
        .we(mem_wb_reg_write),
        .waddr(mem_wb_rd),
        .wdata(wb_data),
        .raddr1(id_d_rs1), .rdata1(id_rs1_data),
        .raddr2(id_d_rs2), .rdata2(id_rs2_data)
    );

    // ID/EX next-state. flush or stall → NOP into ID/EX.
    wire id_ex_make_nop = flush | stall;
    assign id_ex_pc_n         = id_ex_make_nop ? 32'b0     : if_id_pc;
    assign id_ex_pc_plus_4_n  = id_ex_make_nop ? 32'b0     : if_id_pc_plus_4;
    assign id_ex_instr_n      = id_ex_make_nop ? NOP_INSTR : if_id_instr;
    assign id_ex_rs1_val_n    = id_ex_make_nop ? 32'b0     : id_rs1_data;
    assign id_ex_rs2_val_n    = id_ex_make_nop ? 32'b0     : id_rs2_data;
    assign id_ex_imm_n        = id_ex_make_nop ? 32'b0     : id_imm;
    assign id_ex_rs1_idx_n    = id_ex_make_nop ? 5'b0      : id_d_rs1;
    assign id_ex_rs2_idx_n    = id_ex_make_nop ? 5'b0      : id_d_rs2;
    assign id_ex_rd_n         = id_ex_make_nop ? 5'b0      : id_d_rd;
    assign id_ex_alu_op_n     = id_ex_make_nop ? 4'b0      : id_d_alu_op;
    assign id_ex_funct3_n     = id_ex_make_nop ? 3'b0      : if_id_instr[14:12];
    assign id_ex_alu_src_a_n  = id_ex_make_nop ? 1'b0      : id_d_alu_src_a;
    assign id_ex_alu_src_b_n  = id_ex_make_nop ? 1'b0      : id_d_alu_src_b;
    assign id_ex_reg_write_n  = id_ex_make_nop ? 1'b0      : id_d_reg_write;
    assign id_ex_mem_read_n   = id_ex_make_nop ? 1'b0      : id_d_mem_read;
    assign id_ex_mem_write_n  = id_ex_make_nop ? 1'b0      : id_d_mem_write;
    assign id_ex_wb_src_n     = id_ex_make_nop ? 2'b00     : id_d_wb_src;
    assign id_ex_is_branch_n  = id_ex_make_nop ? 1'b0      : id_d_is_branch;
    assign id_ex_is_jal_n     = id_ex_make_nop ? 1'b0      : id_d_is_jal;
    assign id_ex_is_jalr_n    = id_ex_make_nop ? 1'b0      : id_d_is_jalr;

    // ===============================================================
    // EX
    // ===============================================================
    forwarding_unit fu (
        .ex_rs1(id_ex_rs1_idx), .ex_rs2(id_ex_rs2_idx),
        .mem_rd(ex_mem_rd),     .mem_we(ex_mem_reg_write),
        .wb_rd (mem_wb_rd),     .wb_we (mem_wb_reg_write),
        .fwd_a (fwd_a),         .fwd_b (fwd_b)
    );

    assign ex_a_forwarded = (fwd_a == 2'b10) ? ex_mem_alu_result :
                            (fwd_a == 2'b01) ? wb_data           :
                                               id_ex_rs1_val;

    assign ex_b_forwarded = (fwd_b == 2'b10) ? ex_mem_alu_result :
                            (fwd_b == 2'b01) ? wb_data           :
                                               id_ex_rs2_val;

    assign ex_alu_a = id_ex_alu_src_a ? id_ex_pc  : ex_a_forwarded;
    assign ex_alu_b = id_ex_alu_src_b ? id_ex_imm : ex_b_forwarded;

    alu_rv32 alu (
        .a(ex_alu_a), .b(ex_alu_b), .op(id_ex_alu_op),
        .result(ex_alu_result), .zero(ex_alu_zero)
    );

    always @(*) begin
        case (id_ex_funct3)
            3'b000:  ex_branch_cmp = (ex_a_forwarded == ex_b_forwarded);
            3'b001:  ex_branch_cmp = (ex_a_forwarded != ex_b_forwarded);
            3'b100:  ex_branch_cmp = ($signed(ex_a_forwarded) <  $signed(ex_b_forwarded));
            3'b101:  ex_branch_cmp = ($signed(ex_a_forwarded) >= $signed(ex_b_forwarded));
            3'b110:  ex_branch_cmp = (ex_a_forwarded <  ex_b_forwarded);
            3'b111:  ex_branch_cmp = (ex_a_forwarded >= ex_b_forwarded);
            default: ex_branch_cmp = 1'b0;
        endcase
    end

    assign ex_branch_taken  = id_ex_is_branch & ex_branch_cmp;
    assign ex_take_branch   = ex_branch_taken;
    assign ex_take_jump     = id_ex_is_jal | id_ex_is_jalr;
    assign ex_branch_target = id_ex_pc + id_ex_imm;
    assign ex_jalr_target   = {ex_alu_result[31:1], 1'b0};

    // EX/MEM next-state.
    assign ex_mem_pc_plus_4_n  = id_ex_pc_plus_4;
    assign ex_mem_instr_n      = id_ex_instr;
    assign ex_mem_alu_result_n = ex_alu_result;
    assign ex_mem_store_data_n = ex_b_forwarded;
    assign ex_mem_rd_n         = id_ex_rd;
    assign ex_mem_reg_write_n  = id_ex_reg_write;
    assign ex_mem_mem_read_n   = id_ex_mem_read;
    assign ex_mem_mem_write_n  = id_ex_mem_write;
    assign ex_mem_wb_src_n     = id_ex_wb_src;

    // ===============================================================
    // MEM
    // ===============================================================
    always @(posedge clk) begin
        if (ex_mem_mem_write)
            dmem[mem_dmem_addr] <= ex_mem_store_data;
    end

    assign mem_wb_pc_plus_4_n  = ex_mem_pc_plus_4;
    assign mem_wb_instr_n      = ex_mem_instr;
    assign mem_wb_alu_result_n = ex_mem_alu_result;
    assign mem_wb_mem_data_n   = mem_dmem_rdata;
    assign mem_wb_rd_n         = ex_mem_rd;
    assign mem_wb_reg_write_n  = ex_mem_reg_write;
    assign mem_wb_wb_src_n     = ex_mem_wb_src;

    // ===============================================================
    // WB
    // ===============================================================
    always @(*) begin
        case (mem_wb_wb_src)
            2'b00:   wb_data = mem_wb_alu_result;
            2'b01:   wb_data = mem_wb_mem_data;
            2'b10:   wb_data = mem_wb_pc_plus_4;
            default: wb_data = mem_wb_alu_result;
        endcase
    end

    // ===============================================================
    // Hazard detector
    // ===============================================================
    hazard_detector hd (
        .id_rs1      (id_d_rs1),
        .id_rs2      (id_d_rs2),
        .ex_rd       (id_ex_rd),
        .ex_mem_read (id_ex_mem_read),
        .branch_taken(ex_take_branch | ex_take_jump),
        .stall       (stall),
        .flush       (flush)
    );

    // ===============================================================
    // Pipeline-register update — one always block per boundary on
    // each clock edge. Reset clears every register to NOP.
    // ===============================================================
    always @(posedge clk) begin
        if (rst) begin
            // IF/ID
            if_id_pc <= 32'b0; if_id_pc_plus_4 <= 32'b0; if_id_instr <= NOP_INSTR;
            // ID/EX
            id_ex_pc <= 32'b0; id_ex_pc_plus_4 <= 32'b0; id_ex_instr <= NOP_INSTR;
            id_ex_rs1_val <= 32'b0; id_ex_rs2_val <= 32'b0; id_ex_imm <= 32'b0;
            id_ex_rs1_idx <= 5'b0; id_ex_rs2_idx <= 5'b0; id_ex_rd <= 5'b0;
            id_ex_alu_op <= 4'b0; id_ex_funct3 <= 3'b0;
            id_ex_alu_src_a <= 1'b0; id_ex_alu_src_b <= 1'b0;
            id_ex_reg_write <= 1'b0; id_ex_mem_read <= 1'b0; id_ex_mem_write <= 1'b0;
            id_ex_wb_src <= 2'b0;
            id_ex_is_branch <= 1'b0; id_ex_is_jal <= 1'b0; id_ex_is_jalr <= 1'b0;
            // EX/MEM
            ex_mem_pc_plus_4 <= 32'b0; ex_mem_instr <= NOP_INSTR;
            ex_mem_alu_result <= 32'b0; ex_mem_store_data <= 32'b0;
            ex_mem_rd <= 5'b0;
            ex_mem_reg_write <= 1'b0; ex_mem_mem_read <= 1'b0; ex_mem_mem_write <= 1'b0;
            ex_mem_wb_src <= 2'b0;
            // MEM/WB
            mem_wb_pc_plus_4 <= 32'b0; mem_wb_instr <= NOP_INSTR;
            mem_wb_alu_result <= 32'b0; mem_wb_mem_data <= 32'b0;
            mem_wb_rd <= 5'b0;
            mem_wb_reg_write <= 1'b0; mem_wb_wb_src <= 2'b0;
        end else begin
            // IF/ID
            if_id_pc <= if_id_pc_n; if_id_pc_plus_4 <= if_id_pc_plus_4_n;
            if_id_instr <= if_id_instr_n;
            // ID/EX
            id_ex_pc <= id_ex_pc_n; id_ex_pc_plus_4 <= id_ex_pc_plus_4_n;
            id_ex_instr <= id_ex_instr_n;
            id_ex_rs1_val <= id_ex_rs1_val_n; id_ex_rs2_val <= id_ex_rs2_val_n;
            id_ex_imm <= id_ex_imm_n;
            id_ex_rs1_idx <= id_ex_rs1_idx_n; id_ex_rs2_idx <= id_ex_rs2_idx_n;
            id_ex_rd <= id_ex_rd_n;
            id_ex_alu_op <= id_ex_alu_op_n; id_ex_funct3 <= id_ex_funct3_n;
            id_ex_alu_src_a <= id_ex_alu_src_a_n; id_ex_alu_src_b <= id_ex_alu_src_b_n;
            id_ex_reg_write <= id_ex_reg_write_n;
            id_ex_mem_read <= id_ex_mem_read_n; id_ex_mem_write <= id_ex_mem_write_n;
            id_ex_wb_src <= id_ex_wb_src_n;
            id_ex_is_branch <= id_ex_is_branch_n;
            id_ex_is_jal <= id_ex_is_jal_n; id_ex_is_jalr <= id_ex_is_jalr_n;
            // EX/MEM
            ex_mem_pc_plus_4 <= ex_mem_pc_plus_4_n;
            ex_mem_instr <= ex_mem_instr_n;
            ex_mem_alu_result <= ex_mem_alu_result_n;
            ex_mem_store_data <= ex_mem_store_data_n;
            ex_mem_rd <= ex_mem_rd_n;
            ex_mem_reg_write <= ex_mem_reg_write_n;
            ex_mem_mem_read <= ex_mem_mem_read_n;
            ex_mem_mem_write <= ex_mem_mem_write_n;
            ex_mem_wb_src <= ex_mem_wb_src_n;
            // MEM/WB
            mem_wb_pc_plus_4 <= mem_wb_pc_plus_4_n;
            mem_wb_instr <= mem_wb_instr_n;
            mem_wb_alu_result <= mem_wb_alu_result_n;
            mem_wb_mem_data <= mem_wb_mem_data_n;
            mem_wb_rd <= mem_wb_rd_n;
            mem_wb_reg_write <= mem_wb_reg_write_n;
            mem_wb_wb_src <= mem_wb_wb_src_n;
        end
    end

    // ===============================================================
    // Debug bus — WB stage commits.
    // ===============================================================
    assign dbg_pc        = mem_wb_pc_plus_4 - 32'd4;
    assign dbg_instr     = mem_wb_instr;
    assign dbg_reg_we    = mem_wb_reg_write;
    assign dbg_reg_waddr = mem_wb_rd;
    assign dbg_reg_wdata = wb_data;

endmodule

`default_nettype wire
