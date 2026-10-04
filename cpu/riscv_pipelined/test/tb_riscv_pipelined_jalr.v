// JALR overlap, target alignment, link values, and skipped-store regression.
`timescale 1ns/1ps
`default_nettype none
module tb_riscv_pipelined_jalr;
    localparam [31:0] HALT_INSTR = 32'h0000006f;
    reg clk = 0, rst = 1;
    wire [31:0] dbg_pc, dbg_instr, dbg_reg_wdata;
    wire dbg_reg_we;
    wire [4:0] dbg_reg_waddr;
    reg [31:0] shadow_regs [0:31];
    reg halted = 0;
    reg [31:0] halt_pc = 0;
    integer i, cycles = 0;
    riscv_pipelined #(
        .IMEM_ADDR_W(8), .DMEM_ADDR_W(8),
        .IMEM_INIT("../../../tools/rv32_asm/programs/prog_jalr.hex")
    ) dut (
        .clk(clk), .rst(rst),
        .dbg_pc(dbg_pc), .dbg_instr(dbg_instr), .dbg_reg_we(dbg_reg_we),
        .dbg_reg_waddr(dbg_reg_waddr), .dbg_reg_wdata(dbg_reg_wdata)
    );
    always #10 clk = ~clk;
    // Sample the instruction's commit bus before same-edge nonblocking updates.
    always @(negedge clk) begin
        if (!rst) begin
            if (dbg_reg_we && dbg_reg_waddr != 0)
                shadow_regs[dbg_reg_waddr] <= dbg_reg_wdata;
            if (dbg_instr == HALT_INSTR) begin
                halt_pc <= dbg_pc;
                halted <= 1;
            end
        end
    end
    initial begin
        for (i=0; i<32; i=i+1) shadow_regs[i] = 0;
        $dumpfile(`FST_OUT);
        $dumpvars(0, tb_riscv_pipelined_jalr);
        #45 rst = 0;
        cycles = 0;
        while (!halted && cycles < 100) begin
            @(posedge clk);
            #1;
            cycles = cycles + 1;
        end
        if (!halted) $fatal(1, "JALR program timed out");
        if (halt_pc !== 32'd116)
            $fatal(1, "JALR chose wrong path: halted at PC=%0d, expected 116", halt_pc);
        if (shadow_regs[8] !== 4) $fatal(1, "Startup must commit once, followed by three JALR destinations");
        if (shadow_regs[9] !== 16) $fatal(1, "First overlapping JALR link must be 16");
        if (shadow_regs[18] !== 44) $fatal(1, "Negative-immediate overlapping JALR link must be 44");
        if (shadow_regs[19] !== 76) $fatal(1, "Distinct-register JALR link must be 76");
        if (shadow_regs[20] !== 42) $fatal(1, "Committed store/load value must be 42");
        if (shadow_regs[21] !== 43) $fatal(1, "Load-use result must be 43");
        if (shadow_regs[22] !== 0) $fatal(1, "A wrong-path store committed");
        $display("tb_riscv_pipelined_jalr simulation done!");
        $finish;
    end
endmodule
`default_nettype wire
