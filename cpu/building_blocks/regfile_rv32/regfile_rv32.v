// regfile_rv32.v - Verilog mirror of regfile_rv32.vhd.
//
// RV32I register file. 32 architectural registers, x0 hardwired to
// zero, two combinational read ports, one synchronous write port.
// WRITE_FALLING_EDGE defaults to 1 for the pipelined CPU's WB-to-ID
// timing. Single-cycle CPUs select 0 so PC and register/memory writes
// commit together on the rising edge. Reads always return stored data.

module regfile_rv32 #(
    parameter integer WRITE_FALLING_EDGE = 1
) (
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

    generate
        if (WRITE_FALLING_EDGE) begin : falling_write
            always @(negedge clk)
                if (we && (waddr != 5'd0)) regs[waddr] <= wdata;
        end else begin : rising_write
            always @(posedge clk)
                if (we && (waddr != 5'd0)) regs[waddr] <= wdata;
        end
    endgenerate

    assign rdata1 = (raddr1 == 5'd0) ? 32'h0 : regs[raddr1];
    assign rdata2 = (raddr2 == 5'd0) ? 32'h0 : regs[raddr2];

endmodule
