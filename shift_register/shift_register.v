// shift_register.v - Verilog mirror of shift_register.vhd.
//
// Parameterised shift register with synchronous load. When `load` is
// high the register captures `load_data`; otherwise it shifts toward
// the MSB and admits `serial_in` at the LSB on every rising clock.

module shift_register #(
    parameter integer WIDTH = 8
) (
    input  wire             clk,
    input  wire             load,
    input  wire [WIDTH-1:0] load_data,
    input  wire             serial_in,
    output wire [WIDTH-1:0] parallel_out,
    output wire             serial_out
);

    reg [WIDTH-1:0] sreg = {WIDTH{1'b0}};

    always @(posedge clk) begin
        if (load)
            sreg <= load_data;
        else
            sreg <= {sreg[WIDTH-2:0], serial_in};
    end

    assign parallel_out = sreg;
    assign serial_out   = sreg[WIDTH-1];

endmodule
