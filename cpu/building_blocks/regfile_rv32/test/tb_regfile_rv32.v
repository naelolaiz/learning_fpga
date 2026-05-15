// tb_regfile_rv32.v - Verilog mirror of tb_regfile_rv32.vhd.

`timescale 1ns/1ps

module tb_regfile_rv32;

    localparam time CLK_PERIOD = 20;

    reg         sClk    = 1'b0;
    reg         sWe     = 1'b0;
    reg  [4:0]  sWaddr  = 5'd0;
    reg  [31:0] sWdata  = 32'd0;
    reg  [4:0]  sRaddr1 = 5'd0;
    wire [31:0] sRdata1;
    reg  [4:0]  sRaddr2 = 5'd0;
    wire [31:0] sRdata2;
    reg         sSimulationActive = 1'b1;

    regfile_rv32 dut (
        .clk    (sClk),
        .we     (sWe),
        .waddr  (sWaddr),
        .wdata  (sWdata),
        .raddr1 (sRaddr1),
        .rdata1 (sRdata1),
        .raddr2 (sRaddr2),
        .rdata2 (sRdata2)
    );

    always #(CLK_PERIOD/2) if (sSimulationActive) sClk = ~sClk;

    initial begin
        $dumpfile(`FST_OUT);
        $dumpvars(1, tb_regfile_rv32);
        $dumpvars(1, dut);
    end

    // `integer i = 0` so the FST trace has a defined value before
    // the loop starts (Verilog's plain `integer i;` defaults to X).
    integer i = 0;
    initial begin : driver
        // (1) Initial state: every register reads as zero.
        @(negedge sClk);
        for (i = 0; i < 32; i = i + 1) begin
            sRaddr1 = i[4:0];
            sRaddr2 = (i + 16) % 32;
            #1;
            if (sRdata1 !== 32'h0) $fatal(1, "Init read1 mismatch at x%0d", i);
            if (sRdata2 !== 32'h0) $fatal(1, "Init read2 mismatch at x%0d", (i + 16) % 32);
        end

        // 32 iterations of `#1` left us mid-cycle. Re-align before the
        // write phases below so the write actually crosses a rising edge.
        @(negedge sClk);

        // (2) Write 0xDEADBEEF to x5; read it back next cycle on both ports.
        // The #1 after each @(negedge) ensures the regfile's non-blocking
        // write commits before our blocking driver changes the inputs —
        // without it, two always-@(negedge) blocks have undefined order
        // and iverilog can drop the write (see test 4 below for the
        // failure that surfaced this).
        sWe    = 1'b1;
        sWaddr = 5'd5;
        sWdata = 32'hDEADBEEF;
        @(negedge sClk);
        #1;
        sWe = 1'b0;
        sRaddr1 = 5'd5;
        sRaddr2 = 5'd5;
        #1;
        if (sRdata1 !== 32'hDEADBEEF) $fatal(1, "Read1 after write x5: %h", sRdata1);
        if (sRdata2 !== 32'hDEADBEEF) $fatal(1, "Read2 after write x5: %h", sRdata2);

        // (3) Write to x0 must be silently dropped.
        sWe    = 1'b1;
        sWaddr = 5'd0;
        sWdata = 32'hFFFFFFFF;
        @(negedge sClk);
        #1;
        sWe = 1'b0;
        sRaddr1 = 5'd0;
        #1;
        if (sRdata1 !== 32'h0) $fatal(1, "x0 must stay zero, got %h", sRdata1);

        // (4) Same-cycle write+read: with the falling-edge write
        // design (no combinational bypass), reading the same register
        // you're writing returns the OLD value within the cycle. The
        // new value lands at the falling edge.
        @(negedge sClk);

        sRaddr1 = 5'd7;
        #1;
        if (sRdata1 !== 32'h0) $fatal(1, "Pre-write: x7 should still be zero, got %h", sRdata1);

        sWe    = 1'b1;
        sWaddr = 5'd7;
        sWdata = 32'h0000CAFE;
        sRaddr1 = 5'd7;
        #1;
        if (sRdata1 !== 32'h0)
            $fatal(1, "Same-cycle read should return OLD stored value (0), got %h", sRdata1);

        @(negedge sClk);
        // #1 ensures the regfile's non-blocking write at this negedge
        // commits before our blocking sWe=0 changes the inputs. Without
        // it, the order of two always-@(negedge) blocks is undefined
        // and iverilog may run the driver first, dropping the write.
        #1;
        sWe = 1'b0;
        sRaddr1 = 5'd7;
        #1;
        if (sRdata1 !== 32'h0000CAFE)
            $fatal(1, "After write, x7 should hold 0000CAFE, got %h", sRdata1);

        $display("regfile_rv32 simulation done!");
        sSimulationActive = 1'b0;
        $finish;
    end

endmodule
