// forwarding_unit.v - Verilog mirror of forwarding_unit.vhd.
//
// Pure combinational forwarding unit. See the VHDL twin's header
// comment for the priority / x0-guard reasoning; the body below
// translates 1:1.

`default_nettype none

module forwarding_unit (
    input  wire [4:0] ex_rs1,
    input  wire [4:0] ex_rs2,
    input  wire [4:0] mem_rd,
    input  wire       mem_we,
    input  wire [4:0] wb_rd,
    input  wire       wb_we,
    output wire [1:0] fwd_a,
    output wire [1:0] fwd_b
);

    assign fwd_a = (mem_we && mem_rd != 5'd0 && mem_rd == ex_rs1) ? 2'b10 :
                   (wb_we  && wb_rd  != 5'd0 && wb_rd  == ex_rs1) ? 2'b01 :
                                                                    2'b00;

    assign fwd_b = (mem_we && mem_rd != 5'd0 && mem_rd == ex_rs2) ? 2'b10 :
                   (wb_we  && wb_rd  != 5'd0 && wb_rd  == ex_rs2) ? 2'b01 :
                                                                    2'b00;

endmodule

`default_nettype wire
