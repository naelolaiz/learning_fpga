// i2s_master.v - Verilog mirror of i2s_master.vhd.
//
// Two phase-accumulator dividers generate MCLK (from the system
// clock) and BCK (from MCLK); a 4-state FSM runs on BCK falling
// edges and serialises 24 bits of data_l, then 24 bits of data_r,
// MSB-first per channel. The state encoding matches the VHDL twin:
//   00 = START_L, 01 = SEND_L, 10 = START_R, 11 = SEND_R.

module i2s_master #(
    parameter integer CLK_FREQ      = 50_000_000,
    parameter integer MCLK_FREQ     = 24_576_000,
    parameter integer I2S_BIT_WIDTH = 24
) (
    input  wire                          reset,         // active-high
    input  wire                          clk,
    output wire                          mclk,
    // Init lrclk/sdata in the declaration: posedge reset doesn't fire
    // for a reg-init "transition", so without this the outputs sit at
    // 'x' until the first negedge sclk and that 'x' propagates through
    // the LUT-clock path.
    output reg                           lrclk = 1'b0,
    output wire                          sclk,
    output reg                           sdata = 1'b0,
    input  wire [I2S_BIT_WIDTH-1:0]      data_l,
    input  wire [I2S_BIT_WIDTH-1:0]      data_r
);

    localparam integer MCLK_ACC_WIDTH = 16;
    localparam integer SCLK_ACC_WIDTH = 16;

    // Same fixed-point math as the VHDL: the increment is a 16-bit
    // value chosen so the accumulator's MSB toggles at the desired
    // clock rate on average. Real-typed math at elaboration time so
    // the result is rounded once.
    localparam integer MCLK_ACC_INC =
        $rtoi((1.0 * (1 << MCLK_ACC_WIDTH)) / (1.0*CLK_FREQ / (1.0*MCLK_FREQ)));

    localparam real SCLK_FREQ_R =
        (1.0*MCLK_FREQ / 256.0) * (2.0 * I2S_BIT_WIDTH);
    localparam integer SCLK_ACC_INC =
        $rtoi((1.0 * (1 << SCLK_ACC_WIDTH)) / (1.0*MCLK_FREQ / SCLK_FREQ_R));

    reg [MCLK_ACC_WIDTH-1:0] mclk_acc = {MCLK_ACC_WIDTH{1'b0}};
    reg [SCLK_ACC_WIDTH-1:0] sclk_acc = {SCLK_ACC_WIDTH{1'b0}};

    always @(posedge clk or posedge reset) begin
        if (reset) mclk_acc <= {MCLK_ACC_WIDTH{1'b0}};
        else       mclk_acc <= mclk_acc + MCLK_ACC_INC[MCLK_ACC_WIDTH-1:0];
    end
    assign mclk = mclk_acc[MCLK_ACC_WIDTH-1];

    always @(posedge mclk or posedge reset) begin
        if (reset) sclk_acc <= {SCLK_ACC_WIDTH{1'b0}};
        else       sclk_acc <= sclk_acc + SCLK_ACC_INC[SCLK_ACC_WIDTH-1:0];
    end
    assign sclk = sclk_acc[SCLK_ACC_WIDTH-1];

    localparam [1:0] S_START_L = 2'b00;
    localparam [1:0] S_SEND_L  = 2'b01;
    localparam [1:0] S_START_R = 2'b10;
    localparam [1:0] S_SEND_R  = 2'b11;

    reg [1:0] state = S_START_L;
    reg [I2S_BIT_WIDTH-1:0] data_l_i = {I2S_BIT_WIDTH{1'b0}};
    reg [I2S_BIT_WIDTH-1:0] data_r_i = {I2S_BIT_WIDTH{1'b0}};
    reg [4:0]               bit_cnt  = 5'd0;

    always @(negedge sclk or posedge reset) begin
        if (reset) begin
            data_l_i <= {I2S_BIT_WIDTH{1'b0}};
            data_r_i <= {I2S_BIT_WIDTH{1'b0}};
            lrclk    <= 1'b0;
            sdata    <= 1'b0;
            state    <= S_START_L;
            bit_cnt  <= 5'd0;
        end else begin
            case (state)
                S_START_L: begin
                    lrclk   <= 1'b0;
                    sdata   <= data_l_i[I2S_BIT_WIDTH-1];
                    bit_cnt <= bit_cnt + 5'd1;
                    state   <= S_SEND_L;
                end

                S_SEND_L: begin
                    lrclk    <= 1'b0;
                    sdata    <= data_l_i[I2S_BIT_WIDTH-1];
                    data_l_i <= {data_l_i[I2S_BIT_WIDTH-2:0], 1'b0};
                    if (bit_cnt == I2S_BIT_WIDTH-1) begin
                        bit_cnt <= 5'd0;
                        state   <= S_START_R;
                    end else begin
                        bit_cnt <= bit_cnt + 5'd1;
                    end
                end

                S_START_R: begin
                    lrclk   <= 1'b1;
                    sdata   <= data_r_i[I2S_BIT_WIDTH-1];
                    bit_cnt <= bit_cnt + 5'd1;
                    state   <= S_SEND_R;
                end

                S_SEND_R: begin
                    lrclk    <= 1'b1;
                    sdata    <= data_r_i[I2S_BIT_WIDTH-1];
                    data_r_i <= {data_r_i[I2S_BIT_WIDTH-2:0], 1'b0};
                    if (bit_cnt == I2S_BIT_WIDTH-1) begin
                        bit_cnt  <= 5'd0;
                        // Latch next-frame samples right at the loop-back.
                        data_l_i <= data_l;
                        data_r_i <= data_r;
                        state    <= S_START_L;
                    end else begin
                        bit_cnt <= bit_cnt + 5'd1;
                    end
                end
            endcase
        end
    end

endmodule
