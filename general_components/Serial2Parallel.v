// Verilog mirror of Serial2Parallel.vhd.
//
// Shift-register that captures `inData` on every rising edge of inClock
// (MSB-first) and exposes the buffered word on outData when inPrint
// goes high.

module Serial2Parallel #(
    parameter integer NUMBER_OF_BITS = 16
) (
    input  wire                       inClock,
    input  wire                       inData,
    input  wire                       inPrint,
    output reg  [NUMBER_OF_BITS-1:0]  outData
);

    reg [NUMBER_OF_BITS-1:0] cachedData = {NUMBER_OF_BITS{1'b0}};

    always @(posedge inClock) begin
        if (inPrint)
            outData <= cachedData;
        else
            cachedData <= {cachedData[NUMBER_OF_BITS-2:0], inData};
    end

endmodule
