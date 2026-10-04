// tb_i2c_master.v - Verilog mirror of tb_i2c_master.vhd.
//
// Puts i2c_master on a two-wire bus with a behavioural slave and
// checks what actually travels over the wires: a framed, acknowledged
// write; a read-back through a repeated START; an unanswered address;
// and the same write / read-back with the slave stretching the clock.

`timescale 1ns/1ps

module tb_i2c_master;

    localparam integer CLKS_PER_QUARTER = 4;
    localparam time    CLK_PERIOD       = 20;          // 50 MHz
    localparam time    QUARTER          = CLKS_PER_QUARTER * CLK_PERIOD;
    localparam integer STRETCH_TIME     = 6 * CLKS_PER_QUARTER * 20;

    localparam [6:0] SLAVE_ADDR = 7'b1010000;          // 0x50
    localparam [6:0] OTHER_ADDR = 7'b1010001;          // nobody there

    reg        sClk      = 1'b0;
    reg        sRst      = 1'b1;

    reg        sCmdValid = 1'b0;
    reg        sCmdStart = 1'b0;
    reg        sCmdStop  = 1'b0;
    reg        sCmdRead  = 1'b0;
    reg        sCmdNack  = 1'b0;
    reg  [7:0] sCmdWdata = 8'h00;
    wire       sCmdReady;
    wire       sRspValid;
    wire [7:0] sRspRdata;
    wire       sRspNack;
    wire       sBusy;

    // The bus. Each device can only pull a line low; a line nobody
    // pulls is high.
    wire       sMasterSclOe;
    wire       sMasterSdaOe;
    wire       sSlaveSclOe;
    wire       sSlaveSdaOe;
    wire       sScl = ~(sMasterSclOe | sSlaveSclOe);
    wire       sSda = ~(sMasterSdaOe | sSlaveSdaOe);

    reg        sStretch = 1'b0;
    wire [31:0] sStarts;
    wire [31:0] sStops;
    wire [31:0] sRxCount;
    wire [7:0]  sRxData;

    // SCL low times at least STRETCH_TIME long.
    integer    sStretchedLows = 0;
    time       last_edge      = 0;

    reg        sSimulationActive = 1'b1;

    i2c_master #(.CLKS_PER_QUARTER(CLKS_PER_QUARTER)) dut (
        .clk       (sClk),
        .rst       (sRst),
        .cmd_valid (sCmdValid),
        .cmd_start (sCmdStart),
        .cmd_stop  (sCmdStop),
        .cmd_read  (sCmdRead),
        .cmd_nack  (sCmdNack),
        .cmd_wdata (sCmdWdata),
        .cmd_ready (sCmdReady),
        .rsp_valid (sRspValid),
        .rsp_rdata (sRspRdata),
        .rsp_nack  (sRspNack),
        .busy      (sBusy),
        .scl_oe    (sMasterSclOe),
        .scl_i     (sScl),
        .sda_oe    (sMasterSdaOe),
        .sda_i     (sSda)
    );

    i2c_slave_model #(
        .ADDR         (SLAVE_ADDR),
        .STRETCH_TIME (STRETCH_TIME)
    ) slave (
        .scl      (sScl),
        .sda      (sSda),
        .stretch  (sStretch),
        .scl_oe   (sSlaveSclOe),
        .sda_oe   (sSlaveSdaOe),
        .starts   (sStarts),
        .stops    (sStops),
        .rx_count (sRxCount),
        .rx_data  (sRxData)
    );

    always #(CLK_PERIOD/2) if (sSimulationActive) sClk = ~sClk;

    initial begin
        $dumpfile(`FST_OUT);
        $dumpvars(1, tb_i2c_master);
        $dumpvars(1, dut);
    end

    // SCL may be slower than nominal (the synchroniser, clock
    // stretching, the gaps between bytes) but never faster: each high
    // and each low lasts at least two quarters.
    always @(sScl) begin
        if ($time > 0) begin
            if ($time - last_edge < 2 * QUARTER)
                $fatal(1, "SCL level shorter than half a period");
            if (sScl === 1'b1 && $time - last_edge >= STRETCH_TIME)
                sStretchedLows = sStretchedLows + 1;
            last_edge = $time;
        end
    end

    // One byte slot: hand over the command, then wait for its
    // response. The #1 after each clock edge keeps the driver's
    // changes clear of the edge the DUT samples on.
    task xfer(input start, input stop, input read, input nack,
              input [7:0] wdata);
        begin
            sCmdStart = start;
            sCmdStop  = stop;
            sCmdRead  = read;
            sCmdNack  = nack;
            sCmdWdata = wdata;
            sCmdValid = 1'b1;
            @(posedge sClk);
            while (sCmdReady !== 1'b1) @(posedge sClk);
            #1;
            sCmdValid = 1'b0;
            @(posedge sClk);
            while (sRspValid !== 1'b1) @(posedge sClk);
            #1;
        end
    endtask

    task wait_idle;
        begin
            while (sBusy !== 1'b0) @(posedge sClk);
            #1;
        end
    endtask

    initial begin : driver
        #(4*CLK_PERIOD);
        #1;
        sRst = 1'b0;
        #(2*CLK_PERIOD);
        if (sScl !== 1'b1 || sSda !== 1'b1) $fatal(1, "Bus should idle high");
        if (sBusy !== 1'b0) $fatal(1, "Master should idle not busy");

        // 1. Write 0xA5, 0x3C starting at pointer 0x10.
        xfer(1'b1, 1'b0, 1'b0, 1'b0, {SLAVE_ADDR, 1'b0});
        if (sRspNack !== 1'b0) $fatal(1, "Write address not acknowledged");
        xfer(1'b0, 1'b0, 1'b0, 1'b0, 8'h10);
        if (sRspNack !== 1'b0) $fatal(1, "Pointer byte not acknowledged");
        xfer(1'b0, 1'b0, 1'b0, 1'b0, 8'hA5);
        if (sRspNack !== 1'b0) $fatal(1, "First data byte not acknowledged");
        if (sRspRdata !== 8'hA5) $fatal(1, "Write did not read back its own byte");
        xfer(1'b0, 1'b1, 1'b0, 1'b0, 8'h3C);
        if (sRspNack !== 1'b0) $fatal(1, "Second data byte not acknowledged");
        wait_idle;
        if (sStarts != 1 || sStops != 1)
            $fatal(1, "Write should be framed by one START and one STOP");
        if (sRxCount != 3 || sRxData !== 8'h3C)
            $fatal(1, "Slave did not receive the three bytes");
        if (sScl !== 1'b1 || sSda !== 1'b1)
            $fatal(1, "Bus should be released after STOP");

        // 2. Read them back: set the pointer, repeated START, two reads.
        xfer(1'b1, 1'b0, 1'b0, 1'b0, {SLAVE_ADDR, 1'b0});
        xfer(1'b0, 1'b0, 1'b0, 1'b0, 8'h10);
        xfer(1'b1, 1'b0, 1'b0, 1'b0, {SLAVE_ADDR, 1'b1});
        if (sRspNack !== 1'b0) $fatal(1, "Read address not acknowledged");
        xfer(1'b0, 1'b0, 1'b1, 1'b0, 8'h00);
        if (sRspRdata !== 8'hA5) $fatal(1, "First byte read back wrong: %h", sRspRdata);
        if (sRspNack !== 1'b0) $fatal(1, "Master should acknowledge the first read");
        xfer(1'b0, 1'b1, 1'b1, 1'b1, 8'h00);
        if (sRspRdata !== 8'h3C) $fatal(1, "Second byte read back wrong: %h", sRspRdata);
        if (sRspNack !== 1'b1) $fatal(1, "Master should NACK the last read");
        wait_idle;
        if (sStarts != 3 || sStops != 2)
            $fatal(1, "Read should add a START, a repeated START and one STOP");

        // 3. Nobody answers at OTHER_ADDR.
        xfer(1'b1, 1'b1, 1'b0, 1'b0, {OTHER_ADDR, 1'b0});
        if (sRspNack !== 1'b1) $fatal(1, "Missing slave should read as NACK");
        wait_idle;
        if (sStarts != 4 || sStops != 3)
            $fatal(1, "Unanswered address should still be framed");
        if (sRxCount != 4)
            $fatal(1, "Slave must ignore a transfer addressed elsewhere");
        if (sStretchedLows != 0)
            $fatal(1, "No SCL low should reach the stretch length yet");

        // 4. The same write and read-back while the slave stretches SCL.
        sStretch = 1'b1;
        xfer(1'b1, 1'b0, 1'b0, 1'b0, {SLAVE_ADDR, 1'b0});
        xfer(1'b0, 1'b0, 1'b0, 1'b0, 8'h20);
        xfer(1'b0, 1'b1, 1'b0, 1'b0, 8'h5A);
        if (sRspNack !== 1'b0) $fatal(1, "Stretched write not acknowledged");
        wait_idle;
        if (sStretchedLows != 3)
            $fatal(1, "Expected one stretched SCL low per byte of the write, got %0d",
                   sStretchedLows);

        xfer(1'b1, 1'b0, 1'b0, 1'b0, {SLAVE_ADDR, 1'b0});
        xfer(1'b0, 1'b0, 1'b0, 1'b0, 8'h20);
        xfer(1'b1, 1'b0, 1'b0, 1'b0, {SLAVE_ADDR, 1'b1});
        xfer(1'b0, 1'b1, 1'b1, 1'b1, 8'h00);
        if (sRspRdata !== 8'h5A) $fatal(1, "Stretched read returned the wrong byte: %h", sRspRdata);
        wait_idle;
        if (sStretchedLows != 7)
            $fatal(1, "Expected one stretched SCL low per byte of the read-back, got %0d",
                   sStretchedLows);
        if (sStarts != 7 || sStops != 5)
            $fatal(1, "Unexpected START / STOP totals");

        $display("i2c_master simulation done!");
        sSimulationActive = 1'b0;
        $finish;
    end

endmodule
