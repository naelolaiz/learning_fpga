// ram_sync.v - Verilog mirror of ram_sync.vhd.
//
// Single-port synchronous RAM with optional hex-file initialisation.
// Read and write both happen on the rising clock edge: due to NBA
// scheduling, a same-cycle write+read returns the OLD value of
// mem[addr] (read-before-write), matching the VHDL behaviour and the
// BRAM mode Quartus and yosys infer for this pattern.
//
// Sizing: pass ADDR_W (address width in bits); DEPTH = 2**ADDR_W is
// derived internally. We avoid $clog2 in the port list to match the
// VHDL twin and stay portable across older synth flows.
//
// INIT_FILE is the path to a hex file accepted by $readmemh (one
// word per line, ASCII hex). Empty string means "start at all zeros".

module ram_sync #(
    parameter integer WIDTH     = 32,
    parameter integer ADDR_W    = 10,        // DEPTH = 1 << ADDR_W (1024 by default)
    parameter         INIT_FILE = ""
) (
    input  wire                  clk,
    input  wire                  we,
    input  wire [ADDR_W-1:0]     addr,
    input  wire [WIDTH-1:0]      wdata,
    output reg  [WIDTH-1:0]      rdata
);

    localparam integer DEPTH = (1 << ADDR_W);

    reg [WIDTH-1:0] mem [0:DEPTH-1];

    // Initialise. Skip $readmemh on empty filename so the simulator
    // doesn't trip an "open" error when no init file is given.
    integer i;
    initial begin
        for (i = 0; i < DEPTH; i = i + 1) mem[i] = {WIDTH{1'b0}};
        if (INIT_FILE != "") $readmemh(INIT_FILE, mem);
    end

    always @(posedge clk) begin
        if (we) mem[addr] <= wdata;
        rdata <= mem[addr];
    end

endmodule
