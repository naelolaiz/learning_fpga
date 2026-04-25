// tb_shift_register.v - Verilog mirror of tb_shift_register.vhd.
//
// Stimulus is driven on negedge so each rising edge captures a stable
// input — no race between the initial block and the always block.

`timescale 1ns/1ps

module tb_shift_register;

    localparam integer WIDTH      = 8;
    localparam time    CLK_PERIOD = 20;

    reg              sClk    = 1'b0;
    reg              sLoad   = 1'b0;
    reg  [WIDTH-1:0] sLoadD  = 8'hA5;
    reg              sIn     = 1'b0;
    wire [WIDTH-1:0] sPOut;
    wire             sSOut;

    reg              sSimulationActive = 1'b1;

    shift_register #(.WIDTH(WIDTH)) dut (
        .clk          (sClk),
        .load         (sLoad),
        .load_data    (sLoadD),
        .serial_in    (sIn),
        .parallel_out (sPOut),
        .serial_out   (sSOut)
    );

    always #(CLK_PERIOD/2) if (sSimulationActive) sClk = ~sClk;

    initial begin
        $dumpfile(`VCD_OUT);
        $dumpvars(1, tb_shift_register);
        $dumpvars(1, dut);
    end

    initial begin : driver
        @(negedge sClk);
        sLoad = 1'b1;
        @(negedge sClk);
        sLoad = 1'b0;
        if (sPOut !== 8'hA5)
            $fatal(1, "Loaded value mismatch: %h", sPOut);

        // start    = 10100101 (A5)
        // <<1, in=1: 01001011 (4B)
        // <<1, in=0: 10010110 (96)
        // <<1, in=1: 00101101 (2D)
        sIn = 1'b1; @(negedge sClk);
        sIn = 1'b0; @(negedge sClk);
        sIn = 1'b1; @(negedge sClk);

        if (sPOut !== 8'h2D)
            $fatal(1, "After three shifts: %b (expected 00101101)", sPOut);
        if (sSOut !== 1'b0)
            $fatal(1, "After three shifts, serial_out=%b", sSOut);

        $display("shift_register simulation done!");
        sSimulationActive = 1'b0;
        $finish;
    end

endmodule
