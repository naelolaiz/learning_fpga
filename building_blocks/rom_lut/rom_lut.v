// rom_lut.v - Verilog mirror of ROM_LUT.vhd (storage method A: inline literal).
//
// 32 x 16 entries of 9-bit unsigned magnitude — sin(angle)*nibble for the
// first-quadrant samples. The wrapping quadrant logic mirrors the VHDL
// version: bit5 of the angle index inverts the row (mirror around pi/2),
// bit6 negates the output (lower half of the circle).
//
// The output port is 10 bits = 1 sign + 9 magnitude. Negation uses 2's
// complement so reads in quadrants 3/4 produce a signed-style 10-bit value.

module rom_lut #(
    parameter integer ARRAY_SIZE          = 32,
    parameter integer ELEMENTS_BITS_COUNT = 9
) (
    input  wire                                clock,
    input  wire [6:0]                          read_angle_idx,
    input  wire [3:0]                          nibble_product_idx,
    output reg  [ELEMENTS_BITS_COUNT:0]        data_out
);

    // Flat 1-D backing store; (row, col) packed as row*16 + col so the
    // table layout below reads top-to-bottom, left-to-right exactly
    // like the VHDL literal in ROM_LUT.vhd. Synth tools infer BRAM
    // when the indexing is clocked and not too wide.
    reg [ELEMENTS_BITS_COUNT-1:0] rom [0:ARRAY_SIZE*16-1];

    initial begin
        // row 0  (sin(0) — all zero, kept explicit for parity with VHDL)
        rom[  0] = 9'h000; rom[  1] = 9'h000; rom[  2] = 9'h000; rom[  3] = 9'h000;
        rom[  4] = 9'h000; rom[  5] = 9'h000; rom[  6] = 9'h000; rom[  7] = 9'h000;
        rom[  8] = 9'h000; rom[  9] = 9'h000; rom[ 10] = 9'h000; rom[ 11] = 9'h000;
        rom[ 12] = 9'h000; rom[ 13] = 9'h000; rom[ 14] = 9'h000; rom[ 15] = 9'h000;
        // row 1
        rom[ 16] = 9'h000; rom[ 17] = 9'h002; rom[ 18] = 9'h003; rom[ 19] = 9'h005;
        rom[ 20] = 9'h006; rom[ 21] = 9'h008; rom[ 22] = 9'h009; rom[ 23] = 9'h00b;
        rom[ 24] = 9'h00c; rom[ 25] = 9'h00e; rom[ 26] = 9'h00f; rom[ 27] = 9'h011;
        rom[ 28] = 9'h012; rom[ 29] = 9'h014; rom[ 30] = 9'h015; rom[ 31] = 9'h017;
        // row 2
        rom[ 32] = 9'h000; rom[ 33] = 9'h003; rom[ 34] = 9'h006; rom[ 35] = 9'h009;
        rom[ 36] = 9'h00c; rom[ 37] = 9'h00f; rom[ 38] = 9'h012; rom[ 39] = 9'h015;
        rom[ 40] = 9'h018; rom[ 41] = 9'h01b; rom[ 42] = 9'h01e; rom[ 43] = 9'h021;
        rom[ 44] = 9'h024; rom[ 45] = 9'h028; rom[ 46] = 9'h02b; rom[ 47] = 9'h02e;
        // row 3
        rom[ 48] = 9'h000; rom[ 49] = 9'h005; rom[ 50] = 9'h009; rom[ 51] = 9'h00e;
        rom[ 52] = 9'h012; rom[ 53] = 9'h017; rom[ 54] = 9'h01b; rom[ 55] = 9'h020;
        rom[ 56] = 9'h024; rom[ 57] = 9'h029; rom[ 58] = 9'h02d; rom[ 59] = 9'h032;
        rom[ 60] = 9'h037; rom[ 61] = 9'h03b; rom[ 62] = 9'h040; rom[ 63] = 9'h044;
        // row 4
        rom[ 64] = 9'h000; rom[ 65] = 9'h006; rom[ 66] = 9'h00c; rom[ 67] = 9'h012;
        rom[ 68] = 9'h018; rom[ 69] = 9'h01e; rom[ 70] = 9'h024; rom[ 71] = 9'h02a;
        rom[ 72] = 9'h030; rom[ 73] = 9'h036; rom[ 74] = 9'h03c; rom[ 75] = 9'h043;
        rom[ 76] = 9'h049; rom[ 77] = 9'h04f; rom[ 78] = 9'h055; rom[ 79] = 9'h05b;
        // row 5
        rom[ 80] = 9'h000; rom[ 81] = 9'h008; rom[ 82] = 9'h00f; rom[ 83] = 9'h017;
        rom[ 84] = 9'h01e; rom[ 85] = 9'h026; rom[ 86] = 9'h02d; rom[ 87] = 9'h035;
        rom[ 88] = 9'h03c; rom[ 89] = 9'h044; rom[ 90] = 9'h04b; rom[ 91] = 9'h053;
        rom[ 92] = 9'h05a; rom[ 93] = 9'h062; rom[ 94] = 9'h069; rom[ 95] = 9'h071;
        // row 6
        rom[ 96] = 9'h000; rom[ 97] = 9'h009; rom[ 98] = 9'h012; rom[ 99] = 9'h01b;
        rom[100] = 9'h024; rom[101] = 9'h02d; rom[102] = 9'h036; rom[103] = 9'h03f;
        rom[104] = 9'h048; rom[105] = 9'h051; rom[106] = 9'h05a; rom[107] = 9'h063;
        rom[108] = 9'h06c; rom[109] = 9'h075; rom[110] = 9'h07e; rom[111] = 9'h087;
        // row 7
        rom[112] = 9'h000; rom[113] = 9'h00a; rom[114] = 9'h015; rom[115] = 9'h01f;
        rom[116] = 9'h02a; rom[117] = 9'h034; rom[118] = 9'h03f; rom[119] = 9'h049;
        rom[120] = 9'h054; rom[121] = 9'h05e; rom[122] = 9'h068; rom[123] = 9'h073;
        rom[124] = 9'h07d; rom[125] = 9'h088; rom[126] = 9'h092; rom[127] = 9'h09d;
        // row 8
        rom[128] = 9'h000; rom[129] = 9'h00c; rom[130] = 9'h018; rom[131] = 9'h024;
        rom[132] = 9'h02f; rom[133] = 9'h03b; rom[134] = 9'h047; rom[135] = 9'h053;
        rom[136] = 9'h05f; rom[137] = 9'h06b; rom[138] = 9'h077; rom[139] = 9'h082;
        rom[140] = 9'h08e; rom[141] = 9'h09a; rom[142] = 9'h0a6; rom[143] = 9'h0b2;
        // row 9
        rom[144] = 9'h000; rom[145] = 9'h00d; rom[146] = 9'h01b; rom[147] = 9'h028;
        rom[148] = 9'h035; rom[149] = 9'h042; rom[150] = 9'h050; rom[151] = 9'h05d;
        rom[152] = 9'h06a; rom[153] = 9'h077; rom[154] = 9'h085; rom[155] = 9'h092;
        rom[156] = 9'h09f; rom[157] = 9'h0ac; rom[158] = 9'h0ba; rom[159] = 9'h0c7;
        // row 10
        rom[160] = 9'h000; rom[161] = 9'h00f; rom[162] = 9'h01d; rom[163] = 9'h02c;
        rom[164] = 9'h03a; rom[165] = 9'h049; rom[166] = 9'h058; rom[167] = 9'h066;
        rom[168] = 9'h075; rom[169] = 9'h084; rom[170] = 9'h092; rom[171] = 9'h0a1;
        rom[172] = 9'h0af; rom[173] = 9'h0be; rom[174] = 9'h0cd; rom[175] = 9'h0db;
        // row 11
        rom[176] = 9'h000; rom[177] = 9'h010; rom[178] = 9'h020; rom[179] = 9'h030;
        rom[180] = 9'h040; rom[181] = 9'h050; rom[182] = 9'h060; rom[183] = 9'h070;
        rom[184] = 9'h07f; rom[185] = 9'h08f; rom[186] = 9'h09f; rom[187] = 9'h0af;
        rom[188] = 9'h0bf; rom[189] = 9'h0cf; rom[190] = 9'h0df; rom[191] = 9'h0ef;
        // row 12
        rom[192] = 9'h000; rom[193] = 9'h011; rom[194] = 9'h022; rom[195] = 9'h034;
        rom[196] = 9'h045; rom[197] = 9'h056; rom[198] = 9'h067; rom[199] = 9'h079;
        rom[200] = 9'h08a; rom[201] = 9'h09b; rom[202] = 9'h0ac; rom[203] = 9'h0bd;
        rom[204] = 9'h0cf; rom[205] = 9'h0e0; rom[206] = 9'h0f1; rom[207] = 9'h102;
        // row 13
        rom[208] = 9'h000; rom[209] = 9'h012; rom[210] = 9'h025; rom[211] = 9'h037;
        rom[212] = 9'h04a; rom[213] = 9'h05c; rom[214] = 9'h06f; rom[215] = 9'h081;
        rom[216] = 9'h094; rom[217] = 9'h0a6; rom[218] = 9'h0b9; rom[219] = 9'h0cb;
        rom[220] = 9'h0de; rom[221] = 9'h0f0; rom[222] = 9'h103; rom[223] = 9'h115;
        // row 14
        rom[224] = 9'h000; rom[225] = 9'h014; rom[226] = 9'h027; rom[227] = 9'h03b;
        rom[228] = 9'h04f; rom[229] = 9'h062; rom[230] = 9'h076; rom[231] = 9'h08a;
        rom[232] = 9'h09d; rom[233] = 9'h0b1; rom[234] = 9'h0c5; rom[235] = 9'h0d8;
        rom[236] = 9'h0ec; rom[237] = 9'h100; rom[238] = 9'h113; rom[239] = 9'h127;
        // row 15
        rom[240] = 9'h000; rom[241] = 9'h015; rom[242] = 9'h02a; rom[243] = 9'h03e;
        rom[244] = 9'h053; rom[245] = 9'h068; rom[246] = 9'h07d; rom[247] = 9'h092;
        rom[248] = 9'h0a7; rom[249] = 9'h0bb; rom[250] = 9'h0d0; rom[251] = 9'h0e5;
        rom[252] = 9'h0fa; rom[253] = 9'h10f; rom[254] = 9'h123; rom[255] = 9'h138;
        // row 16
        rom[256] = 9'h000; rom[257] = 9'h016; rom[258] = 9'h02c; rom[259] = 9'h042;
        rom[260] = 9'h058; rom[261] = 9'h06e; rom[262] = 9'h084; rom[263] = 9'h099;
        rom[264] = 9'h0af; rom[265] = 9'h0c5; rom[266] = 9'h0db; rom[267] = 9'h0f1;
        rom[268] = 9'h107; rom[269] = 9'h11d; rom[270] = 9'h133; rom[271] = 9'h149;
        // row 17
        rom[272] = 9'h000; rom[273] = 9'h017; rom[274] = 9'h02e; rom[275] = 9'h045;
        rom[276] = 9'h05c; rom[277] = 9'h073; rom[278] = 9'h08a; rom[279] = 9'h0a1;
        rom[280] = 9'h0b8; rom[281] = 9'h0cf; rom[282] = 9'h0e6; rom[283] = 9'h0fd;
        rom[284] = 9'h114; rom[285] = 9'h12b; rom[286] = 9'h142; rom[287] = 9'h159;
        // row 18
        rom[288] = 9'h000; rom[289] = 9'h018; rom[290] = 9'h030; rom[291] = 9'h048;
        rom[292] = 9'h060; rom[293] = 9'h078; rom[294] = 9'h090; rom[295] = 9'h0a8;
        rom[296] = 9'h0c0; rom[297] = 9'h0d8; rom[298] = 9'h0f0; rom[299] = 9'h108;
        rom[300] = 9'h120; rom[301] = 9'h138; rom[302] = 9'h14f; rom[303] = 9'h167;
        // row 19
        rom[304] = 9'h000; rom[305] = 9'h019; rom[306] = 9'h032; rom[307] = 9'h04b;
        rom[308] = 9'h064; rom[309] = 9'h07c; rom[310] = 9'h095; rom[311] = 9'h0ae;
        rom[312] = 9'h0c7; rom[313] = 9'h0e0; rom[314] = 9'h0f9; rom[315] = 9'h112;
        rom[316] = 9'h12b; rom[317] = 9'h144; rom[318] = 9'h15d; rom[319] = 9'h175;
        // row 20
        rom[320] = 9'h000; rom[321] = 9'h01a; rom[322] = 9'h034; rom[323] = 9'h04d;
        rom[324] = 9'h067; rom[325] = 9'h081; rom[326] = 9'h09b; rom[327] = 9'h0b4;
        rom[328] = 9'h0ce; rom[329] = 9'h0e8; rom[330] = 9'h102; rom[331] = 9'h11c;
        rom[332] = 9'h135; rom[333] = 9'h14f; rom[334] = 9'h169; rom[335] = 9'h183;
        // row 21
        rom[336] = 9'h000; rom[337] = 9'h01b; rom[338] = 9'h035; rom[339] = 9'h050;
        rom[340] = 9'h06a; rom[341] = 9'h085; rom[342] = 9'h0a0; rom[343] = 9'h0ba;
        rom[344] = 9'h0d5; rom[345] = 9'h0ef; rom[346] = 9'h10a; rom[347] = 9'h124;
        rom[348] = 9'h13f; rom[349] = 9'h15a; rom[350] = 9'h174; rom[351] = 9'h18f;
        // row 22
        rom[352] = 9'h000; rom[353] = 9'h01b; rom[354] = 9'h037; rom[355] = 9'h052;
        rom[356] = 9'h06d; rom[357] = 9'h089; rom[358] = 9'h0a4; rom[359] = 9'h0bf;
        rom[360] = 9'h0db; rom[361] = 9'h0f6; rom[362] = 9'h111; rom[363] = 9'h12d;
        rom[364] = 9'h148; rom[365] = 9'h163; rom[366] = 9'h17f; rom[367] = 9'h19a;
        // row 23
        rom[368] = 9'h000; rom[369] = 9'h01c; rom[370] = 9'h038; rom[371] = 9'h054;
        rom[372] = 9'h070; rom[373] = 9'h08c; rom[374] = 9'h0a8; rom[375] = 9'h0c4;
        rom[376] = 9'h0e0; rom[377] = 9'h0fc; rom[378] = 9'h118; rom[379] = 9'h134;
        rom[380] = 9'h150; rom[381] = 9'h16c; rom[382] = 9'h188; rom[383] = 9'h1a4;
        // row 24
        rom[384] = 9'h000; rom[385] = 9'h01d; rom[386] = 9'h039; rom[387] = 9'h056;
        rom[388] = 9'h073; rom[389] = 9'h08f; rom[390] = 9'h0ac; rom[391] = 9'h0c8;
        rom[392] = 9'h0e5; rom[393] = 9'h102; rom[394] = 9'h11e; rom[395] = 9'h13b;
        rom[396] = 9'h158; rom[397] = 9'h174; rom[398] = 9'h191; rom[399] = 9'h1ae;
        // row 25
        rom[400] = 9'h000; rom[401] = 9'h01d; rom[402] = 9'h03a; rom[403] = 9'h058;
        rom[404] = 9'h075; rom[405] = 9'h092; rom[406] = 9'h0af; rom[407] = 9'h0cc;
        rom[408] = 9'h0ea; rom[409] = 9'h107; rom[410] = 9'h124; rom[411] = 9'h141;
        rom[412] = 9'h15e; rom[413] = 9'h17b; rom[414] = 9'h199; rom[415] = 9'h1b6;
        // row 26
        rom[416] = 9'h000; rom[417] = 9'h01e; rom[418] = 9'h03b; rom[419] = 9'h059;
        rom[420] = 9'h077; rom[421] = 9'h094; rom[422] = 9'h0b2; rom[423] = 9'h0d0;
        rom[424] = 9'h0ed; rom[425] = 9'h10b; rom[426] = 9'h129; rom[427] = 9'h146;
        rom[428] = 9'h164; rom[429] = 9'h182; rom[430] = 9'h19f; rom[431] = 9'h1bd;
        // row 27
        rom[432] = 9'h000; rom[433] = 9'h01e; rom[434] = 9'h03c; rom[435] = 9'h05a;
        rom[436] = 9'h078; rom[437] = 9'h096; rom[438] = 9'h0b4; rom[439] = 9'h0d2;
        rom[440] = 9'h0f1; rom[441] = 9'h10f; rom[442] = 9'h12d; rom[443] = 9'h14b;
        rom[444] = 9'h169; rom[445] = 9'h187; rom[446] = 9'h1a5; rom[447] = 9'h1c3;
        // row 28
        rom[448] = 9'h000; rom[449] = 9'h01e; rom[450] = 9'h03d; rom[451] = 9'h05b;
        rom[452] = 9'h07a; rom[453] = 9'h098; rom[454] = 9'h0b6; rom[455] = 9'h0d5;
        rom[456] = 9'h0f3; rom[457] = 9'h112; rom[458] = 9'h130; rom[459] = 9'h14e;
        rom[460] = 9'h16d; rom[461] = 9'h18b; rom[462] = 9'h1aa; rom[463] = 9'h1c8;
        // row 29
        rom[464] = 9'h000; rom[465] = 9'h01f; rom[466] = 9'h03d; rom[467] = 9'h05c;
        rom[468] = 9'h07b; rom[469] = 9'h099; rom[470] = 9'h0b8; rom[471] = 9'h0d7;
        rom[472] = 9'h0f5; rom[473] = 9'h114; rom[474] = 9'h133; rom[475] = 9'h151;
        rom[476] = 9'h170; rom[477] = 9'h18f; rom[478] = 9'h1ad; rom[479] = 9'h1cc;
        // row 30
        rom[480] = 9'h000; rom[481] = 9'h01f; rom[482] = 9'h03e; rom[483] = 9'h05d;
        rom[484] = 9'h07b; rom[485] = 9'h09a; rom[486] = 9'h0b9; rom[487] = 9'h0d8;
        rom[488] = 9'h0f7; rom[489] = 9'h116; rom[490] = 9'h135; rom[491] = 9'h153;
        rom[492] = 9'h172; rom[493] = 9'h191; rom[494] = 9'h1b0; rom[495] = 9'h1cf;
        // row 31  (sin(pi/2) — peak row, *15 column = 9'h1d0 = 464)
        rom[496] = 9'h000; rom[497] = 9'h01f; rom[498] = 9'h03e; rom[499] = 9'h05d;
        rom[500] = 9'h07c; rom[501] = 9'h09b; rom[502] = 9'h0ba; rom[503] = 9'h0d9;
        rom[504] = 9'h0f8; rom[505] = 9'h117; rom[506] = 9'h136; rom[507] = 9'h155;
        rom[508] = 9'h174; rom[509] = 9'h193; rom[510] = 9'h1b1; rom[511] = 9'h1d0;
    end

    // --- Address decode (mirrors the VHDL aliases) -------------------
    wire        secondOrFourthQuadrant = read_angle_idx[5];
    wire        thirdOrFourthQuadrant  = read_angle_idx[6];
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
            // Negate as 10-bit signed (0 - magnitude). For magnitude 0 this
            // yields exactly 0 (no -0 weirdness in 2's complement).
            data_out <= -{1'b0, rom_value};
        else
            data_out <= {1'b0, rom_value};
    end

endmodule
