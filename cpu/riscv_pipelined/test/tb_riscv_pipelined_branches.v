// tb_riscv_pipelined_branches.v - Verilog mirror of
// tb_riscv_pipelined_branches.vhd. Every branch flavour taken and
// not-taken; expected s0 = 4.

`timescale 1ns/1ps
`default_nettype none

module tb_riscv_pipelined_branches;

    localparam time    CLK_PERIOD = 20;
    localparam [31:0]  HALT_INSTR = 32'h0000006F;
    localparam integer MAX_CYCLES = 500;

    reg  clk = 1'b0;
    reg  rst = 1'b1;
    reg  sim_active = 1'b1;

    wire [31:0] dbg_pc, dbg_instr, dbg_reg_wdata;
    wire        dbg_reg_we;
    wire [4:0]  dbg_reg_waddr;

    reg [31:0] shadow_regs [0:31];
    integer i = 0;
    initial for (i = 0; i < 32; i = i + 1) shadow_regs[i] = 32'b0;

    reg halted = 1'b0;

    riscv_pipelined #(
        .IMEM_ADDR_W(8),
        .DMEM_ADDR_W(8),
        .IMEM_INIT  ("../../../tools/rv32_asm/programs/prog_branches.hex")
    ) dut (
        .clk(clk), .rst(rst),
        .dbg_pc(dbg_pc), .dbg_instr(dbg_instr),
        .dbg_reg_we(dbg_reg_we), .dbg_reg_waddr(dbg_reg_waddr),
        .dbg_reg_wdata(dbg_reg_wdata)
    );

    initial begin
        $dumpfile(`FST_OUT);
        $dumpvars(0, tb_riscv_pipelined_branches);
    end

    always #(CLK_PERIOD/2.0) if (sim_active) clk = ~clk;

    always @(negedge clk) begin
        if (dbg_reg_we && dbg_reg_waddr != 5'd0)
            shadow_regs[dbg_reg_waddr] <= dbg_reg_wdata;
        if (dbg_instr == HALT_INSTR)
            halted <= 1'b1;
    end

    integer cycle_count = 0;
    initial begin
        #(2 * CLK_PERIOD) rst = 1'b0;
        while (!halted && cycle_count < MAX_CYCLES) begin
            @(posedge clk);
            cycle_count = cycle_count + 1;
        end
        if (!halted)
            $fatal(1, "Timeout: program did not halt within %0d cycles", MAX_CYCLES);

        @(posedge clk);

        if ($signed(shadow_regs[8]) !== 32'sd4)
            $fatal(1, "prog_branches: expected s0 = 4, got %0d", $signed(shadow_regs[8]));

        $display("tb_riscv_pipelined_branches simulation done!");
        sim_active = 1'b0;
        $finish;
    end

endmodule

`default_nettype wire
