// rom_lut_hex.v - Storage method B for the ROM_LUT example.
//
// Same I/O and quadrant logic as rom_lut.v; only the table-population
// strategy differs. Here the contents come from rom_lut.hex via
// $readmemh — no inline literal in the source. The hex file is shared
// with the VHDL textio variant (single_clock_rom_hex), which proves
// the two languages can read the same on-disk asset.

module rom_lut_hex #(
    parameter integer ARRAY_SIZE          = 32,
    parameter integer ELEMENTS_BITS_COUNT = 9,
    parameter         HEX_FILE            = "rom_lut.hex"
) (
    input  wire                          clock,
    input  wire [6:0]                    read_angle_idx,
    input  wire [3:0]                    nibble_product_idx,
    output reg  [ELEMENTS_BITS_COUNT:0]  data_out
);

    reg [ELEMENTS_BITS_COUNT-1:0] rom [0:ARRAY_SIZE*16-1];

    initial begin
        $readmemh(HEX_FILE, rom);
    end

    wire        secondOrFourthQuadrant  = read_angle_idx[5];
    wire        thirdOrFourthQuadrant   = read_angle_idx[6];
    wire [4:0]  firstQuadrantTableIndex = read_angle_idx[4:0];

    reg  [4:0]  tableOfTablesIdx;
    reg  [ELEMENTS_BITS_COUNT-1:0] rom_value;

    always @(posedge clock) begin
        if (secondOrFourthQuadrant)
            tableOfTablesIdx = 5'd31 - firstQuadrantTableIndex;
        else
            tableOfTablesIdx = firstQuadrantTableIndex;

        rom_value = rom[{tableOfTablesIdx, nibble_product_idx}];

        if (thirdOrFourthQuadrant)
            data_out <= -{1'b0, rom_value};
        else
            data_out <= {1'b0, rom_value};
    end

endmodule
