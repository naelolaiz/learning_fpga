// tl_rom_lut.v - Verilog mirror of tl_rom_lut.vhd.
//
// Thin top-level wrapper around the inline-literal ROM (storage method
// A). Adds a one-cycle input register stage so total latency from
// input change to outReadMemory is two clock cycles — matching the
// VHDL version exactly. The diagram TOP and the basic testbench both
// target this wrapper.

module tl_rom_lut #(
    parameter integer ARRAY_SIZE          = 32,
    parameter integer ELEMENTS_BITS_COUNT = 9
) (
    input  wire                          inClock50Mhz,
    input  wire [6:0]                    inAngleIdxToRead,
    input  wire [3:0]                    inNibbleProductIdx,
    output wire [ELEMENTS_BITS_COUNT:0]  outReadMemory
);

    reg [6:0] sAngleIdx         = 7'd0;
    reg [3:0] sNibbleProductIdx = 4'd0;

    always @(posedge inClock50Mhz) begin
        sAngleIdx         <= inAngleIdxToRead;
        sNibbleProductIdx <= inNibbleProductIdx;
    end

    rom_lut #(
        .ARRAY_SIZE         (ARRAY_SIZE),
        .ELEMENTS_BITS_COUNT(ELEMENTS_BITS_COUNT)
    ) rom_inst (
        .clock              (inClock50Mhz),
        .read_angle_idx     (sAngleIdx),
        .nibble_product_idx (sNibbleProductIdx),
        .data_out           (outReadMemory)
    );

endmodule
