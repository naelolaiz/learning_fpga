// decoder_rv32.v - Verilog mirror of decoder_rv32.vhd.
//
// RV32I instruction decoder. Pure combinational. See the VHDL header
// for the full output table and the rationale behind each control
// signal. The case structure here mirrors the VHDL one-for-one.

module decoder_rv32 (
    input  wire [31:0] instr,

    output wire [4:0]  rs1,
    output wire [4:0]  rs2,
    output wire [4:0]  rd,

    output reg  [2:0]  imm_fmt,
    output reg  [3:0]  alu_op,
    output reg         alu_src_a,
    output reg         alu_src_b,

    output reg         mem_read,
    output reg         mem_write,
    output reg         reg_write,
    output reg  [1:0]  wb_src,

    output reg         is_branch,
    output reg         is_jal,
    output reg         is_jalr,

    output reg         illegal
);

    localparam [6:0] OP_LUI    = 7'b0110111;
    localparam [6:0] OP_AUIPC  = 7'b0010111;
    localparam [6:0] OP_JAL    = 7'b1101111;
    localparam [6:0] OP_JALR   = 7'b1100111;
    localparam [6:0] OP_BRANCH = 7'b1100011;
    localparam [6:0] OP_LOAD   = 7'b0000011;
    localparam [6:0] OP_STORE  = 7'b0100011;
    localparam [6:0] OP_ALU_I  = 7'b0010011;
    localparam [6:0] OP_ALU_R  = 7'b0110011;

    localparam [2:0] FMT_I = 3'b000;
    localparam [2:0] FMT_S = 3'b001;
    localparam [2:0] FMT_B = 3'b010;
    localparam [2:0] FMT_U = 3'b011;
    localparam [2:0] FMT_J = 3'b100;

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

    wire [6:0] opcode      = instr[6:0];
    wire [2:0] funct3      = instr[14:12];
    wire       funct7_bit5 = instr[30];

    assign rs1 = instr[19:15];
    assign rs2 = instr[24:20];
    assign rd  = instr[11:7];

    always @* begin
        // Defaults — no-op.
        imm_fmt   = FMT_I;
        alu_op    = ALU_ADD;
        alu_src_a = 1'b0;
        alu_src_b = 1'b0;
        mem_read  = 1'b0;
        mem_write = 1'b0;
        reg_write = 1'b0;
        wb_src    = 2'b00;
        is_branch = 1'b0;
        is_jal    = 1'b0;
        is_jalr   = 1'b0;
        illegal   = 1'b0;

        case (opcode)
            OP_LUI: begin
                // wb_src=11 routes imm straight to rd via the
                // top-level writeback mux, bypassing the ALU. See the
                // VHDL header for the rationale.
                imm_fmt   = FMT_U;
                reg_write = 1'b1;
                wb_src    = 2'b11;
            end

            OP_AUIPC: begin
                imm_fmt   = FMT_U;
                alu_src_a = 1'b1;
                alu_src_b = 1'b1;
                alu_op    = ALU_ADD;
                reg_write = 1'b1;
                wb_src    = 2'b00;
            end

            OP_JAL: begin
                imm_fmt   = FMT_J;
                reg_write = 1'b1;
                wb_src    = 2'b10;
                is_jal    = 1'b1;
            end

            OP_JALR: begin
                imm_fmt   = FMT_I;
                alu_src_b = 1'b1;
                alu_op    = ALU_ADD;
                reg_write = 1'b1;
                wb_src    = 2'b10;
                is_jalr   = 1'b1;
            end

            OP_BRANCH: begin
                imm_fmt   = FMT_B;
                is_branch = 1'b1;
            end

            OP_LOAD: begin
                imm_fmt   = FMT_I;
                alu_src_b = 1'b1;
                alu_op    = ALU_ADD;
                mem_read  = 1'b1;
                reg_write = 1'b1;
                wb_src    = 2'b01;
                if (funct3 != 3'b010) illegal = 1'b1;
            end

            OP_STORE: begin
                imm_fmt   = FMT_S;
                alu_src_b = 1'b1;
                alu_op    = ALU_ADD;
                mem_write = 1'b1;
                if (funct3 != 3'b010) illegal = 1'b1;
            end

            OP_ALU_I: begin
                imm_fmt   = FMT_I;
                alu_src_b = 1'b1;
                reg_write = 1'b1;
                case (funct3)
                    3'b000: alu_op = ALU_ADD;
                    3'b001: alu_op = ALU_SLL;
                    3'b010: alu_op = ALU_SLT;
                    3'b011: alu_op = ALU_SLTU;
                    3'b100: alu_op = ALU_XOR;
                    3'b101: alu_op = funct7_bit5 ? ALU_SRA : ALU_SRL;
                    3'b110: alu_op = ALU_OR;
                    3'b111: alu_op = ALU_AND;
                    default: illegal = 1'b1;
                endcase
            end

            OP_ALU_R: begin
                alu_src_b = 1'b0;
                reg_write = 1'b1;
                case (funct3)
                    3'b000: alu_op = funct7_bit5 ? ALU_SUB : ALU_ADD;
                    3'b001: alu_op = ALU_SLL;
                    3'b010: alu_op = ALU_SLT;
                    3'b011: alu_op = ALU_SLTU;
                    3'b100: alu_op = ALU_XOR;
                    3'b101: alu_op = funct7_bit5 ? ALU_SRA : ALU_SRL;
                    3'b110: alu_op = ALU_OR;
                    3'b111: alu_op = ALU_AND;
                    default: illegal = 1'b1;
                endcase
            end

            default: illegal = 1'b1;
        endcase
    end

endmodule
