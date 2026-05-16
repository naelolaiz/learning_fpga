// uart_rx.v - Verilog mirror of uart_rx.vhd.
//
// 8N1 receiver, complementary to comm/uart_tx. See the VHDL header
// for the full design notes — two-stage synchroniser on the
// async rx line, three-tap majority sampler at each bit centre,
// rx_valid pulses one clock when a clean byte is captured.

module uart_rx #(
    parameter integer CLKS_PER_BIT = 5208
) (
    input  wire       clk,
    input  wire       rx,
    output wire [7:0] rx_data,
    output wire       rx_valid
);

    localparam [1:0] S_IDLE  = 2'b00;
    localparam [1:0] S_START = 2'b01;
    localparam [1:0] S_DATA  = 2'b10;
    localparam [1:0] S_STOP  = 2'b11;

    // Async-to-sync. Initialised idle-high so the FSM doesn't see a
    // spurious start-bit edge in the first cycles after reset.
    reg rx_sync1 = 1'b1;
    reg rx_sync2 = 1'b1;

    // Three-deep rolling sample window (newest at bit 0).
    reg [2:0] samples = 3'b111;

    reg [1:0] state    = S_IDLE;
    reg [$clog2(CLKS_PER_BIT)-1:0] tick = 0;
    reg [2:0] bit_idx  = 3'b000;
    reg [7:0] data_reg = 8'h00;
    reg       valid_r  = 1'b0;

    // Majority of 3 — two-of-three decoder.
    function automatic maj3(input [2:0] v);
        maj3 = (v[0] & v[1]) | (v[0] & v[2]) | (v[1] & v[2]);
    endfunction

    always @(posedge clk) begin
        // Always: synchroniser and sample window.
        rx_sync1 <= rx;
        rx_sync2 <= rx_sync1;
        samples  <= {samples[1:0], rx_sync2};

        valid_r <= 1'b0;

        case (state)
            S_IDLE: begin
                tick    <= 0;
                bit_idx <= 3'b000;
                if (rx_sync2 == 1'b0) begin
                    state <= S_START;
                end
            end

            S_START: begin
                if (tick == (CLKS_PER_BIT/2) - 1) begin
                    tick <= 0;
                    if (maj3(samples) == 1'b0) begin
                        state <= S_DATA;
                    end else begin
                        state <= S_IDLE;
                    end
                end else begin
                    tick <= tick + 1;
                end
            end

            S_DATA: begin
                if (tick == CLKS_PER_BIT - 1) begin
                    tick               <= 0;
                    data_reg[bit_idx]  <= maj3(samples);
                    if (bit_idx == 3'd7) begin
                        state <= S_STOP;
                    end else begin
                        bit_idx <= bit_idx + 1;
                    end
                end else begin
                    tick <= tick + 1;
                end
            end

            S_STOP: begin
                if (tick == CLKS_PER_BIT - 1) begin
                    tick <= 0;
                    if (maj3(samples) == 1'b1) begin
                        valid_r <= 1'b1;
                    end
                    state <= S_IDLE;
                end else begin
                    tick <= tick + 1;
                end
            end

            default: state <= S_IDLE;
        endcase
    end

    assign rx_data  = data_reg;
    assign rx_valid = valid_r;

endmodule
