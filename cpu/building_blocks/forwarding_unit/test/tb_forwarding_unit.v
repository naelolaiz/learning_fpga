// tb_forwarding_unit.v - Verilog mirror of tb_forwarding_unit.vhd.
//
// Same seven cases as the VHDL twin: no-hazard, MEM-to-A, WB-to-B,
// MEM-wins-over-WB, x0-never-forwards, we-low-blocks, MEM-A + WB-B
// independent.

`timescale 1ns/1ps
`default_nettype none

module tb_forwarding_unit;

    reg  [4:0] ex_rs1 = 5'd0, ex_rs2 = 5'd0;
    reg  [4:0] mem_rd = 5'd0, wb_rd  = 5'd0;
    reg        mem_we = 1'b0, wb_we  = 1'b0;
    wire [1:0] fwd_a, fwd_b;

    forwarding_unit dut (
        .ex_rs1(ex_rs1), .ex_rs2(ex_rs2),
        .mem_rd(mem_rd), .mem_we(mem_we),
        .wb_rd (wb_rd),  .wb_we (wb_we),
        .fwd_a (fwd_a),  .fwd_b (fwd_b)
    );

    initial begin
        $dumpfile(`FST_OUT);
        $dumpvars(0, tb_forwarding_unit);
    end

    integer errors = 0;

    task check;
        input [255:0] tag;
        input [1:0]   exp_a;
        input [1:0]   exp_b;
        begin
            if (fwd_a !== exp_a) begin
                $display("%0s: fwd_a expected %b got %b", tag, exp_a, fwd_a);
                errors = errors + 1;
            end
            if (fwd_b !== exp_b) begin
                $display("%0s: fwd_b expected %b got %b", tag, exp_b, fwd_b);
                errors = errors + 1;
            end
        end
    endtask

    initial begin
        // Case 1: no hazard.
        ex_rs1 = 5'd5;  ex_rs2 = 5'd6;
        mem_rd = 5'd10; mem_we = 1'b1;
        wb_rd  = 5'd11; wb_we  = 1'b1;
        #1; check("no-hazard", 2'b00, 2'b00);

        // Case 2: MEM forwards to A.
        ex_rs1 = 5'd7;  ex_rs2 = 5'd8;
        mem_rd = 5'd7;  mem_we = 1'b1;
        wb_rd  = 5'd31; wb_we  = 1'b1;
        #1; check("mem-to-a", 2'b10, 2'b00);

        // Case 3: WB forwards to B.
        ex_rs1 = 5'd12; ex_rs2 = 5'd13;
        mem_rd = 5'd30; mem_we = 1'b1;
        wb_rd  = 5'd13; wb_we  = 1'b1;
        #1; check("wb-to-b", 2'b00, 2'b01);

        // Case 4: both stages match — MEM wins.
        ex_rs1 = 5'd9;  ex_rs2 = 5'd0;
        mem_rd = 5'd9;  mem_we = 1'b1;
        wb_rd  = 5'd9;  wb_we  = 1'b1;
        #1; check("mem-wins-over-wb", 2'b10, 2'b00);

        // Case 5: x0 must never forward.
        ex_rs1 = 5'd0;  ex_rs2 = 5'd0;
        mem_rd = 5'd0;  mem_we = 1'b1;
        wb_rd  = 5'd0;  wb_we  = 1'b1;
        #1; check("x0-never-forwards", 2'b00, 2'b00);

        // Case 6: we=0 blocks forwarding.
        ex_rs1 = 5'd10; ex_rs2 = 5'd11;
        mem_rd = 5'd10; mem_we = 1'b0;
        wb_rd  = 5'd11; wb_we  = 1'b0;
        #1; check("we-low-blocks", 2'b00, 2'b00);

        // Case 7: MEM-to-A + WB-to-B independently.
        ex_rs1 = 5'd3;  ex_rs2 = 5'd4;
        mem_rd = 5'd3;  mem_we = 1'b1;
        wb_rd  = 5'd4;  wb_we  = 1'b1;
        #1; check("mem-a-wb-b", 2'b10, 2'b01);

        if (errors != 0) $fatal(1, "tb_forwarding_unit: %0d errors", errors);
        $display("tb_forwarding_unit: all cases passed");
        $finish;
    end

endmodule

`default_nettype wire
