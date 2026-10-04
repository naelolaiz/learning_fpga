// i2c_master.v - Verilog mirror of i2c_master.vhd.
//
// Single-master I2C byte engine. Each accepted command puts one byte
// slot on the bus: eight data bits MSB first, then the acknowledge
// bit. `cmd_start` sends a START (or a repeated START) before the
// slot and `cmd_stop` sends a STOP after it. The address is simply
// the first byte written after a START, as {address, R/W}.
//
// The pins are open-drain and split: `*_oe = 1` pulls the line low,
// `*_oe = 0` lets the pull-up raise it, `*_i` reads the line back.
//
// CLKS_PER_QUARTER is the number of `clk` cycles in a quarter of an
// SCL period: 50 MHz / (4 * 100 kHz) = 125. Within a bit:
//
//   0  SCL low,  SDA still holds the previous bit (hold time)
//   1  SCL low,  SDA carries this bit              (setup time)
//   2  SCL high, sampled at the end of the quarter (middle of high)
//   3  SCL high
//
// While this master has released SCL but the line still reads low,
// the quarter timer waits — that is clock stretching. See the VHDL
// file for the longer walkthrough; signal names match one to one.

module i2c_master #(
    parameter integer CLKS_PER_QUARTER = 125
) (
    input  wire       clk,
    input  wire       rst,          // synchronous, active high
    // Command: accepted on a rising edge with cmd_valid && cmd_ready.
    input  wire       cmd_valid,
    input  wire       cmd_start,    // (repeated) START before the byte
    input  wire       cmd_stop,     // STOP after the acknowledge bit
    input  wire       cmd_read,     // 0 write cmd_wdata, 1 read a byte
    input  wire       cmd_nack,     // read only: answer NACK (last byte)
    input  wire [7:0] cmd_wdata,
    output wire       cmd_ready,
    // Response: one-clock pulse when the byte slot has finished.
    output wire       rsp_valid,
    output wire [7:0] rsp_rdata,    // the eight bits as seen on SDA
    output wire       rsp_nack,     // acknowledge bit: 1 = not acknowledged
    output wire       busy,         // high from START until the STOP completes
    // Open-drain bus, split into drive-low enables and read-backs.
    output wire       scl_oe,
    input  wire       scl_i,
    output wire       sda_oe,
    input  wire       sda_i
);

    localparam [3:0] S_IDLE     = 4'd0;   // bus free
    localparam [3:0] S_START    = 4'd1;   // SDA low, SCL high
    localparam [3:0] S_BIT      = 4'd2;   // nine bits, four quarters each
    localparam [3:0] S_HOLD     = 4'd3;   // between bytes, SCL held low
    localparam [3:0] S_RSTART_A = 4'd4;   // SCL low,  SDA released
    localparam [3:0] S_RSTART_B = 4'd5;   // SCL high, SDA high
    localparam [3:0] S_STOP_A   = 4'd6;   // SCL low,  SDA unchanged
    localparam [3:0] S_STOP_B   = 4'd7;   // SCL low,  SDA low
    localparam [3:0] S_STOP_C   = 4'd8;   // SCL high, SDA low
    localparam [3:0] S_STOP_D   = 4'd9;   // SDA high: bus free time

    reg [3:0]  state    = S_IDLE;
    reg [31:0] tick_cnt = 32'd0;
    reg [1:0]  phase    = 2'd0;     // quarter index inside the state
    reg [3:0]  bit_cnt  = 4'd0;     // 0..7 data bits, 8 acknowledge bit
    reg [7:0]  shreg    = 8'd0;
    reg        ack_bit  = 1'b0;

    // Flags of the command being executed.
    reg        c_read   = 1'b0;
    reg        c_stop   = 1'b0;
    reg        c_nack   = 1'b0;

    reg        scl_oe_r = 1'b0;
    reg        sda_oe_r = 1'b0;

    // Two-stage synchronisers, initialised to the idle (high) level.
    reg        scl_s1 = 1'b1, scl_s2 = 1'b1;
    reg        sda_s1 = 1'b1, sda_s2 = 1'b1;

    reg        rsp_valid_r = 1'b0;
    reg [7:0]  rsp_rdata_r = 8'd0;
    reg        rsp_nack_r  = 1'b0;

    // SCL released by us but still low: somebody else is holding it.
    wire stretching   = !scl_oe_r && !scl_s2;
    wire quarter_done = (tick_cnt == CLKS_PER_QUARTER - 1) && !stretching;
    wire ready_i      = (state == S_IDLE) || (state == S_HOLD);

    always @(posedge clk) begin
        scl_s1 <= scl_i;
        scl_s2 <= scl_s1;
        sda_s1 <= sda_i;
        sda_s2 <= sda_s1;

        // rsp_valid is a one-clock pulse.
        rsp_valid_r <= 1'b0;

        // Quarter timer. It rests in the two states that wait for a
        // command and pauses while the clock is being stretched.
        if (ready_i || stretching || tick_cnt == CLKS_PER_QUARTER - 1)
            tick_cnt <= 32'd0;
        else
            tick_cnt <= tick_cnt + 32'd1;

        if (rst) begin
            state    <= S_IDLE;
            scl_oe_r <= 1'b0;
            sda_oe_r <= 1'b0;
            phase    <= 2'd0;
            bit_cnt  <= 4'd0;
        end else begin
            case (state)

                S_IDLE: begin
                    scl_oe_r <= 1'b0;
                    sda_oe_r <= 1'b0;
                    if (cmd_valid) begin
                        shreg    <= cmd_wdata;
                        c_read   <= cmd_read;
                        c_stop   <= cmd_stop;
                        c_nack   <= cmd_nack;
                        // From a free bus every transfer begins with a
                        // START: pull SDA low while SCL is still high.
                        sda_oe_r <= 1'b1;
                        phase    <= 2'd0;
                        state    <= S_START;
                    end
                end

                S_HOLD: begin
                    if (cmd_valid) begin
                        shreg  <= cmd_wdata;
                        c_read <= cmd_read;
                        c_stop <= cmd_stop;
                        c_nack <= cmd_nack;
                        phase  <= 2'd0;
                        if (cmd_start) begin
                            sda_oe_r <= 1'b0;       // let SDA rise while SCL is low
                            state    <= S_RSTART_A;
                        end else begin
                            bit_cnt <= 4'd0;
                            state   <= S_BIT;
                        end
                    end
                end

                // Repeated START, first half: SCL low with SDA released.
                S_RSTART_A: begin
                    if (quarter_done) begin
                        if (phase == 2'd1) begin
                            scl_oe_r <= 1'b0;
                            phase    <= 2'd0;
                            state    <= S_RSTART_B;
                        end else begin
                            phase <= phase + 2'd1;
                        end
                    end
                end

                // Repeated START, second half: both lines high.
                S_RSTART_B: begin
                    if (quarter_done) begin
                        if (phase == 2'd1) begin
                            sda_oe_r <= 1'b1;       // the START edge
                            phase    <= 2'd0;
                            state    <= S_START;
                        end else begin
                            phase <= phase + 2'd1;
                        end
                    end
                end

                // START hold: SDA low, SCL high for half a period.
                S_START: begin
                    if (quarter_done) begin
                        if (phase == 2'd1) begin
                            scl_oe_r <= 1'b1;
                            phase    <= 2'd0;
                            bit_cnt  <= 4'd0;
                            state    <= S_BIT;
                        end else begin
                            phase <= phase + 2'd1;
                        end
                    end
                end

                S_BIT: begin
                    if (quarter_done) begin
                        case (phase)
                            2'd0: begin
                                // Hold quarter over: put this bit on SDA.
                                if (bit_cnt == 4'd8)
                                    // Acknowledge slot. Writing: release
                                    // SDA and let the slave answer.
                                    // Reading: we answer.
                                    sda_oe_r <= c_read && !c_nack;
                                else
                                    // Data bit. Open drain: pull low for
                                    // a 0, release for a 1 and whenever
                                    // we are reading.
                                    sda_oe_r <= !c_read && !shreg[7];
                                phase <= 2'd1;
                            end
                            2'd1: begin
                                scl_oe_r <= 1'b0;   // SCL rises
                                phase    <= 2'd2;
                            end
                            2'd2: begin
                                // Middle of SCL high: sample. Shifting
                                // the sampled bit in serves both
                                // directions.
                                if (bit_cnt == 4'd8)
                                    ack_bit <= sda_s2;
                                else
                                    shreg <= {shreg[6:0], sda_s2};
                                phase <= 2'd3;
                            end
                            default: begin
                                scl_oe_r <= 1'b1;   // SCL falls
                                phase    <= 2'd0;
                                if (bit_cnt == 4'd8) begin
                                    rsp_valid_r <= 1'b1;
                                    rsp_rdata_r <= shreg;
                                    rsp_nack_r  <= ack_bit;
                                    state       <= c_stop ? S_STOP_A : S_HOLD;
                                end else begin
                                    bit_cnt <= bit_cnt + 4'd1;
                                end
                            end
                        endcase
                    end
                end

                // STOP. SDA must be low before SCL rises, and it may
                // only move while SCL is low, so: wait a quarter, pull
                // SDA low, release SCL, then release SDA — the STOP edge.
                S_STOP_A: begin
                    if (quarter_done) begin
                        sda_oe_r <= 1'b1;
                        state    <= S_STOP_B;
                    end
                end

                S_STOP_B: begin
                    if (quarter_done) begin
                        scl_oe_r <= 1'b0;
                        phase    <= 2'd0;
                        state    <= S_STOP_C;
                    end
                end

                S_STOP_C: begin
                    if (quarter_done) begin
                        if (phase == 2'd1) begin
                            sda_oe_r <= 1'b0;       // the STOP edge
                            phase    <= 2'd0;
                            state    <= S_STOP_D;
                        end else begin
                            phase <= phase + 2'd1;
                        end
                    end
                end

                // Bus free time before the next START may follow.
                S_STOP_D: begin
                    if (quarter_done) begin
                        if (phase == 2'd1) begin
                            phase <= 2'd0;
                            state <= S_IDLE;
                        end else begin
                            phase <= phase + 2'd1;
                        end
                    end
                end

                default: state <= S_IDLE;
            endcase
        end
    end

    assign cmd_ready = ready_i;
    assign rsp_valid = rsp_valid_r;
    assign rsp_rdata = rsp_rdata_r;
    assign rsp_nack  = rsp_nack_r;
    assign busy      = (state != S_IDLE);
    assign scl_oe    = scl_oe_r;
    assign sda_oe    = sda_oe_r;

endmodule
