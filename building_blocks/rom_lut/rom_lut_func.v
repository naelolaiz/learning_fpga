// rom_lut_func.v - Storage method C for the ROM_LUT example.
//
// Same I/O and quadrant logic as rom_lut.v; here every entry is
// *computed* from $sin in the elaboration-time `initial` block, no
// inline literal and no external file. The formula matches the
// generate_tables.py recipe used to build the canonical hex data:
//   entry(row, col) = round( sin(row * pi/2 / ARRAY_SIZE) * col * (2^5 - 1) )
//
// $sin / $rtoi / `real` are simulator features (iverilog supports them);
// yosys read_verilog rejects `real`, so the whole module is hidden from
// the synthesis frontend via the translate-off/on pragmas. The multi-
// method TB still picks it up under iverilog and asserts bit-identity
// with methods A and B, so any rounding mismatch would trip there.

// synthesis translate_off
module rom_lut_func #(
    parameter integer ARRAY_SIZE          = 32,
    parameter integer ELEMENTS_BITS_COUNT = 9
) (
    input  wire                          clock,
    input  wire [6:0]                    read_angle_idx,
    input  wire [3:0]                    nibble_product_idx,
    output reg  [ELEMENTS_BITS_COUNT:0]  data_out
);

    localparam real PI_OVER_2 = 1.5707963267948966;
    localparam real MAGNITUDE = 31.0;  // 2^(9-4) - 1

    reg [ELEMENTS_BITS_COUNT-1:0] rom [0:ARRAY_SIZE*16-1];

    integer row, col;
    real    angle, sample;
    initial begin
        for (row = 0; row < ARRAY_SIZE; row = row + 1) begin
            angle = PI_OVER_2 * row / ARRAY_SIZE;
            for (col = 0; col < 16; col = col + 1) begin
                // round-to-nearest (positive args only here, so a +0.5 floor works)
                sample = $sin(angle) * col * MAGNITUDE;
                rom[row*16 + col] = $rtoi(sample + 0.5);
            end
        end
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
// synthesis translate_on
