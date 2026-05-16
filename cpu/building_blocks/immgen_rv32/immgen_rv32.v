// immgen_rv32.v - Verilog mirror of immgen_rv32.vhd.
//
// RV32I immediate generator. Combinational. See the VHDL header for
// the full bit-extraction tables for the five immediate formats; the
// concatenations below match them position-for-position.

module immgen_rv32 (
    input  wire [31:0] instr,
    input  wire [2:0]  fmt,
    output reg  [31:0] imm
);

    localparam [2:0] FMT_I = 3'b000;
    localparam [2:0] FMT_S = 3'b001;
    localparam [2:0] FMT_B = 3'b010;
    localparam [2:0] FMT_U = 3'b011;
    localparam [2:0] FMT_J = 3'b100;

    wire sign = instr[31];

    always @* begin
        case (fmt)
            FMT_I:   imm = {{20{sign}}, instr[31:20]};
            FMT_S:   imm = {{20{sign}}, instr[31:25], instr[11:7]};
            FMT_B:   imm = {{19{sign}}, instr[31], instr[7],
                            instr[30:25], instr[11:8], 1'b0};
            FMT_U:   imm = {instr[31:12], 12'b0};
            FMT_J:   imm = {{11{sign}}, instr[31], instr[19:12],
                            instr[20], instr[30:21], 1'b0};
            default: imm = 32'b0;
        endcase
    end

endmodule
