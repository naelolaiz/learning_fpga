// top_level_uda1380_core.v
//
// Diagram-renderable mirror of top_level_uda1380.v: the I2C bus is
// split into (oe, i) pairs instead of inout. The simulation top
// wraps this core and resolves the inout pin against the external
// pull-up; netlistsvg can render this one because it has no inout.

module top_level_uda1380_core #(
    parameter integer SYS_CLK_FREQ      = 50_000_000,
    parameter integer I2C_BUS_FREQ      = 100_000,
    parameter integer INIT_DELAY_CYCLES = 5_000_000,
    parameter integer TONE_HALF_CYCLES  = 96
) (
    input  wire iClk,
    input  wire iNoReset,
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

    wire        i2c_ena;
    wire [6:0]  i2c_addr;
    wire        i2c_rw;
    wire [7:0]  i2c_data_wr;
    wire        i2c_busy;
    wire        i2c_ack_err;
    wire [7:0]  i2c_data_rd;

    wire [23:0] sample_24;
    wire        lrclk_int;

    uda1380_init_fsm #(
        .INIT_DELAY_CYCLES (INIT_DELAY_CYCLES)
    ) init_fsm (
        .clk         (iClk),
        .reset       (reset_h),
        .i2c_ena     (i2c_ena),
        .i2c_addr    (i2c_addr),
        .i2c_rw      (i2c_rw),
        .i2c_data_wr (i2c_data_wr),
        .i2c_busy    (i2c_busy),
        .i2c_ack_err (i2c_ack_err),
        .init_done   (oInitDone)
    );

    i2c_master_for_diagram #(
        .input_clk (SYS_CLK_FREQ),
        .bus_clk   (I2C_BUS_FREQ)
    ) i2c_master_inst (
        .clk       (iClk),
        .reset_n   (iNoReset),
        .ena       (i2c_ena),
        .addr      (i2c_addr),
        .rw        (i2c_rw),
        .data_wr   (i2c_data_wr),
        .busy      (i2c_busy),
        .data_rd   (i2c_data_rd),
        .ack_error (i2c_ack_err),
        .sda_oe    (oI2cSdaOe),
        .sda_i     (iI2cSdaIn),
        .scl_oe    (oI2cSclOe),
        .scl_i     (iI2cSclIn)
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
