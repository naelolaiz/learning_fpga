// tb_uart_tx.v - Verilog mirror of tb_uart_tx.vhd.

`timescale 1ns/1ps

module tb_uart_tx;

    localparam integer CLKS_PER_BIT = 8;
    localparam time CLK_PERIOD = 20;            // 50 MHz
    localparam time BIT_TIME   = CLKS_PER_BIT * CLK_PERIOD;

    reg        sClk     = 1'b0;
    reg        sTxStart = 1'b0;
    reg  [7:0] sTxData  = 8'hA5;
    wire       sTx;
    wire       sTxBusy;

    reg  [7:0] received = 8'h00;

    reg        sSimulationActive = 1'b1;

    uart_tx #(.CLKS_PER_BIT(CLKS_PER_BIT)) dut (
        .clk      (sClk),
        .tx_start (sTxStart),
        .tx_data  (sTxData),
        .tx       (sTx),
        .tx_busy  (sTxBusy)
    );

    always #(CLK_PERIOD/2) if (sSimulationActive) sClk = ~sClk;

    initial begin
        $dumpfile(`VCD_OUT);
        $dumpvars(1, tb_uart_tx);
        $dumpvars(1, dut);
    end

    initial begin : driver
        integer i;

        #(4*CLK_PERIOD);
        if (sTx !== 1'b1) $fatal(1, "Idle line should be high");
        sTxStart = 1'b1;
        #(CLK_PERIOD);
        sTxStart = 1'b0;

        // After tx_start, the FSM needs one cycle to register S_START
        // and another to drive tx low. Skip that, then half a bit
        // time to land in the middle of the start bit.
        #(CLK_PERIOD + BIT_TIME/2);
        if (sTx !== 1'b0) $fatal(1, "Start bit should be low");

        for (i = 0; i < 8; i = i + 1) begin
            #(BIT_TIME);
            received[i] = sTx;
        end
        #(BIT_TIME);
        if (sTx !== 1'b1) $fatal(1, "Stop bit should be high");

        #(BIT_TIME);
        if (received !== sTxData)
            $fatal(1, "Recovered byte mismatch: got %h expected %h",
                   received, sTxData);

        $display("uart_tx simulation done!");
        sSimulationActive = 1'b0;
        $finish;
    end

endmodule
