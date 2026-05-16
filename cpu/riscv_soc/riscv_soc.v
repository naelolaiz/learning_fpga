// riscv_soc.v - Verilog mirror of riscv_soc.vhd.
//
// CPU + 4 KB DMEM + memory-mapped UART (TX + RX). Address decode:
//   addr[31] = 1 → MMIO   ; addr[2] selects TX (0) vs RX (4)
//   addr[31] = 0 → DMEM   ; addr[11:2] indexes the 1024-word array
//
// See the VHDL twin for the address map, read-mux behaviour, and
// the RX-latch / TX-busy semantics.

`default_nettype none
`timescale 1ns/1ps

module riscv_soc #(
    parameter integer CLKS_PER_BIT = 5208,
    parameter         IMEM_INIT    = ""
) (
    input  wire        clk_50mhz,
    input  wire        rst_n,
    input  wire        uart_rx_in,
    output wire        uart_tx_out,

    output wire [31:0] dbg_pc,
    output wire [31:0] dbg_instr,
    output wire        dbg_reg_we,
    output wire [4:0]  dbg_reg_waddr,
    output wire [31:0] dbg_reg_wdata
);

    wire rst = ~rst_n;

    // CPU's external DMEM bus.
    wire [31:0] cpu_dmem_addr;
    wire [31:0] cpu_dmem_wdata;
    wire        cpu_dmem_we;
    wire        cpu_dmem_re;
    reg  [31:0] cpu_dmem_rdata = 32'b0;

    // ---------------------------------------------------------------
    // CPU
    // ---------------------------------------------------------------
    riscv_singlecycle #(
        .IMEM_ADDR_W(10),
        .IMEM_INIT  (IMEM_INIT)
    ) cpu (
        .clk(clk_50mhz),
        .rst(rst),
        .dmem_addr (cpu_dmem_addr),
        .dmem_wdata(cpu_dmem_wdata),
        .dmem_we   (cpu_dmem_we),
        .dmem_re   (cpu_dmem_re),
        .dmem_rdata(cpu_dmem_rdata),
        .dbg_pc       (dbg_pc),
        .dbg_instr    (dbg_instr),
        .dbg_reg_we   (dbg_reg_we),
        .dbg_reg_waddr(dbg_reg_waddr),
        .dbg_reg_wdata(dbg_reg_wdata)
    );

    // ---------------------------------------------------------------
    // Address decoder
    // ---------------------------------------------------------------
    wire        is_mmio   = cpu_dmem_addr[31];
    wire        dmem_we_q = cpu_dmem_we & ~is_mmio;
    wire        mmio_we   = cpu_dmem_we &  is_mmio;
    wire [5:0]  mmio_word = cpu_dmem_addr[7:2];

    // ---------------------------------------------------------------
    // DMEM — 1024 × 32-bit, sync write, async read
    // ---------------------------------------------------------------
    localparam integer DMEM_DEPTH = 1024;
    reg [31:0] dmem [0:DMEM_DEPTH-1];
    integer k;
    initial for (k = 0; k < DMEM_DEPTH; k = k + 1) dmem[k] = 32'b0;

    wire [9:0] dmem_word_addr = cpu_dmem_addr[11:2];
    always @(posedge clk_50mhz) begin
        if (dmem_we_q) dmem[dmem_word_addr] <= cpu_dmem_wdata;
    end
    wire [31:0] dmem_rdata = dmem[dmem_word_addr];

    // ---------------------------------------------------------------
    // UART TX peripheral: write to 0x8000_0000 sends LSB byte
    // ---------------------------------------------------------------
    wire        uart_tx_busy;
    reg         uart_tx_start = 1'b0;
    reg  [7:0]  uart_tx_data  = 8'b0;

    always @(posedge clk_50mhz) begin
        uart_tx_start <= 1'b0;  // default; one-clock pulse
        if (rst) begin
            uart_tx_data <= 8'b0;
        end else if (mmio_we && mmio_word == 6'd0 && !uart_tx_busy) begin
            uart_tx_data  <= cpu_dmem_wdata[7:0];
            uart_tx_start <= 1'b1;
        end
    end

    uart_tx #(.CLKS_PER_BIT(CLKS_PER_BIT)) tx (
        .clk(clk_50mhz),
        .tx_start(uart_tx_start),
        .tx_data (uart_tx_data),
        .tx      (uart_tx_out),
        .tx_busy (uart_tx_busy)
    );

    // ---------------------------------------------------------------
    // UART RX peripheral: latch + drain on read of 0x8000_0004
    // ---------------------------------------------------------------
    wire [7:0]  uart_rx_data;
    wire        uart_rx_valid;
    reg  [7:0]  rx_byte_latch  = 8'b0;
    reg         rx_ready_latch = 1'b0;
    wire        rx_read_pulse  = cpu_dmem_re && is_mmio && mmio_word == 6'd1;

    uart_rx #(.CLKS_PER_BIT(CLKS_PER_BIT)) rx (
        .clk(clk_50mhz),
        .rx       (uart_rx_in),
        .rx_data  (uart_rx_data),
        .rx_valid (uart_rx_valid)
    );

    always @(posedge clk_50mhz) begin
        if (rst) begin
            rx_byte_latch  <= 8'b0;
            rx_ready_latch <= 1'b0;
        end else if (uart_rx_valid) begin
            // Overwrite the latch even if previous byte unread.
            rx_byte_latch  <= uart_rx_data;
            rx_ready_latch <= 1'b1;
        end else if (rx_read_pulse) begin
            rx_ready_latch <= 1'b0;
        end
    end

    // ---------------------------------------------------------------
    // SIMD accelerator (combinational result) + its write path
    // ---------------------------------------------------------------
    reg  [31:0] simd_a   = 32'b0;
    reg  [31:0] simd_b   = 32'b0;
    reg  [3:0]  simd_op  = 4'b0;
    wire [31:0] simd_result;
    wire [3:0]  simd_flags;

    simd_alu simd (
        .a(simd_a), .b(simd_b), .op(simd_op),
        .result(simd_result), .flags(simd_flags)
    );

    always @(posedge clk_50mhz) begin
        if (rst) begin
            simd_a  <= 32'b0;
            simd_b  <= 32'b0;
            simd_op <= 4'b0;
        end else if (mmio_we) begin
            case (mmio_word)
                6'd12:   simd_a  <= cpu_dmem_wdata;            // 0x30
                6'd13:   simd_b  <= cpu_dmem_wdata;            // 0x34
                6'd14:   simd_op <= cpu_dmem_wdata[3:0];       // 0x38
                default: ;
            endcase
        end
    end

    // ---------------------------------------------------------------
    // FIR accelerator + its write path + result latch
    // ---------------------------------------------------------------
    reg  [8:0]  fir_coeff_0      = 9'b0;
    reg  [8:0]  fir_coeff_1      = 9'b0;
    reg  [8:0]  fir_coeff_2      = 9'b0;
    reg  [8:0]  fir_coeff_3      = 9'b0;
    reg  [15:0] fir_sample_data  = 16'b0;
    reg         fir_sample_pulse = 1'b0;
    wire signed [15:0] fir_result;
    wire        fir_result_valid;
    reg  [15:0] fir_result_latch = 16'b0;
    reg         fir_ready_latch  = 1'b0;

    fir4tap fir (
        .clk(clk_50mhz),
        .rst(rst),
        .coeff_0(fir_coeff_0), .coeff_1(fir_coeff_1),
        .coeff_2(fir_coeff_2), .coeff_3(fir_coeff_3),
        .sample_in(fir_sample_data),
        .sample_valid(fir_sample_pulse),
        .result(fir_result),
        .result_valid(fir_result_valid)
    );

    always @(posedge clk_50mhz) begin
        fir_sample_pulse <= 1'b0;
        if (rst) begin
            fir_coeff_0     <= 9'b0;
            fir_coeff_1     <= 9'b0;
            fir_coeff_2     <= 9'b0;
            fir_coeff_3     <= 9'b0;
            fir_sample_data <= 16'b0;
        end else if (mmio_we) begin
            case (mmio_word)
                6'd20: begin                                    // 0x50 coeffs 0,1
                    fir_coeff_0 <= cpu_dmem_wdata[8:0];
                    fir_coeff_1 <= cpu_dmem_wdata[24:16];
                end
                6'd21: begin                                    // 0x54 coeffs 2,3
                    fir_coeff_2 <= cpu_dmem_wdata[8:0];
                    fir_coeff_3 <= cpu_dmem_wdata[24:16];
                end
                6'd22: begin                                    // 0x58 sample
                    fir_sample_data  <= cpu_dmem_wdata[15:0];
                    fir_sample_pulse <= 1'b1;
                end
                default: ;
            endcase
        end
    end

    wire fir_read_result = cpu_dmem_re && is_mmio && (mmio_word == 6'd23);
    always @(posedge clk_50mhz) begin
        if (rst) begin
            fir_result_latch <= 16'b0;
            fir_ready_latch  <= 1'b0;
        end else if (fir_result_valid) begin
            fir_result_latch <= fir_result;
            fir_ready_latch  <= 1'b1;
        end else if (fir_read_result) begin
            fir_ready_latch  <= 1'b0;
        end
    end

    // ---------------------------------------------------------------
    // Read mux
    // ---------------------------------------------------------------
    always @(*) begin
        if (is_mmio && mmio_word == 6'd0)                       // 0x00 UART_TX
            cpu_dmem_rdata = {31'b0, uart_tx_busy};
        else if (is_mmio && mmio_word == 6'd1)                  // 0x04 UART_RX
            cpu_dmem_rdata = {rx_ready_latch, 23'b0, rx_byte_latch};
        else if (is_mmio && mmio_word == 6'd15)                 // 0x3C SIMD_RESULT
            cpu_dmem_rdata = simd_result;
        else if (is_mmio && mmio_word == 6'd16)                 // 0x40 SIMD_FLAGS
            cpu_dmem_rdata = {28'b0, simd_flags};
        else if (is_mmio && mmio_word == 6'd23)                 // 0x5C FIR_RESULT
            cpu_dmem_rdata = {{16{fir_result_latch[15]}}, fir_result_latch};
        else if (is_mmio && mmio_word == 6'd24)                 // 0x60 FIR_STATUS
            cpu_dmem_rdata = {31'b0, fir_ready_latch};
        else
            cpu_dmem_rdata = dmem_rdata;
    end

endmodule

`default_nettype wire
