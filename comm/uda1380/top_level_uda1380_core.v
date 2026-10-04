// top_level_uda1380_core.v - Verilog mirror of top_level_uda1380_core.vhd.
//
// init_fsm + i2c_master (comm/i2c_master) + i2s_master + tone_gen.
// The I2C bus leaves this module as (oe, i) pairs instead of inout,
// so the hierarchy has no tristates: it simulates with plain 0 / 1
// levels and netlistsvg can render it. top_level_uda1380.v wraps
// this core and adds the two open-drain pins for the board.

module top_level_uda1380_core #(
    parameter integer SYS_CLK_FREQ      = 50_000_000,
    parameter integer I2C_BUS_FREQ      = 100_000,
    parameter integer INIT_DELAY_CYCLES = 5_000_000,
    parameter integer TONE_HALF_CYCLES  = 96
) (
    input  wire iClk,
    input  wire iNoReset,                     // active-low
    output wire oI2cSclOe,
    input  wire iI2cSclIn,
    output wire oI2cSdaOe,
    input  wire iI2cSdaIn,
    output wire oTxMasterClock,
    output wire oTxWordSelectClock,
    output wire oTxBitClock,
    output wire oTxSerialData,
    output wire oInitDone
);

    wire reset_h = ~iNoReset;

    wire        cmd_valid;
    wire        cmd_start;
    wire        cmd_stop;
    wire [7:0]  cmd_wdata;
    wire        cmd_ready;
    wire        i2c_busy;

    wire [23:0] sample_24;
    wire        lrclk_int;

    uda1380_init_fsm #(
        .INIT_DELAY_CYCLES (INIT_DELAY_CYCLES)
    ) init_fsm (
        .clk       (iClk),
        .reset     (reset_h),
        .cmd_valid (cmd_valid),
        .cmd_start (cmd_start),
        .cmd_stop  (cmd_stop),
        .cmd_wdata (cmd_wdata),
        .cmd_ready (cmd_ready),
        .i2c_busy  (i2c_busy),
        .init_done (oInitDone)
    );

    // The master counts in quarters of an SCL period. The boot
    // sequence only writes, and it does not look at the acknowledge
    // bits, so the read flags are tied off and the response is left
    // unconnected.
    i2c_master #(
        .CLKS_PER_QUARTER (SYS_CLK_FREQ / (4 * I2C_BUS_FREQ))
    ) i2c_master_inst (
        .clk       (iClk),
        .rst       (reset_h),
        .cmd_valid (cmd_valid),
        .cmd_start (cmd_start),
        .cmd_stop  (cmd_stop),
        .cmd_read  (1'b0),
        .cmd_nack  (1'b0),
        .cmd_wdata (cmd_wdata),
        .cmd_ready (cmd_ready),
        .rsp_valid (),
        .rsp_rdata (),
        .rsp_nack  (),
        .busy      (i2c_busy),
        .scl_oe    (oI2cSclOe),
        .scl_i     (iI2cSclIn),
        .sda_oe    (oI2cSdaOe),
        .sda_i     (iI2cSdaIn)
    );

    i2s_master #(
        .CLK_FREQ      (SYS_CLK_FREQ),
        .MCLK_FREQ     (24_576_000),
        .I2S_BIT_WIDTH (24)
    ) i2s_master_inst (
        .reset  (reset_h),
        .clk    (iClk),
        .mclk   (oTxMasterClock),
        .lrclk  (lrclk_int),
        .sclk   (oTxBitClock),
        .sdata  (oTxSerialData),
        .data_l (sample_24),
        .data_r (sample_24)
    );

    assign oTxWordSelectClock = lrclk_int;

    tone_gen #(
        .TOGGLE_HALF_CYCLES (TONE_HALF_CYCLES)
    ) tone (
        .clk    (lrclk_int),
        .reset  (reset_h),
        .sample (sample_24)
    );

endmodule
