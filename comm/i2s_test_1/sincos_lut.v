// sincos_lut.v - 16384 x 16-bit signed sine table.
//
// Data is loaded from a hex file via $readmemh. The VHDL twin keeps
// the same data inline so the yosys+ghdl-plugin diagram synth has
// a static table to walk; both forms must agree bit-for-bit.
//
// HEX_FILE defaults to "sincos_lut.hex" (resolved relative to vvp's
// cwd). The testbench overrides it via defparam to "../sincos_lut.hex"
// because the Makefile runs vvp from build/.

module sincos_lut #(
    parameter HEX_FILE = "sincos_lut.hex"
) (
    input  wire        clk,
    input  wire [13:0] addr,
    output reg  [15:0] sin_out
);

    reg [15:0] rom [0:16383];

    initial begin
        $readmemh(HEX_FILE, rom);
    end

    always @(posedge clk) begin
        sin_out <= rom[addr];
    end

endmodule
