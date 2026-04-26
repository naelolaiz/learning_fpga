// uart_tx.v - Verilog mirror of uart_tx.vhd.
//
// Minimal 8N1 UART transmitter. Idle = high; start bit (low), 8 data
// bits LSB first, 1 stop bit (high). Asserting tx_start while !tx_busy
// latches tx_data and begins the frame.
//
// The `tx_reg` intermediate register mirrors the VHDL `signal tx_reg`
// — same shape in both languages so the two waveforms show the same
// internal signal set.

module uart_tx #(
    parameter integer CLKS_PER_BIT = 5208
) (
    input  wire       clk,
    input  wire       tx_start,
    input  wire [7:0] tx_data,
    output wire       tx,
    output wire       tx_busy
);

    localparam [1:0] S_IDLE  = 2'd0;
    localparam [1:0] S_START = 2'd1;
    localparam [1:0] S_DATA  = 2'd2;
    localparam [1:0] S_STOP  = 2'd3;

    reg [1:0]  state    = S_IDLE;
    reg [31:0] tick     = 32'd0;
    reg [2:0]  bit_idx  = 3'd0;
    reg [7:0]  shifter  = 8'd0;
    reg        tx_reg   = 1'b1;

    always @(posedge clk) begin
        case (state)
            S_IDLE: begin
                tx_reg <= 1'b1;
                tick   <= 32'd0;
                if (tx_start) begin
                    shifter <= tx_data;
                    state   <= S_START;
                end
            end

            S_START: begin
                tx_reg <= 1'b0;
                if (tick == CLKS_PER_BIT - 1) begin
                    tick    <= 32'd0;
                    bit_idx <= 3'd0;
                    state   <= S_DATA;
                end else begin
                    tick <= tick + 32'd1;
                end
            end

            S_DATA: begin
                tx_reg <= shifter[0];
                if (tick == CLKS_PER_BIT - 1) begin
                    tick    <= 32'd0;
                    shifter <= {1'b0, shifter[7:1]};
                    if (bit_idx == 3'd7)
                        state <= S_STOP;
                    else
                        bit_idx <= bit_idx + 3'd1;
                end else begin
                    tick <= tick + 32'd1;
                end
            end

            S_STOP: begin
                tx_reg <= 1'b1;
                if (tick == CLKS_PER_BIT - 1) begin
                    tick  <= 32'd0;
                    state <= S_IDLE;
                end else begin
                    tick <= tick + 32'd1;
                end
            end
        endcase
    end

    assign tx      = tx_reg;
    assign tx_busy = (state != S_IDLE);

endmodule
