// Verilog mirror of 7segmentsDigit.vhd (entity name: Digit).
//
// One BCD digit. On every rising edge of `clock`, count up (when
// direction = 1) or down (when direction = 0); wrap to 0 (or to
// MAX_NUMBER) on overflow and pulse `carryBit` for one cycle. The clock
// for downstream digits is the carry of this one — chained, the cascade
// implements a multi-digit BCD counter without any explicit central
// state.

module Digit #(
    parameter integer MAX_NUMBER = 9
) (
    input  wire       clock,
    input  wire       reset,
    input  wire       direction,         // 1 = forward
    output wire [3:0] currentNumber,
    output reg        carryBit = 1'b0
);

    reg [3:0] currentNumberSignal = 4'd0;

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
