// 16-bit Galois LFSR with byte-strobe output.
//
// Stand-in for neoTRNG in the Verilog flow. The VHDL flow uses
// neoTRNG's chaotic ring oscillators on hardware (and neoTRNG's own
// LFSR in simulation). The Verilog flow uses an LFSR for both, which
// is simpler and gives equivalent visual behaviour on the display
// (random-looking hex digits rolling at the gate-divider rate).
//
// Polynomial: x^16 + x^14 + x^13 + x^11 + 1 (taps 0xB400, full
// 65535-state period from any non-zero seed).
//
// While `enable` is high the LFSR steps every clock edge and emits
// `valid` + an 8-bit `data` snapshot every 8 steps. While `enable`
// is low the LFSR pauses and the byte counter resets, so each
// gate-open phase starts fresh.

module lfsr (
    input  wire        clk,
    input  wire        enable,
    output reg  [7:0]  data,
    output reg         valid
);

    reg [15:0] state    = 16'h0001;   // any non-zero seed
    reg [2:0]  bitCount = 3'd0;

    always @(posedge clk) begin
        valid <= 1'b0;
        if (enable) begin
            // Galois step: shift right; XOR taps in if the bit shifted out is 1.
            if (state[0])
                state <= (state >> 1) ^ 16'hB400;
            else
                state <= (state >> 1);

            // Emit a byte every 8 steps.
            if (bitCount == 3'd7) begin
                bitCount <= 3'd0;
                data     <= state[7:0];
                valid    <= 1'b1;
            end else begin
                bitCount <= bitCount + 3'd1;
            end
        end else begin
            bitCount <= 3'd0;
        end
    end

endmodule
