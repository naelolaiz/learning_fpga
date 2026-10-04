// uda1380_init_fsm.v - Verilog mirror of uda1380_init_fsm.vhd.
//
// The boot sequence is encoded as a flat ROM of {reg, hi, lo} bytes
// instead of using the VHDL record types from
// uda1380_control_definitions.vhd (Verilog has no equivalent for
// VHDL records-with-named-fields, so the table is inlined here as
// hex literals — the integration testbenches check both languages
// against the same expected byte stream).
//
// Same handshake as the VHDL: one command per byte towards
// comm/i2c_master, cmd_start on the address byte, cmd_stop on the
// last data byte, stepping on every clock where the master is ready.

module uda1380_init_fsm #(
    parameter integer INIT_DELAY_CYCLES = 5_000_000   // 100 ms @ 50 MHz
) (
    input  wire        clk,
    input  wire        reset,                          // active-high
    // To i2c_master (write-only, so cmd_read / cmd_nack stay 0).
    output wire        cmd_valid,
    output wire        cmd_start,
    output wire        cmd_stop,
    output reg  [7:0]  cmd_wdata,
    // From i2c_master
    input  wire        cmd_ready,
    input  wire        i2c_busy,
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
    localparam [1:0] ST_WAIT_BUS_FREE = 2'd2;
    localparam [1:0] ST_DONE          = 2'd3;
    reg [1:0] state = ST_POWER_UP_WAIT;

    reg [3:0]  table_idx     = 4'd0;
    // Which byte of the current transaction is on offer:
    // 0 = device address, 1 = register, 2 = data high, 3 = data low.
    reg [1:0]  byte_idx      = 2'd0;
    reg [31:0] delay_counter = 32'd0;

    // The command is a pure function of where we are in the table, so
    // the byte on offer always matches the index that advances when
    // it is accepted.
    assign cmd_valid = (state == ST_SEND_REGISTER);
    assign cmd_start = (byte_idx == 2'd0);
    assign cmd_stop  = (byte_idx == 2'd3);

    always @(*) begin
        case (byte_idx)
            2'd0:    cmd_wdata = {DEVICE_ADDR, 1'b0};                   // address, write
            2'd1:    cmd_wdata = {1'b0, init_table[table_idx][22:16]};  // 7 bits, padded to 8
            2'd2:    cmd_wdata = init_table[table_idx][15:8];
            default: cmd_wdata = init_table[table_idx][7:0];
        endcase
    end

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            state         <= ST_POWER_UP_WAIT;
            table_idx     <= 4'd0;
            byte_idx      <= 2'd0;
            delay_counter <= 32'd0;
            init_done     <= 1'b0;
        end else begin
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
                    // cmd_valid is high throughout this state, so a
                    // ready master means the byte on offer was
                    // accepted on this edge.
                    if (cmd_ready) begin
                        if (byte_idx == 2'd3) begin
                            byte_idx <= 2'd0;
                            if (table_idx == N_INIT - 1)
                                state <= ST_WAIT_BUS_FREE;
                            else
                                table_idx <= table_idx + 4'd1;
                        end else begin
                            byte_idx <= byte_idx + 2'd1;
                        end
                    end
                end

                ST_WAIT_BUS_FREE: begin
                    // The last byte and its STOP are still on the wire.
                    if (!i2c_busy)
                        state <= ST_DONE;
                end

                ST_DONE: init_done <= 1'b1;
            endcase
        end
    end

endmodule
