// Verilog testbench mirror of tb_logic_styles.vhd. Same five phases:
//   1. Init observation at t=1 ns (before any clock edge).
//   2. Combinational sweep of (a, b).
//   3. Clock with rst='1' to load the reset value.
//   4. Release rst; all three registers should follow `a`.
//   5. Drive the intentional latch through transparent + hold cycles.

`timescale 1ns/1ps

module tb_logic_styles;

    reg sClock = 1'b0;
    reg sA = 1'b0;
    reg sB = 1'b0;
    reg sRst = 1'b0;
    reg sEn = 1'b0;

    wire comb_op_and;
    wire comb_proc_good_and;
    wire comb_proc_latch;
    wire seq_no_init;
    wire seq_decl_init;
    wire seq_sync_reset;
    wire latch_intentional;

    reg sSimulationActive = 1'b1;

    logic_styles dut (
        .a                   (sA),
        .b                   (sB),
        .clk                 (sClock),
        .rst                 (sRst),
        .en                  (sEn),
        .comb_op_and         (comb_op_and),
        .comb_proc_good_and  (comb_proc_good_and),
        .comb_proc_latch_and (comb_proc_latch),
        .seq_no_init_a       (seq_no_init),
        .seq_decl_init_a     (seq_decl_init),
        .seq_sync_reset_a    (seq_sync_reset),
        .latch_intentional_a (latch_intentional)
    );

    always #10 if (sSimulationActive) sClock = ~sClock;

    initial begin
        $dumpfile(`VCD_OUT);
        $dumpvars(1, tb_logic_styles);
        $dumpvars(1, dut);
    end

    integer ab;
    initial begin : driver
        // Warmup: iverilog does not fire `always @(*)` at strict t=0
        // the way ghdl's processes initialize at simulation start, so
        // we wiggle sB to give the combinational always blocks an
        // event to react to. The wiggle keeps sA=0 throughout so the
        // latch trap (`if (a) ...`) and the intentional latch
        // (`if (en) ...`) stay un-assigned and observably 1'bx at
        // Phase 1, preserving the init-pedagogy.
        sB = 1'b1; #1;
        sB = 1'b0; #1;

        // Phase 1 -- observation at t=2 ns (post-warmup).
        $display("t=2 ns init observation: seq_no_init=%b seq_decl_init=%b seq_sync_reset=%b latch_intentional=%b comb_proc_latch=%b",
                 seq_no_init, seq_decl_init, seq_sync_reset, latch_intentional, comb_proc_latch);

        if (seq_no_init !== 1'bx)
            $fatal(1, "seq_no_init must be 1'bx before the first clock edge");
        if (seq_decl_init !== 1'b1)
            $fatal(1, "seq_decl_init must be 1'b1 from t=0 (declaration init)");
        if (seq_sync_reset !== 1'bx)
            $fatal(1, "seq_sync_reset must be 1'bx before the first reset+clock");

        // The latch trap: never assigned because sA=0 at startup.
        if (comb_proc_latch !== 1'bx)
            $display("WARNING: expected comb_proc_latch to be 1'bx at startup, got %b", comb_proc_latch);

        // Continuous-assign output is defined as soon as inputs are.
        if (comb_op_and !== (sA & sB))
            $fatal(1, "comb_op_and mismatch at startup");

        // `comb_proc_good_and` comes out of an `always @(*)` block.
        // iverilog does not fire `always @(*)` at strict t=0 the same
        // way VHDL processes initialize at simulation start, so we
        // skip the startup-time check and verify it during the sweep
        // below, where the @(*) block is guaranteed to have run.

        // Phase 2 -- combinational sweep.
        for (ab = 0; ab < 4; ab = ab + 1) begin
            {sA, sB} = ab[1:0];
            #1;
            if (comb_op_and !== (sA & sB))
                $fatal(1, "comb_op_and mismatch (ab=%0d)", ab);
            if (comb_proc_good_and !== (sA & sB))
                $fatal(1, "comb_proc_good_and mismatch (ab=%0d)", ab);
        end

        // Phase 3 -- clock with rst='1'.
        sA = 1'b1;
        sRst = 1'b1;
        @(posedge sClock);
        #1;
        if (seq_sync_reset !== 1'b1)
            $fatal(1, "seq_sync_reset must be 1 after first edge with rst=1");
        if (seq_no_init !== 1'b1)
            $fatal(1, "seq_no_init must follow sA after first edge");
        if (seq_decl_init !== 1'b1)
            $fatal(1, "seq_decl_init must follow sA after first edge");

        // Phase 4 -- release rst.
        sRst = 1'b0;
        sA = 1'b0;
        @(posedge sClock);
        #1;
        if (seq_no_init    !== 1'b0) $fatal(1, "seq_no_init must follow sA");
        if (seq_decl_init  !== 1'b0) $fatal(1, "seq_decl_init must follow sA");
        if (seq_sync_reset !== 1'b0) $fatal(1, "seq_sync_reset must follow sA");

        // Phase 5 -- intentional latch.
        sEn = 1'b1;
        sA  = 1'b1;
        #5;
        if (latch_intentional !== 1'b1)
            $fatal(1, "intentional latch must be transparent when en=1");

        sEn = 1'b0;
        #5;
        sA = 1'b0;
        #5;
        if (latch_intentional !== 1'b1)
            $fatal(1, "intentional latch must HOLD 1 after en falls");

        sEn = 1'b1;
        #5;
        if (latch_intentional !== 1'b0)
            $fatal(1, "intentional latch must be transparent again when en=1");

        $display("Simulation done!");
        sSimulationActive = 1'b0;
        $finish;
    end

endmodule
