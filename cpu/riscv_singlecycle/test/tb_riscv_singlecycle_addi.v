// tb_riscv_singlecycle_addi.v - Verilog mirror of
// tb_riscv_singlecycle_addi.vhd. Same prog_addi.hex, same shadow-
// regfile snooping, same final-state assertion (t0 = 3).
//
// Doubles as the DEBUG_TRACE demo (see the VHDL twin's header for
// the full rationale). DEBUG_TRACE = 1 below switches on the per-
// cycle trace inside riscv_singlecycle.v.

`timescale 1ns/1ps
`default_nettype none

module tb_riscv_singlecycle_addi;

    localparam time   CLK_PERIOD = 20;
    localparam [31:0] HALT_INSTR = 32'h0000006F;
    localparam integer MAX_CYCLES = 200;

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

    riscv_singlecycle #(
        .IMEM_ADDR_W(8),
        .DMEM_ADDR_W(8),
        .IMEM_INIT  ("../../../tools/rv32_asm/programs/prog_addi.hex"),
        .DEBUG_TRACE(1)
    ) dut (
        .clk(clk), .rst(rst),
        .dbg_pc(dbg_pc), .dbg_instr(dbg_instr),
        .dbg_reg_we(dbg_reg_we), .dbg_reg_waddr(dbg_reg_waddr),
        .dbg_reg_wdata(dbg_reg_wdata)
    );

    initial begin
        $dumpfile(`FST_OUT);
        $dumpvars(0, tb_riscv_singlecycle_addi);
    end

    always #(CLK_PERIOD/2.0) if (sim_active) clk = ~clk;

    // Falling-edge sample — same rationale as the VHDL twin.
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

        if (shadow_regs[5] !== 32'h00000003)
            $fatal(1, "prog_addi: expected t0 = 3, got %0d", shadow_regs[5]);

        $display("tb_riscv_singlecycle_addi simulation done!");
        sim_active = 1'b0;
        $finish;
    end

endmodule

`default_nettype wire
