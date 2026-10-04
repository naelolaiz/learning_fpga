// top_level_uda1380.v - Verilog mirror of top_level_uda1380.vhd.
//
// Board top: top_level_uda1380_core plus the two open-drain I2C pins.
// Each (oe, i) pair of the core becomes one inout: drive 0 when the
// enable is high, otherwise let go (z) and let the bus pull-up
// resistor raise the line. The pin itself is the read-back.
//
// Guarded with `ifndef YOSYS` (yosys-specific macro) rather than
// the more generic `SYNTHESIS`. Quartus / Vivado also define
// `SYNTHESIS` when compiling for the board, but we WANT them to see
// this wrapper — tri-state is the real I/O behaviour on the chip. We
// only want to hide it from yosys, where tri-state has limited
// support and the diagram flow renders the core instead. yosys
// auto-defines `YOSYS`; iverilog and the FPGA synth tools don't, so
// simulation and board synthesis both pick up the module normally.

`ifndef YOSYS

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

    wire scl_oe;
    wire sda_oe;

    top_level_uda1380_core #(
        .SYS_CLK_FREQ      (SYS_CLK_FREQ),
        .I2C_BUS_FREQ      (I2C_BUS_FREQ),
        .INIT_DELAY_CYCLES (INIT_DELAY_CYCLES),
        .TONE_HALF_CYCLES  (TONE_HALF_CYCLES)
    ) core (
        .iClk               (iClk),
        .iNoReset           (iNoReset),
        .oI2cSclOe          (scl_oe),
        .iI2cSclIn          (i2cIOScl),
        .oI2cSdaOe          (sda_oe),
        .iI2cSdaIn          (i2cIOSda),
        .oTxMasterClock     (oTxMasterClock),
        .oTxWordSelectClock (oTxWordSelectClock),
        .oTxBitClock        (oTxBitClock),
        .oTxSerialData      (oTxSerialData),
        .oInitDone          (oInitDone)
    );

    assign i2cIOScl = scl_oe ? 1'b0 : 1'bz;
    assign i2cIOSda = sda_oe ? 1'b0 : 1'bz;

endmodule

`endif  // YOSYS
