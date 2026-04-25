// trigonometric_functions.vh — Verilog mirror of trigonometric.vhd.
//
// Meant to be ``include``d *inside* a module body. Provides:
//
//   multiplyBySinLUT(index, inputValue)  — 8-bit signed output
//   multiplyByCosLUT(index, inputValue)
//   rotate_x(sprite_w, sprite_h, px, py, rotation) — Pos2D.x component
//   rotate_y(sprite_w, sprite_h, px, py, rotation) — Pos2D.y component
//   translateOriginToCenterOfSprite_x / _y (sprite_w, sprite_h, x, y)
//   translateOriginBackToFirstBitCorner_x / _y (sprite_w, sprite_h, x, y)
//
// All math mirrors the VHDL bit-for-bit (8-bit fixed-point truncation
// toward zero), so the property assertions in the testbenches hit the
// same numerical ranges GHDL produces.

`ifndef TRIGONOMETRIC_FUNCTIONS_VH
`define TRIGONOMETRIC_FUNCTIONS_VH

// 16-row x 16-col sin·x LUT (8-bit unsigned). Indexed by the low 4 bits
// of the rotation index and the 4-bit nibble of |inputValue|. The high
// bit of the rotation index selects the output sign (the "sinIsNegative"
// bit in the VHDL).
function automatic [7:0] trig_lut_entry(input [3:0] row, input [3:0] col);
    case ({row, col})
        8'h00: trig_lut_entry = 8'b00000000; 8'h01: trig_lut_entry = 8'b00000000;
        8'h02: trig_lut_entry = 8'b00000000; 8'h03: trig_lut_entry = 8'b00000000;
        8'h04: trig_lut_entry = 8'b00000000; 8'h05: trig_lut_entry = 8'b00000000;
        8'h06: trig_lut_entry = 8'b00000000; 8'h07: trig_lut_entry = 8'b00000000;
        8'h08: trig_lut_entry = 8'b00000000; 8'h09: trig_lut_entry = 8'b00000000;
        8'h0A: trig_lut_entry = 8'b00000000; 8'h0B: trig_lut_entry = 8'b00000000;
        8'h0C: trig_lut_entry = 8'b00000000; 8'h0D: trig_lut_entry = 8'b00000000;
        8'h0E: trig_lut_entry = 8'b00000000; 8'h0F: trig_lut_entry = 8'b00000000;

        8'h10: trig_lut_entry = 8'b00000000; 8'h11: trig_lut_entry = 8'b00000011;
        8'h12: trig_lut_entry = 8'b00000110; 8'h13: trig_lut_entry = 8'b00001001;
        8'h14: trig_lut_entry = 8'b00001100; 8'h15: trig_lut_entry = 8'b00001111;
        8'h16: trig_lut_entry = 8'b00010010; 8'h17: trig_lut_entry = 8'b00010101;
        8'h18: trig_lut_entry = 8'b00011000; 8'h19: trig_lut_entry = 8'b00011011;
        8'h1A: trig_lut_entry = 8'b00011110; 8'h1B: trig_lut_entry = 8'b00100001;
        8'h1C: trig_lut_entry = 8'b00100100; 8'h1D: trig_lut_entry = 8'b00100111;
        8'h1E: trig_lut_entry = 8'b00101010; 8'h1F: trig_lut_entry = 8'b00101101;

        8'h20: trig_lut_entry = 8'b00000000; 8'h21: trig_lut_entry = 8'b00000110;
        8'h22: trig_lut_entry = 8'b00001100; 8'h23: trig_lut_entry = 8'b00010010;
        8'h24: trig_lut_entry = 8'b00011000; 8'h25: trig_lut_entry = 8'b00011110;
        8'h26: trig_lut_entry = 8'b00100100; 8'h27: trig_lut_entry = 8'b00101010;
        8'h28: trig_lut_entry = 8'b00110000; 8'h29: trig_lut_entry = 8'b00110110;
        8'h2A: trig_lut_entry = 8'b00111100; 8'h2B: trig_lut_entry = 8'b01000010;
        8'h2C: trig_lut_entry = 8'b01001000; 8'h2D: trig_lut_entry = 8'b01001110;
        8'h2E: trig_lut_entry = 8'b01010100; 8'h2F: trig_lut_entry = 8'b01011010;

        8'h30: trig_lut_entry = 8'b00000000; 8'h31: trig_lut_entry = 8'b00001001;
        8'h32: trig_lut_entry = 8'b00010010; 8'h33: trig_lut_entry = 8'b00011011;
        8'h34: trig_lut_entry = 8'b00100100; 8'h35: trig_lut_entry = 8'b00101101;
        8'h36: trig_lut_entry = 8'b00110110; 8'h37: trig_lut_entry = 8'b00111111;
        8'h38: trig_lut_entry = 8'b01001000; 8'h39: trig_lut_entry = 8'b01010001;
        8'h3A: trig_lut_entry = 8'b01011010; 8'h3B: trig_lut_entry = 8'b01100011;
        8'h3C: trig_lut_entry = 8'b01101100; 8'h3D: trig_lut_entry = 8'b01110101;
        8'h3E: trig_lut_entry = 8'b01111110; 8'h3F: trig_lut_entry = 8'b10000111;

        8'h40: trig_lut_entry = 8'b00000000; 8'h41: trig_lut_entry = 8'b00001011;
        8'h42: trig_lut_entry = 8'b00010110; 8'h43: trig_lut_entry = 8'b00100001;
        8'h44: trig_lut_entry = 8'b00101100; 8'h45: trig_lut_entry = 8'b00110111;
        8'h46: trig_lut_entry = 8'b01000010; 8'h47: trig_lut_entry = 8'b01001101;
        8'h48: trig_lut_entry = 8'b01011000; 8'h49: trig_lut_entry = 8'b01100011;
        8'h4A: trig_lut_entry = 8'b01101110; 8'h4B: trig_lut_entry = 8'b01111001;
        8'h4C: trig_lut_entry = 8'b10000100; 8'h4D: trig_lut_entry = 8'b10001111;
        8'h4E: trig_lut_entry = 8'b10011010; 8'h4F: trig_lut_entry = 8'b10100101;

        8'h50: trig_lut_entry = 8'b00000000; 8'h51: trig_lut_entry = 8'b00001101;
        8'h52: trig_lut_entry = 8'b00011010; 8'h53: trig_lut_entry = 8'b00100111;
        8'h54: trig_lut_entry = 8'b00110100; 8'h55: trig_lut_entry = 8'b01000001;
        8'h56: trig_lut_entry = 8'b01001110; 8'h57: trig_lut_entry = 8'b01011011;
        8'h58: trig_lut_entry = 8'b01101000; 8'h59: trig_lut_entry = 8'b01110101;
        8'h5A: trig_lut_entry = 8'b10000010; 8'h5B: trig_lut_entry = 8'b10001111;
        8'h5C: trig_lut_entry = 8'b10011100; 8'h5D: trig_lut_entry = 8'b10101001;
        8'h5E: trig_lut_entry = 8'b10110110; 8'h5F: trig_lut_entry = 8'b11000011;

        8'h60: trig_lut_entry = 8'b00000000; 8'h61: trig_lut_entry = 8'b00001111;
        8'h62: trig_lut_entry = 8'b00011110; 8'h63: trig_lut_entry = 8'b00101101;
        8'h64: trig_lut_entry = 8'b00111100; 8'h65: trig_lut_entry = 8'b01001011;
        8'h66: trig_lut_entry = 8'b01011010; 8'h67: trig_lut_entry = 8'b01101001;
        8'h68: trig_lut_entry = 8'b01111000; 8'h69: trig_lut_entry = 8'b10000111;
        8'h6A: trig_lut_entry = 8'b10010110; 8'h6B: trig_lut_entry = 8'b10100101;
        8'h6C: trig_lut_entry = 8'b10110100; 8'h6D: trig_lut_entry = 8'b11000011;
        8'h6E: trig_lut_entry = 8'b11010010; 8'h6F: trig_lut_entry = 8'b11100001;

        // Rows 7-9 are identical — sin·x is approximately constant near
        // peak sine.
        8'h70: trig_lut_entry = 8'b00000000; 8'h71: trig_lut_entry = 8'b00010000;
        8'h72: trig_lut_entry = 8'b00100000; 8'h73: trig_lut_entry = 8'b00110000;
        8'h74: trig_lut_entry = 8'b01000000; 8'h75: trig_lut_entry = 8'b01010000;
        8'h76: trig_lut_entry = 8'b01100000; 8'h77: trig_lut_entry = 8'b01110000;
        8'h78: trig_lut_entry = 8'b10000000; 8'h79: trig_lut_entry = 8'b10010000;
        8'h7A: trig_lut_entry = 8'b10100000; 8'h7B: trig_lut_entry = 8'b10110000;
        8'h7C: trig_lut_entry = 8'b11000000; 8'h7D: trig_lut_entry = 8'b11010000;
        8'h7E: trig_lut_entry = 8'b11100000; 8'h7F: trig_lut_entry = 8'b11110000;

        8'h80: trig_lut_entry = 8'b00000000; 8'h81: trig_lut_entry = 8'b00010000;
        8'h82: trig_lut_entry = 8'b00100000; 8'h83: trig_lut_entry = 8'b00110000;
        8'h84: trig_lut_entry = 8'b01000000; 8'h85: trig_lut_entry = 8'b01010000;
        8'h86: trig_lut_entry = 8'b01100000; 8'h87: trig_lut_entry = 8'b01110000;
        8'h88: trig_lut_entry = 8'b10000000; 8'h89: trig_lut_entry = 8'b10010000;
        8'h8A: trig_lut_entry = 8'b10100000; 8'h8B: trig_lut_entry = 8'b10110000;
        8'h8C: trig_lut_entry = 8'b11000000; 8'h8D: trig_lut_entry = 8'b11010000;
        8'h8E: trig_lut_entry = 8'b11100000; 8'h8F: trig_lut_entry = 8'b11110000;

        8'h90: trig_lut_entry = 8'b00000000; 8'h91: trig_lut_entry = 8'b00010000;
        8'h92: trig_lut_entry = 8'b00100000; 8'h93: trig_lut_entry = 8'b00110000;
        8'h94: trig_lut_entry = 8'b01000000; 8'h95: trig_lut_entry = 8'b01010000;
        8'h96: trig_lut_entry = 8'b01100000; 8'h97: trig_lut_entry = 8'b01110000;
        8'h98: trig_lut_entry = 8'b10000000; 8'h99: trig_lut_entry = 8'b10010000;
        8'h9A: trig_lut_entry = 8'b10100000; 8'h9B: trig_lut_entry = 8'b10110000;
        8'h9C: trig_lut_entry = 8'b11000000; 8'h9D: trig_lut_entry = 8'b11010000;
        8'h9E: trig_lut_entry = 8'b11100000; 8'h9F: trig_lut_entry = 8'b11110000;

        // Rows 10-15 mirror 1-6 (sin(π/2 + θ) = sin(π/2 - θ)).
        8'hA0: trig_lut_entry = 8'b00000000; 8'hA1: trig_lut_entry = 8'b00001111;
        8'hA2: trig_lut_entry = 8'b00011110; 8'hA3: trig_lut_entry = 8'b00101101;
        8'hA4: trig_lut_entry = 8'b00111100; 8'hA5: trig_lut_entry = 8'b01001011;
        8'hA6: trig_lut_entry = 8'b01011010; 8'hA7: trig_lut_entry = 8'b01101001;
        8'hA8: trig_lut_entry = 8'b01111000; 8'hA9: trig_lut_entry = 8'b10000111;
        8'hAA: trig_lut_entry = 8'b10010110; 8'hAB: trig_lut_entry = 8'b10100101;
        8'hAC: trig_lut_entry = 8'b10110100; 8'hAD: trig_lut_entry = 8'b11000011;
        8'hAE: trig_lut_entry = 8'b11010010; 8'hAF: trig_lut_entry = 8'b11100001;

        8'hB0: trig_lut_entry = 8'b00000000; 8'hB1: trig_lut_entry = 8'b00001101;
        8'hB2: trig_lut_entry = 8'b00011010; 8'hB3: trig_lut_entry = 8'b00100111;
        8'hB4: trig_lut_entry = 8'b00110100; 8'hB5: trig_lut_entry = 8'b01000001;
        8'hB6: trig_lut_entry = 8'b01001110; 8'hB7: trig_lut_entry = 8'b01011011;
        8'hB8: trig_lut_entry = 8'b01101000; 8'hB9: trig_lut_entry = 8'b01110101;
        8'hBA: trig_lut_entry = 8'b10000010; 8'hBB: trig_lut_entry = 8'b10001111;
        8'hBC: trig_lut_entry = 8'b10011100; 8'hBD: trig_lut_entry = 8'b10101001;
        8'hBE: trig_lut_entry = 8'b10110110; 8'hBF: trig_lut_entry = 8'b11000011;

        8'hC0: trig_lut_entry = 8'b00000000; 8'hC1: trig_lut_entry = 8'b00001011;
        8'hC2: trig_lut_entry = 8'b00010110; 8'hC3: trig_lut_entry = 8'b00100001;
        8'hC4: trig_lut_entry = 8'b00101100; 8'hC5: trig_lut_entry = 8'b00110111;
        8'hC6: trig_lut_entry = 8'b01000010; 8'hC7: trig_lut_entry = 8'b01001101;
        8'hC8: trig_lut_entry = 8'b01011000; 8'hC9: trig_lut_entry = 8'b01100011;
        8'hCA: trig_lut_entry = 8'b01101110; 8'hCB: trig_lut_entry = 8'b01111001;
        8'hCC: trig_lut_entry = 8'b10000100; 8'hCD: trig_lut_entry = 8'b10001111;
        8'hCE: trig_lut_entry = 8'b10011010; 8'hCF: trig_lut_entry = 8'b10100101;

        8'hD0: trig_lut_entry = 8'b00000000; 8'hD1: trig_lut_entry = 8'b00001001;
        8'hD2: trig_lut_entry = 8'b00010010; 8'hD3: trig_lut_entry = 8'b00011011;
        8'hD4: trig_lut_entry = 8'b00100100; 8'hD5: trig_lut_entry = 8'b00101101;
        8'hD6: trig_lut_entry = 8'b00110110; 8'hD7: trig_lut_entry = 8'b00111111;
        8'hD8: trig_lut_entry = 8'b01001000; 8'hD9: trig_lut_entry = 8'b01010001;
        8'hDA: trig_lut_entry = 8'b01011010; 8'hDB: trig_lut_entry = 8'b01100011;
        8'hDC: trig_lut_entry = 8'b01101100; 8'hDD: trig_lut_entry = 8'b01110101;
        8'hDE: trig_lut_entry = 8'b01111110; 8'hDF: trig_lut_entry = 8'b10000111;

        8'hE0: trig_lut_entry = 8'b00000000; 8'hE1: trig_lut_entry = 8'b00000110;
        8'hE2: trig_lut_entry = 8'b00001100; 8'hE3: trig_lut_entry = 8'b00010010;
        8'hE4: trig_lut_entry = 8'b00011000; 8'hE5: trig_lut_entry = 8'b00011110;
        8'hE6: trig_lut_entry = 8'b00100100; 8'hE7: trig_lut_entry = 8'b00101010;
        8'hE8: trig_lut_entry = 8'b00110000; 8'hE9: trig_lut_entry = 8'b00110110;
        8'hEA: trig_lut_entry = 8'b00111100; 8'hEB: trig_lut_entry = 8'b01000010;
        8'hEC: trig_lut_entry = 8'b01001000; 8'hED: trig_lut_entry = 8'b01001110;
        8'hEE: trig_lut_entry = 8'b01010100; 8'hEF: trig_lut_entry = 8'b01011010;

        8'hF0: trig_lut_entry = 8'b00000000; 8'hF1: trig_lut_entry = 8'b00000011;
        8'hF2: trig_lut_entry = 8'b00000110; 8'hF3: trig_lut_entry = 8'b00001001;
        8'hF4: trig_lut_entry = 8'b00001100; 8'hF5: trig_lut_entry = 8'b00001111;
        8'hF6: trig_lut_entry = 8'b00010010; 8'hF7: trig_lut_entry = 8'b00010101;
        8'hF8: trig_lut_entry = 8'b00011000; 8'hF9: trig_lut_entry = 8'b00011011;
        8'hFA: trig_lut_entry = 8'b00011110; 8'hFB: trig_lut_entry = 8'b00100001;
        8'hFC: trig_lut_entry = 8'b00100100; 8'hFD: trig_lut_entry = 8'b00100111;
        8'hFE: trig_lut_entry = 8'b00101010; 8'hFF: trig_lut_entry = 8'b00101101;
        default: trig_lut_entry = 8'b00000000;
    endcase
