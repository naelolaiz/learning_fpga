// tb_ram_sync.v - Verilog mirror of tb_ram_sync.vhd.
//
// 4-bit wide, 16-deep instance for waveform readability. Writes
// addr -> (15 - addr) at every location, reads them back, then
// checks the same-cycle write+read read-before-write semantics.

`timescale 1ns/1ps

module tb_ram_sync;

    localparam integer WIDTH      = 4;
    localparam integer DEPTH      = 16;
    localparam integer ADDR_W     = 4;
    localparam time    CLK_PERIOD = 20;

    reg                  sClk    = 1'b0;
    reg                  sWe     = 1'b0;
    reg  [ADDR_W-1:0]    sAddr   = {ADDR_W{1'b0}};
    reg  [WIDTH-1:0]     sWdata  = {WIDTH{1'b0}};
    wire [WIDTH-1:0]     sRdata;
    reg                  sSimulationActive = 1'b1;

    ram_sync #(.WIDTH(WIDTH), .ADDR_W(ADDR_W)) dut (
        .clk   (sClk),
        .we    (sWe),
        .addr  (sAddr),
        .wdata (sWdata),
        .rdata (sRdata)
    );

    always #(CLK_PERIOD/2) if (sSimulationActive) sClk = ~sClk;

    initial begin
        $dumpfile(`FST_OUT);
        $dumpvars(1, tb_ram_sync);
        $dumpvars(1, dut);
    end

    // `integer i = 0` (Verilog 2001 inline init) so the FST trace of
    // `i` has a defined value before the loop starts — a plain
    // `integer i;` shows the variable as 'X' / red band before the
    // first assignment, even though functionally it's loop-scoped.
    integer i = 0;
    initial begin : driver
        @(negedge sClk);

        // Write phase: addr i -> 15 - i.
        for (i = 0; i < DEPTH; i = i + 1) begin
            sWe    = 1'b1;
            sAddr  = i[ADDR_W-1:0];
            sWdata = (DEPTH-1-i) & {WIDTH{1'b1}};
            @(negedge sClk);
        end
        sWe = 1'b0;

        // Read phase: check each address.
        for (i = 0; i < DEPTH; i = i + 1) begin
            sAddr = i[ADDR_W-1:0];
            @(negedge sClk);
            if (sRdata !== ((DEPTH-1-i) & {WIDTH{1'b1}}))
                $fatal(1, "Read mismatch at addr %0d: got %h, expected %h",
                       i, sRdata, (DEPTH-1-i) & {WIDTH{1'b1}});
        end

        // Read-before-write check at addr 5: old value must be 10.
        sAddr  = 5;
        sWe    = 1'b1;
        sWdata = 4'h3;
        @(negedge sClk);
        sWe = 1'b0;
        if (sRdata !== 4'd10)
            $fatal(1, "Read-before-write: expected old value 10, got %0d", sRdata);

        // Now confirm the new value is visible.
        sAddr = 5;
        @(negedge sClk);
        if (sRdata !== 4'h3)
            $fatal(1, "After write, addr 5 should read 3, got %h", sRdata);

        $display("ram_sync simulation done!");
        sSimulationActive = 1'b0;
        $finish;
    end

endmodule
