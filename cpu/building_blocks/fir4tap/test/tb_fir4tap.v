// tb_fir4tap.v - Verilog mirror of tb_fir4tap.vhd.

`timescale 1ns/1ps
`default_nettype none

module tb_fir4tap;

    localparam time CLK_PERIOD = 10;

    reg               clk = 1'b0;
    reg               rst = 1'b1;
    reg               sim_active = 1'b1;
    reg signed [8:0]  coeff_0 = 9'sd0;
    reg signed [8:0]  coeff_1 = 9'sd0;
    reg signed [8:0]  coeff_2 = 9'sd0;
    reg signed [8:0]  coeff_3 = 9'sd0;
    reg signed [15:0] sample_in   = 16'sd0;
    reg               sample_valid = 1'b0;
    wire signed [15:0] result;
    wire              result_valid;

    fir4tap dut (
        .clk(clk), .rst(rst),
        .coeff_0(coeff_0), .coeff_1(coeff_1),
        .coeff_2(coeff_2), .coeff_3(coeff_3),
        .sample_in(sample_in), .sample_valid(sample_valid),
        .result(result), .result_valid(result_valid)
    );

    initial begin
        $dumpfile(`FST_OUT);
        $dumpvars(0, tb_fir4tap);
    end

    always #(CLK_PERIOD/2.0) if (sim_active) clk = ~clk;

    integer errors = 0;

    task stream_and_check;
        input [255:0]      tag;
        input signed [15:0] sample;
        input signed [15:0] expected;
        begin
            // #1 after each posedge so driver assignments land
            // *between* clock edges, not at the same delta cycle as
            // the DUT's read. Without this, blocking assignments race
            // the DUT's @(posedge clk) sample-of-inputs and the result
            // depends on simulator process order — see
            // [[feedback-verilog-negedge-race]] for the broader
            // pattern.
            @(posedge clk); #1;
            sample_in    = sample;
            sample_valid = 1'b1;
            @(posedge clk); #1;
            sample_valid = 1'b0;
            @(posedge clk); #1;
            if (!result_valid) begin
                $display("%0s: result_valid did not pulse", tag);
                errors = errors + 1;
            end
            if (result !== expected) begin
                $display("%0s: expected %0d got %0d", tag, expected, $signed(result));
                errors = errors + 1;
            end
        end
    endtask

    initial begin
        #(2 * CLK_PERIOD) rst = 1'b0;
        #(CLK_PERIOD);

        // Test 1: halving passthrough (coeff = 0.5)
        // 9-bit signed only reaches +255, so +1.0 (= 256) doesn't
        // fit; halving with coeff = 128 sidesteps the boundary and
        // still demos the passthrough behaviour with a known scale.
        coeff_0 = 9'sd128; coeff_1 = 9'sd0; coeff_2 = 9'sd0; coeff_3 = 9'sd0;
        stream_and_check("halve 100",   100,   50);
        stream_and_check("halve 200",   200,  100);
        stream_and_check("halve 50",     50,   25);
        stream_and_check("halve -10",   -10,   -5);
        stream_and_check("halve -1000", -1000, -500);

        // Test 2: box average — reset to clear sample history first.
        rst = 1'b1;
        #(2 * CLK_PERIOD);
        rst = 1'b0;
        #(CLK_PERIOD);

        coeff_0 = 9'sd64; coeff_1 = 9'sd64; coeff_2 = 9'sd64; coeff_3 = 9'sd64;
        stream_and_check("box 100 fill1", 100,  25);
        stream_and_check("box 100 fill2", 100,  50);
        stream_and_check("box 100 fill3", 100,  75);
        stream_and_check("box 100 full",  100, 100);
        stream_and_check("box step 200a", 200, 125);
        stream_and_check("box step 200b", 200, 150);

        if (errors != 0) $fatal(1, "tb_fir4tap: %0d errors", errors);
        $display("tb_fir4tap: all cases passed");
        sim_active = 1'b0;
        $finish;
    end

endmodule

`default_nettype wire