endfunction

// sin(rotation)·inputValue, 8-bit signed. Mirrors VHDL
// multiplyBySinLUT bit-for-bit: take |inputValue|, look up the two
// nibbles in the sin-row, add the lower-nibble product into the upper
// nibble of the 12-bit accumulator, then apply the combined sign
// (sinIsNegative XOR inputIsNegative) and return bits [11:4].
function automatic [7:0] multiplyBySinLUT(input [4:0] idx, input [7:0] inputValue);
    reg        sinIsNegative;
    reg        inputIsNegative;
    reg [7:0]  absInput;
    reg [3:0]  row;
    reg [3:0]  loNib;
    reg [3:0]  hiNib;
    reg [7:0]  opProduct;     // row[loNib]
    reg [11:0] sum;            // {row[hiNib], 4'b0} + opProduct
    reg [11:0] signedSum;
    begin
        sinIsNegative   = idx[4];
        inputIsNegative = inputValue[7];
        absInput        = inputIsNegative ? (~inputValue + 8'd1) : inputValue;
        row   = idx[3:0];
        loNib = absInput[3:0];
        hiNib = absInput[7:4];
        opProduct = trig_lut_entry(row, loNib);
        sum = {trig_lut_entry(row, hiNib), 4'b0000} + {4'b0000, opProduct};
        if (sinIsNegative ^ inputIsNegative)
            signedSum = -sum;
        else
            signedSum = sum;
        multiplyBySinLUT = signedSum[11:4];
    end
endfunction

// cos(idx) = sin(idx + 8) under a 32-step circle.
function automatic [7:0] multiplyByCosLUT(input [4:0] idx, input [7:0] inputValue);
    begin
        multiplyByCosLUT = multiplyBySinLUT((idx + 5'd8) & 5'd31, inputValue);
    end
endfunction

// rotate(): returns the two components of the rotated Pos2D as separate
// integers. sprite_w / sprite_h are unused in the math itself (the
// VHDL keeps them for a commented-out divisor), but exposed for parity.
function automatic integer rotate_x(input integer sprite_w,
                                    input integer sprite_h,
                                    input integer px,
                                    input integer py,
                                    input [4:0]   rotation);
    reg signed [7:0] cosPx;
    reg signed [7:0] sinPy;
    begin
        cosPx = $signed(multiplyByCosLUT(rotation, px[7:0]));
        sinPy = $signed(multiplyBySinLUT(rotation, py[7:0]));
        rotate_x = cosPx - sinPy;
    end
endfunction

function automatic integer rotate_y(input integer sprite_w,
                                    input integer sprite_h,
                                    input integer px,
                                    input integer py,
                                    input [4:0]   rotation);
    reg signed [7:0] sinPx;
    reg signed [7:0] cosPy;
    begin
        sinPx = $signed(multiplyBySinLUT(rotation, px[7:0]));
        cosPy = $signed(multiplyByCosLUT(rotation, py[7:0]));
        rotate_y = sinPx + cosPy;
    end
endfunction

function automatic integer translateOriginToCenterOfSprite_x(input integer sprite_w,
                                                             input integer x);
    translateOriginToCenterOfSprite_x = x - (sprite_w / 2);
endfunction

function automatic integer translateOriginToCenterOfSprite_y(input integer sprite_h,
                                                             input integer y);
    translateOriginToCenterOfSprite_y = y - (sprite_h / 2);
endfunction

function automatic integer translateOriginBackToFirstBitCorner_x(input integer sprite_w,
                                                                 input integer x);
    translateOriginBackToFirstBitCorner_x = x + (sprite_w / 2);
endfunction

function automatic integer translateOriginBackToFirstBitCorner_y(input integer sprite_h,
                                                                 input integer y);
    translateOriginBackToFirstBitCorner_y = y + (sprite_h / 2);
endfunction

`endif
