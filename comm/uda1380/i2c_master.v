// i2c_master.v
//
// Bit-banged generic I2C master with start/stop framing and slave
// ACK detection. Open-drain outputs: '0' actively driven low,
// otherwise high-impedance ('Z') so an external pull-up resolves
// the bus high. Continuous-mode operation (ena held high across
// bytes) skips the stop bit between transfers.

module i2c_master #(
    parameter integer input_clk = 50_000_000,
    parameter integer bus_clk   = 400_000
) (
    input  wire        clk,
    input  wire        reset_n,                       // active-low
    input  wire        ena,
    input  wire [6:0]  addr,
    input  wire        rw,
    input  wire [7:0]  data_wr,
    output reg         busy,
    output reg  [7:0]  data_rd,
    output reg         ack_error,
    inout  wire        sda,
    inout  wire        scl
);

    localparam integer DIVIDER = (input_clk / bus_clk) / 4;

    localparam [3:0] S_READY    = 4'd0;
    localparam [3:0] S_START    = 4'd1;
    localparam [3:0] S_COMMAND  = 4'd2;
    localparam [3:0] S_SLV_ACK1 = 4'd3;
    localparam [3:0] S_WR       = 4'd4;
    localparam [3:0] S_RD       = 4'd5;
    localparam [3:0] S_SLV_ACK2 = 4'd6;
    localparam [3:0] S_MSTR_ACK = 4'd7;
    localparam [3:0] S_STOP     = 4'd8;

    reg [3:0]  state         = S_READY;
    reg        data_clk      = 1'b0;
    reg        data_clk_prev = 1'b0;
    reg        scl_clk       = 1'b0;
    reg        scl_ena       = 1'b0;
    reg        sda_int       = 1'b1;
    reg        sda_ena_n     = 1'b1;
    reg [7:0]  addr_rw       = 8'd0;
    reg [7:0]  data_tx       = 8'd0;
    reg [7:0]  data_rx       = 8'd0;
    reg [3:0]  bit_cnt       = 4'd7;
    reg        stretch       = 1'b0;
    reg [31:0] count         = 32'd0;

    // Bus-clock and data-clock generator.
    always @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            stretch <= 1'b0;
            count   <= 32'd0;
        end else begin
            data_clk_prev <= data_clk;
            if (count == DIVIDER*4 - 1) count <= 32'd0;
            else if (!stretch)          count <= count + 32'd1;

            if (count < DIVIDER) begin
                scl_clk  <= 1'b0;
                data_clk <= 1'b0;
            end else if (count < DIVIDER*2) begin
                scl_clk  <= 1'b0;
                data_clk <= 1'b1;
            end else if (count < DIVIDER*3) begin
                scl_clk  <= 1'b1;
                stretch  <= (scl == 1'b0);
                data_clk <= 1'b1;
            end else begin
                scl_clk  <= 1'b1;
                data_clk <= 1'b0;
            end
        end
    end

    // State machine.
    always @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            state     <= S_READY;
            busy      <= 1'b1;
            scl_ena   <= 1'b0;
            sda_int   <= 1'b1;
            ack_error <= 1'b0;
            bit_cnt   <= 4'd7;
            data_rd   <= 8'h00;
        end else begin
            // data_clk rising edge: SDA setup at SCL low.
            if (data_clk == 1'b1 && data_clk_prev == 1'b0) begin
                case (state)
                    S_READY: begin
                        if (ena) begin
                            busy    <= 1'b1;
                            addr_rw <= {addr, rw};
                            data_tx <= data_wr;
                            state   <= S_START;
                        end else begin
                            busy  <= 1'b0;
                            state <= S_READY;
                        end
                    end
                    S_START: begin
                        busy    <= 1'b1;
                        sda_int <= addr_rw[bit_cnt];
                        state   <= S_COMMAND;
                    end
                    S_COMMAND: begin
                        if (bit_cnt == 4'd0) begin
                            sda_int <= 1'b1;
                            bit_cnt <= 4'd7;
                            state   <= S_SLV_ACK1;
                        end else begin
                            bit_cnt <= bit_cnt - 4'd1;
                            sda_int <= addr_rw[bit_cnt-1];
                        end
                    end
                    S_SLV_ACK1: begin
                        if (addr_rw[0] == 1'b0) begin
                            sda_int <= data_tx[bit_cnt];
                            state   <= S_WR;
                        end else begin
                            sda_int <= 1'b1;
                            state   <= S_RD;
                        end
                    end
                    S_WR: begin
                        busy <= 1'b1;
                        if (bit_cnt == 4'd0) begin
                            sda_int <= 1'b1;
                            bit_cnt <= 4'd7;
                            state   <= S_SLV_ACK2;
                        end else begin
                            bit_cnt <= bit_cnt - 4'd1;
                            sda_int <= data_tx[bit_cnt-1];
                        end
                    end
                    S_RD: begin
                        busy <= 1'b1;
                        if (bit_cnt == 4'd0) begin
                            if (ena && addr_rw == {addr, rw}) sda_int <= 1'b0;
                            else                              sda_int <= 1'b1;
                            bit_cnt <= 4'd7;
                            data_rd <= data_rx;
                            state   <= S_MSTR_ACK;
                        end else begin
                            bit_cnt <= bit_cnt - 4'd1;
                        end
                    end
                    S_SLV_ACK2: begin
                        if (ena) begin
                            busy    <= 1'b0;
                            addr_rw <= {addr, rw};
                            data_tx <= data_wr;
                            if (addr_rw == {addr, rw}) begin
                                sda_int <= data_wr[bit_cnt];
                                state   <= S_WR;
                            end else begin
                                state <= S_START;
                            end
                        end else begin
                            state <= S_STOP;
                        end
                    end
                    S_MSTR_ACK: begin
                        if (ena) begin
                            busy    <= 1'b0;
                            addr_rw <= {addr, rw};
                            data_tx <= data_wr;
                            if (addr_rw == {addr, rw}) begin
                                sda_int <= 1'b1;
                                state   <= S_RD;
                            end else begin
                                state <= S_START;
                            end
                        end else begin
                            state <= S_STOP;
                        end
                    end
                    S_STOP: begin
                        busy  <= 1'b0;
                        state <= S_READY;
                    end
                endcase
            end else if (data_clk == 1'b0 && data_clk_prev == 1'b1) begin
                // data_clk falling edge: SDA sampled at SCL high.
                case (state)
                    S_START: begin
                        if (!scl_ena) begin
                            scl_ena   <= 1'b1;
                            ack_error <= 1'b0;
                        end
                    end
                    S_SLV_ACK1: begin
                        if (sda != 1'b0 || ack_error == 1'b1)
                            ack_error <= 1'b1;
                    end
                    S_RD: begin
                        data_rx[bit_cnt] <= sda;
                    end
                    S_SLV_ACK2: begin
                        if (sda != 1'b0 || ack_error == 1'b1)
                            ack_error <= 1'b1;
                    end
                    S_STOP: begin
                        scl_ena <= 1'b0;
                    end
                endcase
            end
        end
    end

    // SDA output enable: combinational with state.
    always @(*) begin
        case (state)
            S_START: sda_ena_n = data_clk_prev;       // generate start
            S_STOP : sda_ena_n = ~data_clk_prev;      // generate stop
            default: sda_ena_n = sda_int;
        endcase
    end

    // Open-drain bus drivers.
    assign scl = (scl_ena && !scl_clk) ? 1'b0 : 1'bz;
    assign sda = (!sda_ena_n)          ? 1'b0 : 1'bz;

endmodule
