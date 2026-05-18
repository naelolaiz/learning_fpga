// CounterTimer — Verilog mirror of CounterTimer.vhd.
//
// Composition of Timer + a 64-bit saturating counter: the inner
// Timer pulses every MAX_NUMBER_FOR_TIMER cycles, the counter
// accumulates ticks and wraps at MAX_NUMBER_FOR_COUNTER.

module CounterTimer #(
    parameter integer MAX_NUMBER_FOR_TIMER   = 50_000_000,
    parameter integer MAX_NUMBER_FOR_COUNTER = 10
) (
    input  wire        clock,
    input  wire        reset,
    output wire        timerTriggered,
    output reg  [63:0] counter
);

    wire timerTick;

    initial counter = 64'd0;

    Timer #(.MAX_NUMBER(MAX_NUMBER_FOR_TIMER)) inner_timer (
        .clock          (clock),
        .reset          (reset),
        .maxLimit       (MAX_NUMBER_FOR_TIMER[31:0]),
        .timerTriggered (timerTick)
    );

    // VHDL mirror uses `timerTick'event and timerTick='1'` — clock
    // the counter off the tick directly with async reset, so the
    // counter advances in the same delta cycle as the tick rises
    // (clocking off `clock` instead would push the update one cycle
    // late).
    always @(posedge timerTick or posedge reset) begin
        if (reset) begin
            counter <= 64'd0;
        end else begin
            if (counter == MAX_NUMBER_FOR_COUNTER)
                counter <= 64'd0;
            else
                counter <= counter + 64'd1;
        end
    end

    assign timerTriggered = timerTick;

endmodule
