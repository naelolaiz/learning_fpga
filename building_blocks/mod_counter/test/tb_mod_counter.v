// mod_counter smoke test (Verilog mirror of tb_mod_counter.vhd).
//
// MAX_NUMBER = 4. Walk forward through one full cycle (carry on
// MAX→0 wrap), then backward through a second.

`timescale 1ns/1ps

module tb_mod_counter;
    localparam integer CLK_PERIOD_NS = 20;
    localparam integer MAX = 4;

    reg         clk = 1'b0;
    reg         rst = 1'b0;
    reg         direction = 1'b1;
    wire [3:0]  currentNumber;
    wire        carryBit;

    integer expected = 0;   // initialised so waveview doesn't paint
                            // an X-band from t=0 until the first
                            // for-loop assignment

    mod_counter #(.MAX_NUMBER(MAX)) DUT (
        .clock         (clk),
        .reset         (rst),
        .direction     (direction),
        .currentNumber (currentNumber),
        .carryBit      (carryBit)
    );

    always #(CLK_PERIOD_NS/2) clk = ~clk;

    initial begin
        $dumpfile(`FST_OUT);
        $dumpvars(1, tb_mod_counter);
        $dumpvars(1, DUT);

        rst = 1'b1; #(2 * CLK_PERIOD_NS); rst = 1'b0;

        // Forward walk: 1, 2, 3, 4, then wrap to 0 with carry.
        direction = 1'b1;
        for (expected = 1; expected <= MAX; expected = expected + 1) begin
            @(posedge clk);
            #1;
            if (currentNumber !== expected[3:0]) begin
                $display("FAIL forward: expected %0d, got %0d",
                         expected, currentNumber);
                $fatal;
            end
            if (carryBit !== 1'b0) begin
                $display("FAIL forward: unexpected mid-cycle carry at %0d",
                         expected);
                $fatal;
            end
        end
        @(posedge clk); #1;
        if (currentNumber !== 4'd0) begin
            $display("FAIL forward wrap: expected 0, got %0d", currentNumber);
            $fatal;
        end
        if (carryBit !== 1'b1) begin
            $display("FAIL forward wrap: carryBit was not asserted");
            $fatal;
        end

        // Backward walk.
        @(negedge clk); #1; direction = 1'b0;
        for (expected = MAX; expected >= 1; expected = expected - 1) begin
            @(posedge clk);
            #1;
            if (currentNumber !== expected[3:0]) begin
                $display("FAIL backward: expected %0d, got %0d",
                         expected, currentNumber);
                $fatal;
            end
        end
        @(posedge clk); #1;
        if (currentNumber !== 4'd0) begin
            $display("FAIL backward wrap: expected 0, got %0d", currentNumber);
            $fatal;
        end

        $finish;
    end

endmodule
