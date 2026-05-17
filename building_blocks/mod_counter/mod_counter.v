// mod_counter — Verilog mirror of mod_counter.vhd.
//
// Up/down modulo-N counter with carry-out. Counts 0..MAX_NUMBER
// (forward) or MAX_NUMBER..0 (backward), pulsing carryBit for one
// cycle on every wrap. 4-bit output makes it a drop-in single BCD
// digit at MAX_NUMBER=9; other moduli up to 15 share the same width.

module mod_counter #(
    parameter integer MAX_NUMBER = 9
) (
    input  wire       clock,
    input  wire       reset,
    input  wire       direction,        // 1 = forward, 0 = backward
    output wire [3:0] currentNumber,
    output reg        carryBit
);

    reg [3:0] currentNumberSignal = 4'd0;
    initial carryBit = 1'b0;

    always @(posedge clock) begin
        if (reset) begin
            currentNumberSignal <= 4'd0;
        end else if (direction) begin
            if (currentNumberSignal == MAX_NUMBER) begin
                currentNumberSignal <= 4'd0;
                carryBit            <= 1'b1;
            end else begin
                currentNumberSignal <= currentNumberSignal + 4'd1;
                carryBit            <= 1'b0;
            end
        end else begin
            if (currentNumberSignal == 4'd0) begin
                currentNumberSignal <= MAX_NUMBER[3:0];
                carryBit            <= 1'b1;
            end else begin
                currentNumberSignal <= currentNumberSignal - 4'd1;
                carryBit            <= 1'b0;
            end
        end
    end

    assign currentNumber = currentNumberSignal;

endmodule
