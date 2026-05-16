// regfile_rv32.v - Verilog mirror of regfile_rv32.vhd.
//
// RV32I register file. 32 architectural registers, x0 hardwired to
// zero, two combinational read ports, one synchronous write port.
// Writes happen on the FALLING clock edge — see the VHDL header for
// why (textbook single-cycle-friendly timing; the read port returns
// the OLD stored value within the same cycle, the new value lands
// by the next rising edge).

module regfile_rv32 (
    input  wire        clk,
    input  wire        we,
    input  wire [4:0]  waddr,
    input  wire [31:0] wdata,
    input  wire [4:0]  raddr1,
    output wire [31:0] rdata1,
    input  wire [4:0]  raddr2,
    output wire [31:0] rdata2
);

    reg [31:0] regs [0:31];

    integer i;
    initial for (i = 0; i < 32; i = i + 1) regs[i] = 32'h0;

    // Falling edge — see the VHDL header.
    always @(negedge clk) begin
        if (we && (waddr != 5'd0)) regs[waddr] <= wdata;
    end

    assign rdata1 = (raddr1 == 5'd0) ? 32'h0 : regs[raddr1];
    assign rdata2 = (raddr2 == 5'd0) ? 32'h0 : regs[raddr2];

endmodule
