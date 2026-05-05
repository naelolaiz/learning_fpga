// tb_uda1380_init_fsm.v - Verilog mirror of tb_uda1380_init_fsm.vhd.
//
// Stubs the i2c_master's busy handshake and asserts:
//   * Every byte transaction targets DEVICE_ADDR (7'h18) with rw=0.
//   * Total byte count = 15 register writes * 3 bytes = 45.
//   * init_done eventually rises.

`timescale 1ns/1ps

module tb_uda1380_init_fsm;

    localparam time CLK_PERIOD = 20;            // 50 MHz
    localparam integer INIT_DELAY_CYCLES_TB = 4;
    localparam integer EXPECTED_TABLE_LEN  = 15;
    localparam integer EXPECTED_BYTES      = EXPECTED_TABLE_LEN * 3;
    localparam [6:0]   DEVICE_ADDR_TB      = 7'h18;

    reg         clk         = 1'b0;
    reg         reset       = 1'b1;
    wire        i2c_ena;
    wire [6:0]  i2c_addr;
    wire        i2c_rw;
    wire [7:0]  i2c_data_wr;
    reg         i2c_busy    = 1'b0;
    reg         i2c_ack_err = 1'b0;
    wire        init_done;

    reg sim_active = 1'b1;
    integer bytes_observed = 0;

    uda1380_init_fsm #(
        .INIT_DELAY_CYCLES (INIT_DELAY_CYCLES_TB)
    ) dut (
        .clk         (clk),
        .reset       (reset),
        .i2c_ena     (i2c_ena),
        .i2c_addr    (i2c_addr),
        .i2c_rw      (i2c_rw),
        .i2c_data_wr (i2c_data_wr),
        .i2c_busy    (i2c_busy),
        .i2c_ack_err (i2c_ack_err),
        .init_done   (init_done)
    );

    always #(CLK_PERIOD/2) if (sim_active) clk = ~clk;

    initial begin
        $dumpfile(`FST_OUT);
        $dumpvars(1, tb_uda1380_init_fsm);
        $dumpvars(1, dut);
    end

    // Stub i2c_master: pulse busy once per "byte" while ena is high.
    initial begin : i2c_stub
        forever begin
            i2c_busy = 1'b0;
            @(posedge clk);
            while (i2c_ena !== 1'b1) @(posedge clk);
            while (i2c_ena === 1'b1) begin
                #200;
                i2c_busy <= 1'b1;
                bytes_observed = bytes_observed + 1;
                if (i2c_addr !== DEVICE_ADDR_TB)
                    $fatal(1, "i2c_addr != DEVICE_ADDR during init: %h", i2c_addr);
                if (i2c_rw !== 1'b0)
                    $fatal(1, "i2c_rw should be 0 (write) during init");
                #100;
                i2c_busy <= 1'b0;
                #50;
            end
        end
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
