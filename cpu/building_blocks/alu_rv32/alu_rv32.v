// alu_rv32.v - Verilog mirror of alu_rv32.vhd.
//
// 32-bit RV32I ALU. Pure combinational. See the VHDL header for the
// op-encoding table; the values below match it bit-for-bit.

module alu_rv32 (
    input  wire [31:0] a,
    input  wire [31:0] b,
    input  wire [3:0]  op,
    output reg  [31:0] result,
    output wire        zero
);

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

    wire [4:0] shamt = b[4:0];

    always @* begin
        case (op)
            ALU_ADD : result = a + b;
            ALU_SUB : result = a - b;
            ALU_AND : result = a & b;
            ALU_OR  : result = a | b;
            ALU_XOR : result = a ^ b;
            ALU_SLL : result = a << shamt;
            ALU_SRL : result = a >> shamt;
            ALU_SRA : result = $signed(a) >>> shamt;
            ALU_SLT : result = ($signed(a) < $signed(b)) ? 32'd1 : 32'd0;
            ALU_SLTU: result = (a < b)                   ? 32'd1 : 32'd0;
            default : result = 32'd0;
        endcase
    end

    assign zero = (result == 32'd0);

endmodule
