// CounterTimer smoke test (Verilog mirror of tb_counter_timer.vhd).
//
// Inner Timer MAX_NUMBER=9 → period 10 cycles, counter modulus = 4.
// After 5 ticks (50 clocks) the counter should have wrapped exactly
// once back to 0; after 10 ticks (100 clocks) it should be at 0 again.

`timescale 1ns/1ps

module tb_counter_timer;
    localparam integer CLK_PERIOD_NS = 20;

    reg         clk = 1'b0;
    reg         rst = 1'b0;
    wire        tick;
    wire [63:0] counter;

    CounterTimer #(.MAX_NUMBER_FOR_TIMER(9), .MAX_NUMBER_FOR_COUNTER(4)) DUT (
        .clock          (clk),
        .reset          (rst),
        .timerTriggered (tick),
        .counter        (counter)
    );

    always #(CLK_PERIOD_NS/2) clk = ~clk;

    initial begin
        $dumpfile(`FST_OUT);
        $dumpvars(1, tb_counter_timer);
        $dumpvars(1, DUT);

        rst = 1'b1; #(2 * CLK_PERIOD_NS); rst = 1'b0;

        // After 5 ticks (50 clocks) — counter sequence 0→1→2→3→4→0.
        #(50 * CLK_PERIOD_NS);
        if (counter !== 64'd0) begin
            $display("FAIL: after 5 ticks expected counter=0, got %0d", counter);
            $fatal;
        end

        // After 10 ticks (100 clocks) the counter should wrap again.
        #(50 * CLK_PERIOD_NS);
        if (counter !== 64'd0) begin
            $display("FAIL: after 10 ticks expected counter=0, got %0d", counter);
            $fatal;
        end

        $finish;
    end

endmodule
