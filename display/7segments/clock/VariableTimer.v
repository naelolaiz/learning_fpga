// Verilog mirror of VariableTimer.vhd.
//
// Same pulse-generator shape as Timer, plus a `setMax` mode that clocks
// the upper bound in serially over `dataIn` (one bit per clock for up to
// 63 bits). The serial-load path is unused in the clock top-level today
// (setMax/dataIn default to '0'), but the entity is preserved so the
// VHDL/Verilog netlists stay identical.

module VariableTimer #(
    parameter integer MAX_NUMBER       = 50_000_000,
    parameter integer TRIGGER_DURATION = 1
) (
    input  wire clock,
    input  wire reset,
    input  wire setMax,
    input  wire dataIn,
    output reg  timerTriggered = 1'b0
);

    reg [31:0] counterForTriggerOut = 32'd0;
    reg        setMaxStarted        = 1'b0;
    // Declare with the parameter value directly — a separate `initial`
    // block produces a yosys "conflicting initialization values" error
    // because the reg declaration's `= 64'd0` and the initial block
    // would both try to write at simulation start.
    reg [63:0] maxNumber            = MAX_NUMBER;
    reg [5:0]  serialInDataCounter  = 6'd0;

    always @(posedge clock) begin
        if (reset) begin
            counterForTriggerOut <= 32'd0;
            maxNumber            <= MAX_NUMBER;
        end
        if (!setMax) begin
            setMaxStarted       <= 1'b0;
            serialInDataCounter <= 6'd0;
            if (counterForTriggerOut == MAX_NUMBER) begin
                counterForTriggerOut <= 32'd0;
                timerTriggered       <= 1'b1;
            end else begin
                counterForTriggerOut <= counterForTriggerOut + 32'd1;
                if (counterForTriggerOut + 32'd1 == TRIGGER_DURATION)
                    timerTriggered <= 1'b0;
            end
        end else begin
            if (!setMaxStarted) begin
                maxNumber     <= 64'd0;
                setMaxStarted <= 1'b1;
            end
            if (serialInDataCounter < 6'd63) begin
                maxNumber           <= {maxNumber[62:0], dataIn};
                serialInDataCounter <= serialInDataCounter + 6'd1;
            end
            counterForTriggerOut <= 32'd0;
        end
    end

endmodule
