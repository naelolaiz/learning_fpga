// One clock drives every register. tick is a clock enable, never a clock.
// enable_async must be a slowly changing single bit, such as a button.
module clock_enable #(
    parameter integer DIVISOR = 4,
    parameter integer COUNT_WIDTH = 4
) (
    input  wire clk,
    input  wire rst,
    input  wire enable_async,
    output wire enable_sync,
    output reg  tick = 1'b0,
    output reg [COUNT_WIDTH-1:0] count = 0
);
    localparam integer DIV_WIDTH = DIVISOR <= 1 ? 1 : $clog2(DIVISOR);
    reg [DIV_WIDTH-1:0] divider = 0;
    // Quartus recognizes the chain as a synchronizer. Other tools can ignore
    // these vendor attributes; the two clocked stages still exist in RTL.
    (* altera_attribute = "-name SYNCHRONIZER_IDENTIFICATION FORCED_IF_ASYNCHRONOUS" *)
    reg sync1 = 1'b0, sync2 = 1'b0;
    assign enable_sync = sync2;

`ifndef SYNTHESIS
    initial begin
        if (DIVISOR < 1 || COUNT_WIDTH < 1)
            $fatal(1, "DIVISOR and COUNT_WIDTH must be positive");
    end
`endif

    always @(posedge clk) begin
        if (rst) begin
            sync1 <= 1'b0;
            sync2 <= 1'b0;
            divider <= 0;
            tick <= 1'b0;
            count <= 0;
        end else begin
            sync1 <= enable_async;
            sync2 <= sync1;
            tick <= 1'b0;
            if (divider == DIVISOR - 1) begin
                divider <= 0;
                tick <= 1'b1;
                if (sync2) count <= count + 1'b1;
            end else begin
                divider <= divider + 1'b1;
            end
        end
    end
endmodule
