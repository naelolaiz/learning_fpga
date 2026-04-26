// Serial2Parallel: continuously shifts inData into the LSB of an
// internal shift register and exposes a snapshot of that register on
// outData when inPrint is held high at the rising clock edge. Between
// inPrint pulses outData stays at its last snapshot.
//
// Verilog mirror of Serial2Parallel.vhd — wraps the shared
// shift_register module (in ../shift_register/) plus a snapshot reg.

module Serial2Parallel #(
    parameter integer NUMBER_OF_BITS = 16
) (
    input  wire                       inClock,
    input  wire                       inData,
    input  wire                       inPrint,
    output reg  [NUMBER_OF_BITS-1:0]  outData
);

    wire [NUMBER_OF_BITS-1:0] sShifted;

    shift_register #(.WIDTH(NUMBER_OF_BITS)) inner (
        .clk          (inClock),
        .load         (1'b0),
        .load_data    ({NUMBER_OF_BITS{1'b0}}),
        .serial_in    (inData),
        .parallel_out (sShifted),
        .serial_out   ()
    );

    initial outData = {NUMBER_OF_BITS{1'b0}};

    always @(posedge inClock) begin
        if (inPrint)
            outData <= sShifted;
    end

endmodule
