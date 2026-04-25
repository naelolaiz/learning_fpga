// Verilog mirror of Timer.vhd.
//
// Periodic pulse generator: timerTriggered goes high when the internal
// counter wraps past MAX_NUMBER, and low when it crosses TRIGGER_DURATION.
// With MAX_NUMBER = 50_000_000 and TRIGGER_DURATION = 25_000_000 the
// output is a 1 Hz square wave at 50 MHz with 50 % duty cycle.

module Timer #(
    parameter integer MAX_NUMBER       = 50_000_000,
    parameter integer TRIGGER_DURATION = 1
) (
    input  wire clock,
    input  wire reset,
    output reg  timerTriggered = 1'b0
);

    reg [31:0] counterForTriggerOut = 32'd0;

    always @(posedge clock) begin
        if (reset) begin
            counterForTriggerOut <= 32'd0;
        end else if (counterForTriggerOut == MAX_NUMBER) begin
            counterForTriggerOut <= 32'd0;
            timerTriggered       <= 1'b1;
        end else begin
            counterForTriggerOut <= counterForTriggerOut + 32'd1;
            if (counterForTriggerOut + 32'd1 == TRIGGER_DURATION)
                timerTriggered <= 1'b0;
        end
    end

endmodule
