// uda1380_init_fsm.v - Verilog mirror of uda1380_init_fsm.vhd.
//
// The boot sequence is encoded as a flat ROM of {reg, hi, lo} bytes
// instead of using the VHDL record types from
// uda1380_control_definitions.vhd (Verilog has no equivalent for
// VHDL records-with-named-fields, so the table is inlined here as
// hex literals — bit-for-bit identical to what the VHDL FSM walks).
//
// Same handshake protocol: assert ena with the first byte; on each
// busy 0->1 edge advance to the next byte; after the third byte
// drop ena and wait for busy to fall before moving to the next
// register write.

module uda1380_init_fsm #(
    parameter integer INIT_DELAY_CYCLES = 5_000_000   // 100 ms @ 50 MHz
) (
    input  wire        clk,
    input  wire        reset,                          // active-high
    output reg         i2c_ena,
    output reg  [6:0]  i2c_addr,
    output reg         i2c_rw,
    output reg  [7:0]  i2c_data_wr,
    input  wire        i2c_busy,
    input  wire        i2c_ack_err,
    output reg         init_done
);

    localparam [6:0] DEVICE_ADDR = 7'b0011000;        // = 7'h18

    // 15 entries, three bytes each: {reg_address, hi, lo}. Encoded
    // as a 24-bit word per entry to keep the table easy to scan.
    localparam integer N_INIT = 15;
    reg [23:0] init_table [0:N_INIT-1];
    initial begin
        init_table[ 0] = 24'h7F_00_00;  // L3 reset
        init_table[ 1] = 24'h02_A5_DF;  // power: enable all
        init_table[ 2] = 24'h00_0F_39;  // evalclk: WSPLL, all clocks on
        init_table[ 3] = 24'h01_00_00;  // I2S: bus, digital mixer, BCK0 slave
        init_table[ 4] = 24'h03_00_00;  // analog mixer input gain
        init_table[ 5] = 24'h04_02_02;  // headamp: short-circuit protection on
        init_table[ 6] = 24'h10_00_00;  // master volume: full
        init_table[ 7] = 24'h11_00_00;  // mixer volume: full both channels
        init_table[ 8] = 24'h12_55_15;  // mode/treble/bass: flat
        init_table[ 9] = 24'h13_00_00;  // mute/de-emph: disable
        init_table[10] = 24'h14_00_00;  // mixer SDO: off
        init_table[11] = 24'h20_00_00;  // ADC decimator volume: max
        init_table[12] = 24'h21_00_00;  // PGA: no mute, full gain
        init_table[13] = 24'h22_0F_02;  // ADC: select line-in + mic, max gain
        init_table[14] = 24'h23_00_00;  // AGC: settings
    end

    localparam [1:0] ST_POWER_UP_WAIT = 2'd0;
    localparam [1:0] ST_SEND_REGISTER = 2'd1;
    localparam [1:0] ST_DONE          = 2'd2;
    reg [1:0] state = ST_POWER_UP_WAIT;

    reg [3:0]  table_idx     = 4'd0;
    reg [1:0]  busy_cnt      = 2'd0;
    reg        busy_prev     = 1'b0;
    reg [31:0] delay_counter = 32'd0;

    // Selectors over the current table entry's three bytes.
    wire [7:0] byte_reg = {1'b0, init_table[table_idx][23:17]};
    wire [7:0] byte_hi  = init_table[table_idx][15:8];
    wire [7:0] byte_lo  = init_table[table_idx][7:0];

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            state         <= ST_POWER_UP_WAIT;
            table_idx     <= 4'd0;
            busy_cnt      <= 2'd0;
            busy_prev     <= 1'b0;
            delay_counter <= 32'd0;
            i2c_ena       <= 1'b0;
            i2c_addr      <= 7'd0;
            i2c_rw        <= 1'b0;
            i2c_data_wr   <= 8'd0;
            init_done     <= 1'b0;
        end else begin
            busy_prev <= i2c_busy;

            case (state)
                ST_POWER_UP_WAIT: begin
                    if (delay_counter == INIT_DELAY_CYCLES - 1) begin
                        delay_counter <= 32'd0;
                        state         <= ST_SEND_REGISTER;
                    end else begin
                        delay_counter <= delay_counter + 32'd1;
                    end
                end

                ST_SEND_REGISTER: begin
                    if (!busy_prev && i2c_busy)
                        busy_cnt <= busy_cnt + 2'd1;

                    case (busy_cnt)
                        2'd0: begin
                            i2c_ena     <= 1'b1;
                            i2c_addr    <= DEVICE_ADDR;
                            i2c_rw      <= 1'b0;
                            i2c_data_wr <= byte_reg;
                        end
                        2'd1: i2c_data_wr <= byte_hi;
                        2'd2: i2c_data_wr <= byte_lo;
                        2'd3: begin
                            i2c_ena <= 1'b0;
                            if (!i2c_busy) begin
                                busy_cnt <= 2'd0;
                                if (table_idx == N_INIT - 1)
                                    state <= ST_DONE;
                                else
                                    table_idx <= table_idx + 4'd1;
                            end
                        end
                    endcase
                end

                ST_DONE: begin
                    i2c_ena   <= 1'b0;
                    init_done <= 1'b1;
                end
            endcase
        end
    end

endmodule
