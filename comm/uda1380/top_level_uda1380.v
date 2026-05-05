// top_level_uda1380.v - Verilog mirror of top_level_uda1380.vhd.
//
// Same architecture: init_fsm + i2c_master + i2s_master + tone_gen,
// open-drain SCL/SDA, active-low reset on the entity port (inverted
// internally to active-high for every sub-block).

module top_level_uda1380 #(
    parameter integer SYS_CLK_FREQ      = 50_000_000,
    parameter integer I2C_BUS_FREQ      = 100_000,
    parameter integer INIT_DELAY_CYCLES = 5_000_000,
    parameter integer TONE_HALF_CYCLES  = 96
) (
    input  wire iClk,
    input  wire iNoReset,                     // active-low
    inout  wire i2cIOScl,
    inout  wire i2cIOSda,
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

    i2c_master #(
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
        .sda       (i2cIOSda),
        .scl       (i2cIOScl)
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
