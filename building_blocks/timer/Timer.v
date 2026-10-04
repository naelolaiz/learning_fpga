// Timer
//
// Verilog mirror of Timer.vhd. Free-running tick generator: count up
// to maxLimit on every rising edge of clock, then pulse
// timerTriggered for TRIGGER_DURATION cycles and wrap. maxLimit is a
// runtime port so a wrapper (VariableTimer) can drive it. Unlike VHDL,
// Verilog input ports have no default: wire maxLimit to MAX_NUMBER when
// no runtime override is needed. Reset synchronously clears count and
// output. Lowering maxLimit below the current count triggers on the next
// edge. Pulses overlap when TRIGGER_DURATION >= maxLimit + 1.

module Timer #(
    parameter integer MAX_NUMBER       = 50_000_000,
    parameter integer TRIGGER_DURATION = 1
) (
    input  wire clock,
    input  wire reset,
    input  wire [31:0] maxLimit,
    output reg  timerTriggered
);

    reg [31:0] counterForTriggerOut = 32'd0;

    initial timerTriggered = 1'b0;

`ifndef SYNTHESIS
    initial begin
        if (MAX_NUMBER < 0)
            $fatal(1, "MAX_NUMBER must be nonnegative");
        if (TRIGGER_DURATION < 1)
            $fatal(1, "TRIGGER_DURATION must be positive");
    end
    always @(posedge clock) begin
        if (maxLimit > MAX_NUMBER)
            $fatal(1, "maxLimit must be between 0 and MAX_NUMBER");
    end
`endif

    always @(posedge clock) begin
        if (reset) begin
            counterForTriggerOut <= 32'd0;
            timerTriggered       <= 1'b0;
        end else if (counterForTriggerOut >= maxLimit) begin
            counterForTriggerOut <= 32'd0;
            timerTriggered       <= 1'b1;
        end else begin
            counterForTriggerOut <= counterForTriggerOut + 32'd1;
            if (counterForTriggerOut + 32'd1 >= TRIGGER_DURATION) begin
                timerTriggered <= 1'b0;
            end
        end
    end

endmodule
