// Verilog mirror of CounterTimer.vhd.
//
// Wraps a Timer with a counter that advances on every Timer tick and
// wraps at MAX_NUMBER_FOR_COUNTER. Used by the top-level as the
// 4-state digit-mux selector (counter cycles 0..3 every ~2 ms).

module CounterTimer #(
    parameter integer MAX_NUMBER_FOR_TIMER   = 50_000_000,
    parameter integer MAX_NUMBER_FOR_COUNTER = 10
) (
    input  wire        clock,
    input  wire        reset,
    output wire        timerTriggered,
    output reg  [63:0] counter = 64'd0
);

    wire timerTick;

    Timer #(.MAX_NUMBER(MAX_NUMBER_FOR_TIMER)) inner_timer (
        .clock          (clock),
        .reset          (reset),
        .timerTriggered (timerTick)
    );

    // Detect rising edge of the timer tick (the VHDL mirror clocks on
    // `timerTick'event and timerTick = '1'`).
    reg timerTick_d = 1'b0;
    always @(posedge clock) begin
        timerTick_d <= timerTick;
        if (reset) begin
            counter <= 64'd0;
        end else if (timerTick && !timerTick_d) begin
            if (counter == MAX_NUMBER_FOR_COUNTER)
                counter <= 64'd0;
            else
                counter <= counter + 64'd1;
        end
    end

    assign timerTriggered = timerTick;

endmodule
