// top_level_i2s_oscillator.v - Verilog mirror of
// top_level_i2s_oscillator.vhd.
//
// Mono single-tone I2S source: NCO ticks once per audio sample,
// signed 16-bit sine sign-extended (left-shifted by 8) into the
// 24-bit I2S frame the master serialises.
//
// Default phase increment: 1 kHz at 96 kHz Fs
//   PHASE_INC = round(1000 * 2**32 / 96000) = 44_739_242
// Both blocks use active-high reset.

module top_level_i2s_oscillator #(
    parameter integer PHASE_INC = 44_739_242
) (
    input  wire iReset,
    input  wire iClock50Mhz,
    output wire oMasterClock,
    output wire oLeftRightClock,        // word select (= Fs)
    output wire oSerialBitClock,        // BCK
    output wire oData                   // SDATA, MSB-first
);

    wire [15:0] sSineNumber;            // signed
    wire [23:0] mySignal = {sSineNumber, 8'h00};
    wire        sLeftRight;

    nco_sine nco (
        .clk       (sLeftRight),
        .reset     (iReset),
        .phase_inc (PHASE_INC[31:0]),
        .sin_out   (sSineNumber)
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
        .data_l (mySignal),
        .data_r (mySignal)
    );

    assign oLeftRightClock = sLeftRight;

endmodule
