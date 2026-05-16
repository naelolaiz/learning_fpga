// tb_uart_rx.v - Verilog mirror of tb_uart_rx.vhd.
//
// Same three good bytes (0xA5, 0x00, 0xFF) plus a framing-error
// check. The `send_byte` task bit-bangs the frame at the same
// CLKS_PER_BIT cadence the DUT is configured for.

`timescale 1ns/1ps

module tb_uart_rx;

    localparam integer CLKS_PER_BIT = 8;
    localparam time    CLK_PERIOD   = 20;
    localparam time    BIT_TIME     = CLKS_PER_BIT * CLK_PERIOD;

    reg          sClk    = 1'b0;
    reg          sRx     = 1'b1;       // idle high
    wire [7:0]   sRxData;
    wire         sRxValid;

    reg          sSimulationActive    = 1'b1;
    reg  [7:0]   sLastCaptured        = 8'h00;
    integer      sValidPulseCount     = 0;

    uart_rx #(.CLKS_PER_BIT(CLKS_PER_BIT)) dut (
        .clk      (sClk),
        .rx       (sRx),
        .rx_data  (sRxData),
        .rx_valid (sRxValid)
    );

    always #(CLK_PERIOD/2) if (sSimulationActive) sClk = ~sClk;

    initial begin
        $dumpfile(`FST_OUT);
        $dumpvars(1, tb_uart_rx);
        $dumpvars(1, dut);
    end

    // Watcher
    always @(posedge sClk) begin
        if (sRxValid) begin
            sLastCaptured    <= sRxData;
            sValidPulseCount <= sValidPulseCount + 1;
        end
    end

    // Drive a full 8N1 frame, optionally with a forced framing error.
    // `integer i = 0` so the FST trace has a defined value before
    // the loop runs (a plain `integer i;` defaults to X / red band).
    task send_byte(input [7:0] b, input stop_bv);
        integer i;
        begin
            i = 0;
            sRx = 1'b0;                 // start bit
            #(BIT_TIME);
            for (i = 0; i < 8; i = i + 1) begin
                sRx = b[i];
                #(BIT_TIME);
            end
            sRx = stop_bv;              // stop bit (or '0' for framing error)
            #(BIT_TIME);
            sRx = 1'b1;                 // back to idle
        end
    endtask

    integer expected_count = 0;
    initial begin : driver

        #(4*CLK_PERIOD);
        if (sRx      !== 1'b1) $fatal(1, "rx must idle high");
        if (sRxValid !== 1'b0) $fatal(1, "rx_valid must idle low");

        // 0xA5
        send_byte(8'hA5, 1'b1);
        #(2*BIT_TIME);
        expected_count = expected_count + 1;
        if (sValidPulseCount !== expected_count)
            $fatal(1, "0xA5: rx_valid did not pulse");
        if (sLastCaptured !== 8'hA5)
            $fatal(1, "0xA5: captured byte mismatch: got %h", sLastCaptured);

        // 0x00
        send_byte(8'h00, 1'b1);
        #(2*BIT_TIME);
        expected_count = expected_count + 1;
        if (sValidPulseCount !== expected_count)
            $fatal(1, "0x00: rx_valid did not pulse");
        if (sLastCaptured !== 8'h00)
            $fatal(1, "0x00: captured byte mismatch: got %h", sLastCaptured);

        // 0xFF
        send_byte(8'hFF, 1'b1);
        #(2*BIT_TIME);
        expected_count = expected_count + 1;
        if (sValidPulseCount !== expected_count)
            $fatal(1, "0xFF: rx_valid did not pulse");
        if (sLastCaptured !== 8'hFF)
            $fatal(1, "0xFF: captured byte mismatch: got %h", sLastCaptured);

        // Framing error: stop bit forced low
        send_byte(8'h5A, 1'b0);
        #(2*BIT_TIME);
        if (sValidPulseCount !== expected_count)
            $fatal(1, "Framing-error byte should NOT have pulsed rx_valid");

        $display("uart_rx simulation done!");
        sSimulationActive = 1'b0;
        $finish;
    end

endmodule
