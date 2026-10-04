// tb_uda1380_init_fsm.v - Verilog mirror of tb_uda1380_init_fsm.vhd.
//
// Stubs i2c_master's command interface and asserts, for every byte
// the stub accepts:
//   * the first byte of each group of four carries cmd_start and is
//     {DEVICE_ADDR (7'h18), 1'b0} (a write);
//   * the last byte of the group carries cmd_stop;
//   * the two bytes in between carry neither.
// At the end: byte count = 15 register writes * 4 bytes = 60, and
// init_done only rises once the bus is idle again.

`timescale 1ns/1ps

module tb_uda1380_init_fsm;

    localparam time CLK_PERIOD = 20;            // 50 MHz
    localparam integer INIT_DELAY_CYCLES_TB = 4;
    localparam integer BYTE_TIME           = 10 * 20;   // stub's "byte on the wire"
    localparam integer EXPECTED_TABLE_LEN  = 15;
    localparam integer EXPECTED_BYTES      = EXPECTED_TABLE_LEN * 4;
    localparam [6:0]   DEVICE_ADDR_TB      = 7'h18;

    reg         clk       = 1'b0;
    reg         reset     = 1'b1;
    wire        cmd_valid;
    wire        cmd_start;
    wire        cmd_stop;
    wire [7:0]  cmd_wdata;
    reg         cmd_ready = 1'b0;
    reg         i2c_busy  = 1'b0;
    wire        init_done;

    reg sim_active = 1'b1;

    // Bytes accepted by the stub so far.
    integer bytes_observed = 0;
    reg     stop_seen      = 1'b0;

    uda1380_init_fsm #(
        .INIT_DELAY_CYCLES (INIT_DELAY_CYCLES_TB)
    ) dut (
        .clk       (clk),
        .reset     (reset),
        .cmd_valid (cmd_valid),
        .cmd_start (cmd_start),
        .cmd_stop  (cmd_stop),
        .cmd_wdata (cmd_wdata),
        .cmd_ready (cmd_ready),
        .i2c_busy  (i2c_busy),
        .init_done (init_done)
    );

    always #(CLK_PERIOD/2) if (sim_active) clk = ~clk;

    initial begin
        $dumpfile(`FST_OUT);
        $dumpvars(1, tb_uda1380_init_fsm);
        $dumpvars(1, dut);
    end

    // Stub i2c_master: ready for a command, accept it on the clock
    // edge where cmd_valid is high, stay busy for a "byte time", and
    // after a byte flagged cmd_stop stay busy a little longer for the
    // STOP before reporting the bus idle. The #1 after the edge keeps
    // the stub's changes clear of the edge the DUT samples on.
    initial begin : i2c_stub
        forever begin
            cmd_ready = 1'b1;
            @(posedge clk);
            while (cmd_valid !== 1'b1) @(posedge clk);

            if (bytes_observed % 4 == 0) begin
                if (cmd_start !== 1'b1)
                    $fatal(1, "first byte of a register write must carry cmd_start");
                if (cmd_wdata !== {DEVICE_ADDR_TB, 1'b0})
                    $fatal(1, "first byte must be DEVICE_ADDR with the write bit: %h", cmd_wdata);
            end else if (cmd_start !== 1'b0) begin
                $fatal(1, "cmd_start on a byte that is not the address");
            end
            if (bytes_observed % 4 == 3) begin
                if (cmd_stop !== 1'b1)
                    $fatal(1, "last byte of a register write must carry cmd_stop");
            end else if (cmd_stop !== 1'b0) begin
                $fatal(1, "cmd_stop before the last byte of a register write");
            end

            stop_seen      = cmd_stop;
            bytes_observed = bytes_observed + 1;

            #1;
            cmd_ready = 1'b0;
            i2c_busy  = 1'b1;
            #(BYTE_TIME);
            if (stop_seen) begin
                #(BYTE_TIME);       // the STOP condition
                i2c_busy = 1'b0;
            end
        end
    end

    // init_done must not rise while the last transaction is on the bus.
    always @(posedge init_done) begin
        if (i2c_busy !== 1'b0)
            $fatal(1, "init_done rose while the bus was still busy");
    end

    initial begin : driver
        reset = 1'b1;
        #(10*CLK_PERIOD);
        reset = 1'b0;

        // Wait for init_done with a generous timeout.
        fork : wait_done
            begin
                wait (init_done == 1'b1);
                disable wait_done;
            end
            begin
                #200_000;
                $fatal(1, "init_done never asserted");
            end
        join

        if (bytes_observed != EXPECTED_BYTES)
            $fatal(1, "byte count mismatch: got %0d expected %0d",
                   bytes_observed, EXPECTED_BYTES);

        $display("uda1380_init_fsm simulation done!");
        sim_active = 1'b0;
        $finish;
    end

endmodule
