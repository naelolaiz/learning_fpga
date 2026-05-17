// Timer
//
// Verilog mirror of Timer.vhd. Free-running tick generator: count up
// to maxLimit on every rising edge of clock, then pulse
// timerTriggered for TRIGGER_DURATION cycles and wrap. maxLimit is a
// runtime port so a wrapper (VariableTimer) can drive it; leaving
// the port unconnected at the call-site defaults it to MAX_NUMBER
// via the elaboration-time `MAX_NUMBER` parameter.

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

    always @(posedge clock) begin
        if (reset) begin
            counterForTriggerOut <= 32'd0;
        end else if (counterForTriggerOut == maxLimit) begin
            counterForTriggerOut <= 32'd0;
            timerTriggered       <= 1'b1;
        end else begin
            counterForTriggerOut <= counterForTriggerOut + 32'd1;
            if (counterForTriggerOut + 32'd1 == TRIGGER_DURATION) begin
                timerTriggered <= 1'b0;
            end
        end
    end

endmodule
