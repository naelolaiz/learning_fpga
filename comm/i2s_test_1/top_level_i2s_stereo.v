// top_level_i2s_stereo.v - Verilog mirror of top_level_i2s_stereo.vhd.
//
// Two-tone I2S source: separate NCO per channel, separate phase
// increment per channel. Defaults: 440 Hz / 450 Hz at 96 kHz Fs
// (10 Hz beat in mono mix; clear separation through stereo).

module top_level_i2s_stereo #(
    parameter integer PHASE_INC_LEFT  = 19_685_266,    // 440 Hz @ 96 kHz Fs
    parameter integer PHASE_INC_RIGHT = 20_132_659     // 450 Hz @ 96 kHz Fs
) (
    input  wire iReset,
    input  wire iClock50Mhz,
    output wire oMasterClock,
    output wire oLeftRightClock,
    output wire oSerialBitClock,
    output wire oData
);

    wire [15:0] sSineNumberL;           // signed
    wire [15:0] sSineNumberR;           // signed
    wire [23:0] mySignalL = {sSineNumberL, 8'h00};
    wire [23:0] mySignalR = {sSineNumberR, 8'h00};
    wire        sLeftRight;

    nco_sine nco_l (
        .clk       (sLeftRight),
        .reset     (iReset),
        .phase_inc (PHASE_INC_LEFT[31:0]),
        .sin_out   (sSineNumberL)
    );

    nco_sine nco_r (
        .clk       (sLeftRight),
        .reset     (iReset),
        .phase_inc (PHASE_INC_RIGHT[31:0]),
        .sin_out   (sSineNumberR)
    );

    i2s_master #(
        .CLK_FREQ      (50_000_000),
        .MCLK_FREQ     (24_576_000),
        .I2S_BIT_WIDTH (24)
    ) i2s (
        .reset  (iReset),
        .clk    (iClock50Mhz),
        .mclk   (oMasterClock),
        .lrclk  (sLeftRight),
        .sclk   (oSerialBitClock),
        .sdata  (oData),
        .data_l (mySignalL),
        .data_r (mySignalR)
    );

    assign oLeftRightClock = sLeftRight;

endmodule
