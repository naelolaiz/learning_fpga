// hazard_detector.v - Verilog mirror of hazard_detector.vhd.
//
// See the VHDL twin for the load-use and branch-flush rationale.

`default_nettype none

module hazard_detector (
    input  wire [4:0] id_rs1,
    input  wire [4:0] id_rs2,
    input  wire [4:0] ex_rd,
    input  wire       ex_mem_read,
    input  wire       branch_taken,
    output wire       stall,
    output wire       flush
);

    assign stall = (ex_mem_read && ex_rd != 5'd0 &&
                    (ex_rd == id_rs1 || ex_rd == id_rs2)) ? 1'b1 : 1'b0;
    assign flush = branch_taken;

endmodule

`default_nettype wire
