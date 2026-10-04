`timescale 1ns/1ps
module tb_clock_enable;
    reg clk = 0;
    always #5 clk = ~clk;
    reg rst = 1, enable_async = 0;
    wire enable_sync, tick;
    wire [3:0] count;
    wire fast_sync, fast_tick;
    wire [0:0] fast_count;
    clock_enable dut(clk, rst, enable_async, enable_sync, tick, count);
    clock_enable #(.DIVISOR(1), .COUNT_WIDTH(1)) fast(
        clk, rst, enable_async, fast_sync, fast_tick, fast_count);

    task step;
        begin @(posedge clk); #1; end
    endtask
    integer cycle = 0;
    initial begin
        $dumpfile(`FST_OUT);
        $dumpvars(0, tb_clock_enable);
        step();
        if (tick || count || enable_sync) $fatal(1, "reset must clear outputs");
        @(negedge clk); rst = 0; enable_async = 1;
        step();
        if (enable_sync) $fatal(1, "async input bypassed first stage");
        step();
        if (!enable_sync) $fatal(1, "second stage failed to capture input");
        step();
        if (count != 0 || tick) $fatal(1, "count advanced before first tick");
        step();
        if (count != 1 || !tick) $fatal(1, "first enabled tick must increment");
        for (cycle = 5; cycle <= 68; cycle = cycle + 1) begin
            step();
            if (tick !== (cycle % 4 == 0) || count !== ((cycle / 4) % 16))
                $fatal(1, "tick cadence or modulo wrap wrong at cycle %0d", cycle);
            if (!fast_tick || fast_count !== ((cycle - 2) % 2))
                $fatal(1, "DIVISOR=1 / COUNT_WIDTH=1 failed");
        end
        @(negedge clk); enable_async = 0;
        step();
        if (!enable_sync) $fatal(1, "disable bypassed first stage");
        step();
        if (enable_sync) $fatal(1, "disable did not propagate");
        repeat (8) step();
        if (count != 1) $fatal(1, "disabled count must hold");
        @(negedge clk); rst = 1;
        repeat (2) step();
        if (count || tick || fast_count || fast_tick) $fatal(1, "held reset failed");
        $display("clock_enable: cadence, synchronization, hold, wrap and reset passed");
        $finish;
    end
endmodule
