// tb_top_level_uda1380_board.v - Verilog mirror of
// tb_top_level_uda1380_board.vhd.
//
// Runs the board top, top_level_uda1380, the way it is wired on the
// board: SCL and SDA are single inout wires with a pull-up (`tri1`),
// shared with the codec stand-in. Covers the two open-drain pins the
// wrapper adds; the byte-by-byte check lives in tb_top_level_uda1380.
//
// Asserts that the lines never show contention, that the boot sequence
// completes, that the codec received all 45 bytes in 15 separately
// framed writes, and that both lines end up released. No waveform is
// rendered, to match the VHDL twin.

`timescale 1ns/1ps

module tb_top_level_uda1380_board;

    localparam time    CLK_PERIOD      = 20;        // 50 MHz
    localparam integer EXPECTED_WRITES = 15;
    localparam integer EXPECTED_BYTES  = EXPECTED_WRITES * 3;
    localparam [6:0]   DEVICE_ADDR_TB  = 7'h18;

    reg  iClk     = 1'b0;
    reg  iNoReset = 1'b0;                       // active-low; '0' = reset

    // The two bus wires, each with a pull-up.
    tri1 scl;
    tri1 sda;

    // The codec stand-in's open-drain pins.
    wire codec_scl_oe;
    wire codec_sda_oe;
    assign scl = codec_scl_oe ? 1'b0 : 1'bz;
    assign sda = codec_sda_oe ? 1'b0 : 1'bz;

    wire oTxMasterClock;
    wire oTxWordSelectClock;
    wire oTxBitClock;
    wire oTxSerialData;
    wire oInitDone;

    wire [31:0] starts;
    wire [31:0] stops;
    wire [31:0] rx_count;
    wire [7:0]  rx_data;

    reg sim_active = 1'b1;

    top_level_uda1380 #(
        .SYS_CLK_FREQ      (50_000_000),
        .I2C_BUS_FREQ      (5_000_000),
        .INIT_DELAY_CYCLES (4),
        .TONE_HALF_CYCLES  (4)
    ) dut (
        .iClk               (iClk),
        .iNoReset           (iNoReset),
        .i2cIOScl           (scl),
        .i2cIOSda           (sda),
        .oTxMasterClock     (oTxMasterClock),
        .oTxWordSelectClock (oTxWordSelectClock),
        .oTxBitClock        (oTxBitClock),
        .oTxSerialData      (oTxSerialData),
        .oInitDone          (oInitDone)
    );

    i2c_slave_model #(
        .ADDR (DEVICE_ADDR_TB)
    ) codec (
        .scl      (scl),
        .sda      (sda),
        .stretch  (1'b0),
        .scl_oe   (codec_scl_oe),
        .sda_oe   (codec_sda_oe),
        .starts   (starts),
        .stops    (stops),
        .rx_count (rx_count),
        .rx_data  (rx_data)
    );

    always #(CLK_PERIOD/2) if (sim_active) iClk = ~iClk;

    initial begin
        $dumpfile(`FST_OUT);
        $dumpvars(1, tb_top_level_uda1380_board);
    end

    // Two devices fighting over a line (one driving 1, the other 0)
    // resolve to x. On an open-drain bus that must never happen.
    always @(scl or sda) begin
        if ($time > 0 && (scl === 1'bx || sda === 1'bx))
            $fatal(1, "bus contention: a device is driving a line high");
    end

    initial begin : driver
        iNoReset = 1'b0;
        #(10*CLK_PERIOD);

        if (scl !== 1'b1 || sda !== 1'b1)
            $fatal(1, "bus should rest on the pull-ups while in reset");

        iNoReset = 1'b1;

        fork : wait_done
            begin
                wait (oInitDone == 1'b1);
                disable wait_done;
            end
            begin
                #1_000_000;
                $fatal(1, "oInitDone never asserted");
            end
        join

        if (rx_count != EXPECTED_BYTES)
            $fatal(1, "codec received %0d bytes, expected %0d", rx_count, EXPECTED_BYTES);
        if (starts != EXPECTED_WRITES || stops != EXPECTED_WRITES)
            $fatal(1, "expected one START and one STOP per register write, got %0d / %0d",
                   starts, stops);
        if (scl !== 1'b1 || sda !== 1'b1)
            $fatal(1, "bus not released after the boot sequence");

        $display("uda1380 board-top simulation done!");
        sim_active = 1'b0;
        $finish;
    end

endmodule
