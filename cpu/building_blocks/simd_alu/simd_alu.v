// simd_alu.v - Verilog mirror of simd_alu.vhd.
//
// See the VHDL twin's header for the lane shapes, op encoding,
// saturation contract, and flags semantics. The body below
// translates 1:1.

`default_nettype none

module simd_alu (
    input  wire [31:0] a,
    input  wire [31:0] b,
    input  wire [3:0]  op,
    output reg  [31:0] result,
    output reg  [3:0]  flags
);

    wire        width_sel = op[3];
    wire [1:0]  op_sel    = op[2:1];
    wire        saturate  = op[0];

    // 8-bit signed saturating add/sub. Returns {lane[7:0], sat_flag}.
    function automatic [8:0] sat_addsub_8;
        input signed [7:0] av;
        input signed [7:0] bv;
        input              is_sub;
        input              do_sat;
        reg signed [8:0]   wide;
        reg signed [7:0]   clamped;
        reg                was_sat;
    begin
        wide    = is_sub ? ({av[7], av} - {bv[7], bv})
                         : ({av[7], av} + {bv[7], bv});
        was_sat = 1'b0;
        if (do_sat && wide > 127) begin
            clamped = 8'sd127;
            was_sat = 1'b1;
        end else if (do_sat && wide < -128) begin
            clamped = -8'sd128;
            was_sat = 1'b1;
        end else begin
            clamped = wide[7:0];   // wrap
        end
        sat_addsub_8 = {clamped, was_sat};
    end
    endfunction

    function automatic [16:0] sat_addsub_16;
        input signed [15:0] av;
        input signed [15:0] bv;
        input               is_sub;
        input               do_sat;
        reg signed [16:0]   wide;
        reg signed [15:0]   clamped;
        reg                 was_sat;
    begin
        wide    = is_sub ? ({av[15], av} - {bv[15], bv})
                         : ({av[15], av} + {bv[15], bv});
        was_sat = 1'b0;
        if (do_sat && wide > 32767) begin
            clamped = 16'sd32767;
            was_sat = 1'b1;
        end else if (do_sat && wide < -32768) begin
            clamped = -16'sd32768;
            was_sat = 1'b1;
        end else begin
            clamped = wide[15:0];
        end
        sat_addsub_16 = {clamped, was_sat};
    end
    endfunction

    integer            lane;
    reg signed [7:0]   a8, b8;
    reg signed [15:0]  a16, b16;
    reg [8:0]          lane8_out;
    reg [16:0]         lane16_out;
    reg                is_sub_w;
    reg                do_sat_w;

    always @(*) begin
        result   = 32'b0;
        flags    = 4'b0;
        is_sub_w = (op_sel == 2'b01);
        do_sat_w = (saturate == 1'b1);

        if (!width_sel) begin
            // 4 × 8-bit lanes
            for (lane = 0; lane < 4; lane = lane + 1) begin
                a8 = a[lane*8 +: 8];
                b8 = b[lane*8 +: 8];
                case (op_sel)
                    2'b00, 2'b01: begin
                        lane8_out = sat_addsub_8(a8, b8, is_sub_w, do_sat_w);
                        result[lane*8 +: 8] = lane8_out[8:1];
                        flags[lane]         = lane8_out[0];
                    end
                    2'b10: begin   // signed min
                        result[lane*8 +: 8] = (a8 < b8) ? a8 : b8;
                    end
                    default: begin // 2'b11, signed max
                        result[lane*8 +: 8] = (a8 > b8) ? a8 : b8;
                    end
                endcase
            end
        end else begin
            // 2 × 16-bit lanes
            for (lane = 0; lane < 2; lane = lane + 1) begin
                a16 = a[lane*16 +: 16];
                b16 = b[lane*16 +: 16];
                case (op_sel)
                    2'b00, 2'b01: begin
                        lane16_out = sat_addsub_16(a16, b16, is_sub_w, do_sat_w);
                        result[lane*16 +: 16] = lane16_out[16:1];
                        flags[lane]           = lane16_out[0];
                    end
                    2'b10: begin
                        result[lane*16 +: 16] = (a16 < b16) ? a16 : b16;
                    end
                    default: begin
                        result[lane*16 +: 16] = (a16 > b16) ? a16 : b16;
                    end
                endcase
            end
        end
    end

endmodule

`default_nettype wire
