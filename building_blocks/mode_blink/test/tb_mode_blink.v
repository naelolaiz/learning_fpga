// mode_blink smoke test (Verilog mirror of tb_mode_blink.vhd).
//
// Two DUTs share the same square-wave input — one in passthrough
// mode, one in half-rate mode. After 10 input periods we expect
// 20 transitions on the passthrough output (it tracks signalIn)
// and 10 transitions on the half-rate output.

`timescale 1ns/1ps

module tb_mode_blink;
    localparam integer IN_PERIOD_NS = 40;

    reg  signalIn = 1'b0;
    wire out_pass, out_half;

    integer pass_edges = 0;
    integer half_edges = 0;

    mode_blink DUT_PASS (.signalIn(signalIn), .toggleMode(1'b0), .signalOut(out_pass));
    mode_blink DUT_HALF (.signalIn(signalIn), .toggleMode(1'b1), .signalOut(out_half));

    always #(IN_PERIOD_NS/2) signalIn = ~signalIn;

    always @(out_pass) pass_edges = pass_edges + 1;
    always @(out_half) half_edges = half_edges + 1;

    initial begin
        $dumpfile(`FST_OUT);
        $dumpvars(1, tb_mode_blink);
        $dumpvars(1, DUT_PASS);
        $dumpvars(1, DUT_HALF);

        // Initial X→0 transitions on the two outputs at t=0 would
        // count as edges; skip them by starting the count after the
        // outputs settle.
        #1;
        pass_edges = 0;
        half_edges = 0;

        #(10 * IN_PERIOD_NS);

        if (pass_edges !== 20) begin
            $display("FAIL passthrough: expected 20 edges, got %0d", pass_edges);
            $fatal;
        end
        if (half_edges !== 10) begin
            $display("FAIL half-rate: expected 10 edges, got %0d", half_edges);
            $fatal;
        end

        $finish;
    end

endmodule
