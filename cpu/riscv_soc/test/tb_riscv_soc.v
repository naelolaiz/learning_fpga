// tb_riscv_soc.v - Verilog mirror of tb_riscv_soc.vhd.
//
// Boots the SoC with prog_hello.hex in IMEM, samples the UART_TX
// pin at each bit-center, captures the LSB-first byte, and asserts
// the running output equals the expected "Hello, RV32!\n" greeting.
//
// See the VHDL twin for the sampler-vs-halt timing rationale.

`timescale 1ns/1ps
`default_nettype none

module tb_riscv_soc;

    localparam time    CLK_PERIOD   = 20;
    localparam integer CLKS_PER_BIT = 8;
    localparam time    BIT_TIME     = CLK_PERIOD * CLKS_PER_BIT;
    localparam [31:0]  HALT_INSTR   = 32'h0000006F;
    localparam integer N_EXPECTED   = 13;
    localparam integer MAX_CYCLES   = 5000;

    // "Hello, RV32!\n" — 13 bytes.
    reg [7:0] expected [0:N_EXPECTED-1];
    integer ei = 0;
    initial begin
        expected[0]  = 8'h48; expected[1]  = 8'h65; expected[2]  = 8'h6C;
        expected[3]  = 8'h6C; expected[4]  = 8'h6F;                       // "Hello"
        expected[5]  = 8'h2C; expected[6]  = 8'h20;                       // ", "
        expected[7]  = 8'h52; expected[8]  = 8'h56; expected[9]  = 8'h33;
        expected[10] = 8'h32;                                             // "RV32"
        expected[11] = 8'h21; expected[12] = 8'h0A;                       // "!\n"
    end

    reg  clk        = 1'b0;
    reg  rst_n      = 1'b0;
    reg  sim_active = 1'b1;
    wire uart_tx_w;

    wire [31:0] dbg_pc, dbg_instr, dbg_reg_wdata;
    wire        dbg_reg_we;
    wire [4:0]  dbg_reg_waddr;
    reg         halted = 1'b0;

    integer captured_count = 0;
    reg [7:0] captured_last = 8'b0;

    riscv_soc #(
        .CLKS_PER_BIT(CLKS_PER_BIT),
        .IMEM_INIT  ("../programs/prog_hello.hex")
    ) dut (
        .clk_50mhz   (clk),
        .rst_n       (rst_n),
        .uart_rx_in  (1'b1),
        .uart_tx_out (uart_tx_w),
        .dbg_pc      (dbg_pc),
        .dbg_instr   (dbg_instr),
        .dbg_reg_we  (dbg_reg_we),
        .dbg_reg_waddr(dbg_reg_waddr),
        .dbg_reg_wdata(dbg_reg_wdata)
    );

    initial begin
        $dumpfile(`FST_OUT);
        $dumpvars(0, tb_riscv_soc);
    end

    always #(CLK_PERIOD/2.0) if (sim_active) clk = ~clk;

    // Halt detector — falling edge to match CPU regfile commit timing.
    always @(negedge clk) begin
        if (dbg_instr == HALT_INSTR) halted <= 1'b1;
    end

    // UART sampler — same protocol as the VHDL twin.
    integer bit_idx = 0;
    reg [7:0] byte_v = 8'b0;
    initial begin : sampler
        // Wait until reset releases AND line is idle.
        wait (rst_n == 1'b1);
        #(2 * CLK_PERIOD);

        while (captured_count < N_EXPECTED) begin
            // Wait for start bit (falling edge).
            @(negedge uart_tx_w);

            // Skip past start bit + half-bit so we land at bit-0 centre.
            #(BIT_TIME + BIT_TIME/2);

            // Sample 8 data bits LSB first.
            byte_v = 8'b0;
            for (bit_idx = 0; bit_idx < 8; bit_idx = bit_idx + 1) begin
                byte_v[bit_idx] = uart_tx_w;
                #(BIT_TIME);
            end

            captured_last = byte_v;
            if (byte_v !== expected[captured_count]) begin
                $display("UART byte %0d: expected %h got %h",
                         captured_count, expected[captured_count], byte_v);
                $fatal(1, "uart byte mismatch");
            end
            captured_count = captured_count + 1;
        end
    end

    // Driver: release reset, run until halt + full string OR timeout.
    integer cycle_count = 0;
    initial begin
        #(2 * CLK_PERIOD) rst_n = 1'b1;

        while ((!halted || captured_count < N_EXPECTED)
               && cycle_count < MAX_CYCLES) begin
            @(posedge clk);
            cycle_count = cycle_count + 1;
        end

        if (!halted)
            $fatal(1, "Timeout: CPU did not halt within %0d cycles", MAX_CYCLES);
        if (captured_count != N_EXPECTED)
            $fatal(1, "Captured %0d of %0d expected bytes",
                   captured_count, N_EXPECTED);

        $display("tb_riscv_soc simulation done!");
        sim_active = 1'b0;
        $finish;
    end

endmodule

`default_nettype wire
