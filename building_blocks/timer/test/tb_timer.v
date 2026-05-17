// Timer smoke test (Verilog mirror of tb_timer.vhd).
//
// (A) generic-only: maxLimit left as its default (= MAX_NUMBER=10);
//     expect a tick every 11 clocks.
// (B) runtime override: same MAX_NUMBER=10, drive maxLimit=4; expect
//     a tick every 5 clocks.

`timescale 1ns/1ps

module tb_timer;
    localparam integer CLK_PERIOD_NS = 20;

    reg  clk   = 1'b0;
    reg  rst   = 1'b0;
    wire tick_generic;
    wire tick_runtime;

    integer generic_tick_count = 0;
    integer runtime_tick_count = 0;

    // (A) generic-only
    Timer #(.MAX_NUMBER(10), .TRIGGER_DURATION(1)) DUT_GENERIC (
        .clock(clk),
        .reset(rst),
        .maxLimit(32'd10),                 // simulate the VHDL "default = MAX_NUMBER"
        .timerTriggered(tick_generic)
    );

    // (B) runtime override
    Timer #(.MAX_NUMBER(10), .TRIGGER_DURATION(1)) DUT_RUNTIME (
        .clock(clk),
        .reset(rst),
        .maxLimit(32'd4),
        .timerTriggered(tick_runtime)
    );

    always #(CLK_PERIOD_NS/2) clk = ~clk;

    // Count rising edges of each tick signal directly. Counting on
    // posedge clk would race the DUT's same-edge assignment to the
    // tick output and undercount by one.
    always @(posedge tick_generic) generic_tick_count = generic_tick_count + 1;
    always @(posedge tick_runtime) runtime_tick_count = runtime_tick_count + 1;

    initial begin
        $dumpfile(`FST_OUT);
        $dumpvars(1, tb_timer);
        $dumpvars(1, DUT_GENERIC);
        $dumpvars(1, DUT_RUNTIME);

        // 110 clocks total.
        #(110 * CLK_PERIOD_NS);

        if (generic_tick_count !== 10) begin
            $display("FAIL: generic-only expected 10 ticks, got %0d", generic_tick_count);
            $fatal;
        end
        if (runtime_tick_count !== 22) begin
            $display("FAIL: runtime-override expected 22 ticks, got %0d", runtime_tick_count);
            $fatal;
        end

        $finish;
    end

endmodule
