// tb_top_level_uda1380.v - Verilog mirror of tb_top_level_uda1380.vhd.
//
// Drives top_level_uda1380_core with a behavioural I2C slave standing
// in for the codec and checks the boot sequence on the bus: every
// byte the codec receives matches `expected` (the same stream the
// VHDL testbench uses), each write is framed by its own START and
// STOP, oInitDone rises and the I2S clocks run.
//
// The bus is plain 0 / 1 (no pull1 / z), so it dumps cleanly. The
// inout top is in V_SRC_FILES so it is compiled; the runtime
// hierarchy is the core.

`timescale 1ns/1ps

module tb_top_level_uda1380;

    localparam time CLK_PERIOD = 20;            // 50 MHz

    localparam integer EXPECTED_WRITES = 15;
    localparam integer EXPECTED_BYTES  = EXPECTED_WRITES * 3;
    localparam [6:0]   DEVICE_ADDR_TB  = 7'h18;

    // What the codec must receive: {register, data high, data low}
    // per write, in boot order.
    reg [23:0] expected [0:EXPECTED_WRITES-1];
    initial begin
        expected[ 0] = 24'h7F_00_00;  // L3 reset
        expected[ 1] = 24'h02_A5_DF;  // power: enable all
        expected[ 2] = 24'h00_0F_39;  // evalclk: WSPLL, all clocks on
        expected[ 3] = 24'h01_00_00;  // I2S: bus, digital mixer, BCK0 slave
        expected[ 4] = 24'h03_00_00;  // analog mixer input gain
        expected[ 5] = 24'h04_02_02;  // headamp: short-circuit protection on
        expected[ 6] = 24'h10_00_00;  // master volume: full
        expected[ 7] = 24'h11_00_00;  // mixer volume: full both channels
        expected[ 8] = 24'h12_55_15;  // mode/treble/bass: flat
        expected[ 9] = 24'h13_00_00;  // mute/de-emph: disable
        expected[10] = 24'h14_00_00;  // mixer SDO: off
        expected[11] = 24'h20_00_00;  // ADC decimator volume: max
        expected[12] = 24'h21_00_00;  // PGA: no mute, full gain
        expected[13] = 24'h22_0F_02;  // ADC: select line-in + mic, max gain
        expected[14] = 24'h23_00_00;  // AGC: settings
    end

    reg  iClk     = 1'b0;
    reg  iNoReset = 1'b0;                       // active-low; '0' = reset

    // Open-drain bus: a device drives *_oe=1 to pull a line low, and
    // a line nobody pulls is high.
    wire scl_oe;
    wire sda_oe;
    wire codec_scl_oe;
    wire codec_sda_oe;
    wire scl = ~(scl_oe | codec_scl_oe);
    wire sda = ~(sda_oe | codec_sda_oe);

    wire oTxMasterClock;
    wire oTxWordSelectClock;
    wire oTxBitClock;
    wire oTxSerialData;
    wire oInitDone;

    // Taps from the codec stand-in.
    wire [31:0] starts;
    wire [31:0] stops;
    wire [31:0] rx_count;
    wire [7:0]  rx_data;

    reg sim_active = 1'b1;

    integer mclk_edges = 0;
    integer bclk_edges = 0;
    integer lrclk_edges= 0;

    // Scratch for the byte check.
    integer   write_idx    = 0;
    reg [7:0] expected_now = 8'h00;

    top_level_uda1380_core #(
        .SYS_CLK_FREQ      (50_000_000),
        .I2C_BUS_FREQ      (5_000_000),
        .INIT_DELAY_CYCLES (4),
        .TONE_HALF_CYCLES  (4)
    ) dut (
        .iClk               (iClk),
        .iNoReset           (iNoReset),
        .oI2cSclOe          (scl_oe),
        .iI2cSclIn          (scl),
        .oI2cSdaOe          (sda_oe),
        .iI2cSdaIn          (sda),
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
        $dumpvars(1, tb_top_level_uda1380);
        $dumpvars(1, dut);
    end

    // Compare each byte as the codec receives it.
    always @(rx_count) begin
        if (rx_count > 0) begin
            if (rx_count > EXPECTED_BYTES)
                $fatal(1, "codec received more bytes than the boot sequence has");
            write_idx = (rx_count - 1) / 3;
            case ((rx_count - 1) % 3)
                0:       expected_now = expected[write_idx][23:16];
                1:       expected_now = expected[write_idx][15:8];
                default: expected_now = expected[write_idx][7:0];
            endcase
            if (rx_data !== expected_now)
                $fatal(1, "boot byte %0d differs from the expected stream: got %h expected %h",
                       rx_count - 1, rx_data, expected_now);
        end
    end

    always @(posedge oTxMasterClock) mclk_edges <= mclk_edges + 1;
    always @(posedge oTxBitClock)    bclk_edges <= bclk_edges + 1;
    always @(oTxWordSelectClock)     lrclk_edges<= lrclk_edges+ 1;

    initial begin : driver
        iNoReset = 1'b0;
        #(10*CLK_PERIOD);
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
        if (!(mclk_edges > 1000))
            $fatal(1, "MCLK barely moved: %0d rising edges", mclk_edges);
        if (!(bclk_edges > 100))
            $fatal(1, "BCK barely moved: %0d rising edges", bclk_edges);
        if (!(lrclk_edges > 4))
            $fatal(1, "LRCLK barely moved: %0d transitions", lrclk_edges);

        $display("uda1380 integration simulation done!");
        sim_active = 1'b0;
        $finish;
    end

endmodule
