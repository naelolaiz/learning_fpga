// VariableTimer — Verilog mirror of VariableTimer.vhd.
//
// A `Timer` wrapped with a serial-load shift register. While
// `setMax` is high, the first clock clears the shift register and
// each subsequent clock shifts `dataIn` into the LSB. The mirrored
// register drives the inner Timer's `maxLimit`; the inner Timer is
// held in reset for the duration of the load so the new period
// takes effect when `setMax` goes low.

module VariableTimer #(
    parameter integer MAX_NUMBER       = 50_000_000,
    parameter integer TRIGGER_DURATION = 1
) (
    input  wire clock,
    input  wire reset,
    input  wire setMax,
    input  wire dataIn,
    output wire timerTriggered
);

    reg [63:0] shift_reg = 64'd0;
    reg        started   = 1'b0;
    reg [31:0] limit_reg = MAX_NUMBER;

    // Pre-compute the next shift-register value so the comparison and
    // the truncation don't have to part-select a concatenation literal
    // (which is a syntax error in iverilog / verilator).
    wire [63:0] next_shift = {shift_reg[62:0], dataIn};

    wire inner_reset = reset | setMax;

    always @(posedge clock) begin
        if (reset) begin
            shift_reg <= 64'd0;
            started   <= 1'b0;
            limit_reg <= MAX_NUMBER;
        end else if (setMax) begin
            if (!started) begin
                shift_reg <= 64'd0;
                started   <= 1'b1;
                limit_reg <= 32'd0;
            end else begin
                shift_reg <= next_shift;
                if (next_shift <= MAX_NUMBER)
                    limit_reg <= next_shift[31:0];
                else
                    limit_reg <= MAX_NUMBER;
            end
        end else begin
            started <= 1'b0;
        end
    end

    Timer #(.MAX_NUMBER(MAX_NUMBER), .TRIGGER_DURATION(TRIGGER_DURATION)) inner (
        .clock(clock),
        .reset(inner_reset),
        .maxLimit(limit_reg),
        .timerTriggered(timerTriggered)
    );

endmodule
