// VariableTimer serial-load smoke test (Verilog mirror).
//
// Shift in the bit pattern for 9 over 64 clocks, then count ticks in
// a 200-clock measurement window — expect 20 (period = 10).
//
// Driver changes are aligned to the falling edge of the clock and
// nudged forward by a #1 delay so the DUT's rising-edge sampling
// always sees stable inputs (per the repo's standing rule about
// negedge driver races against the DUT's non-blocking writes).

`timescale 1ns/1ps

module tb_variable_timer;
    localparam integer CLK_PERIOD_NS = 20;

    reg  clk     = 1'b0;
    reg  rst     = 1'b0;
    reg  setMax  = 1'b0;
    reg  dataIn  = 1'b0;
    wire tick;

    integer tick_count = 0;
    integer i = 0;          // initialised so waveview doesn't paint
                            // an X-band from t=0 until the first
                            // for-loop assignment
    reg [63:0] new_limit_bits = 64'd9;

    VariableTimer #(.MAX_NUMBER(100), .TRIGGER_DURATION(1)) DUT (
        .clock(clk),
        .reset(rst),
        .setMax(setMax),
        .dataIn(dataIn),
        .timerTriggered(tick)
    );

    always #(CLK_PERIOD_NS/2) clk = ~clk;
    always @(posedge tick) tick_count = tick_count + 1;

    initial begin
        $dumpfile(`FST_OUT);
        $dumpvars(1, tb_variable_timer);
        $dumpvars(1, DUT);

        rst = 1'b1; #(2 * CLK_PERIOD_NS); rst = 1'b0;

        // Align to the falling edge before asserting setMax so the
        // first posedge with setMax=1 hits the "clear" branch cleanly.
        @(negedge clk); #1;
        setMax = 1'b1;

        // 64 shifts after the initial clear.
        for (i = 63; i >= 0; i = i - 1) begin
            @(negedge clk); #1;
            dataIn = new_limit_bits[i];
        end

        // Hold setMax for one more posedge to capture the last shift,
        // then release on the next negedge.
        @(negedge clk); #1;
        setMax = 1'b0;
        dataIn = 1'b0;

        // Let the inner Timer come out of reset.
        #(2 * CLK_PERIOD_NS);
        tick_count = 0;

        // 200-cycle measurement window. With runtime limit = 9 the
        // Timer ticks every 10 clocks → 20 ticks.
        repeat (200) @(posedge clk);

        if (tick_count !== 20) begin
            $display("FAIL: expected 20 ticks in 200 clocks (period=10), got %0d",
                     tick_count);
            $fatal;
        end

        $finish;
    end

endmodule
