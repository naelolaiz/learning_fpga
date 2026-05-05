// tb_top_level_uda1380.v - Verilog mirror of tb_top_level_uda1380.vhd.
//
// Drives top_level_uda1380_core directly (the (oe, i) split variant)
// so the bus signals dump as strong 1/0 instead of the weak-high
// pull1 / strong-0 mix that the inout top would produce. The inout
// top is in V_SRC_FILES so it elaboration-checks; only the
// runtime hierarchy is via the core.

`timescale 1ns/1ps

module tb_top_level_uda1380;

    localparam time CLK_PERIOD = 20;            // 50 MHz

    reg  iClk     = 1'b0;
    reg  iNoReset = 1'b0;                       // active-low; '0' = reset

    wire scl_oe;
    wire sda_oe;
    wire scl_i = scl_oe ? 1'b0 : 1'b1;
    wire sda_i = sda_oe ? 1'b0 : 1'b1;

    wire oTxMasterClock;
    wire oTxWordSelectClock;
    wire oTxBitClock;
    wire oTxSerialData;
    wire oInitDone;

    reg sim_active = 1'b1;

    integer scl_edges  = 0;
    integer mclk_edges = 0;
    integer bclk_edges = 0;
    integer lrclk_edges= 0;

    top_level_uda1380_core #(
        .SYS_CLK_FREQ      (50_000_000),
        .I2C_BUS_FREQ      (5_000_000),
        .INIT_DELAY_CYCLES (4),
        .TONE_HALF_CYCLES  (4)
    ) dut (
        .iClk               (iClk),
        .iNoReset           (iNoReset),
        .oI2cSclOe          (scl_oe),
        .iI2cSclIn          (scl_i),
        .oI2cSdaOe          (sda_oe),
        .iI2cSdaIn          (sda_i),
        .oTxMasterClock     (oTxMasterClock),
        .oTxWordSelectClock (oTxWordSelectClock),
        .oTxBitClock        (oTxBitClock),
        .oTxSerialData      (oTxSerialData),
        .oInitDone          (oInitDone)
    );

    always #(CLK_PERIOD/2) if (sim_active) iClk = ~iClk;

    initial begin
        $dumpfile(`FST_OUT);
        $dumpvars(1, tb_top_level_uda1380);
        $dumpvars(1, dut);
    end

    always @(scl_i)                  scl_edges  <= scl_edges  + 1;
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

        if (!(scl_edges > 100))
            $fatal(1, "I2C SCL barely moved: %0d transitions", scl_edges);
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
