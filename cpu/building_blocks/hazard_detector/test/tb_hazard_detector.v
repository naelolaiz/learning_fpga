// tb_hazard_detector.v - Verilog mirror of tb_hazard_detector.vhd.

`timescale 1ns/1ps
`default_nettype none

module tb_hazard_detector;

    reg  [4:0] id_rs1 = 5'd0, id_rs2 = 5'd0;
    reg  [4:0] ex_rd  = 5'd0;
    reg        ex_mem_read  = 1'b0;
    reg        branch_taken = 1'b0;
    wire       stall, flush;

    hazard_detector dut (
        .id_rs1(id_rs1), .id_rs2(id_rs2),
        .ex_rd(ex_rd), .ex_mem_read(ex_mem_read),
        .branch_taken(branch_taken),
        .stall(stall), .flush(flush)
    );

    initial begin
        $dumpfile(`FST_OUT);
        $dumpvars(0, tb_hazard_detector);
    end

    integer errors = 0;

    task check;
        input [255:0] tag;
        input         exp_s;
        input         exp_f;
        begin
            if (stall !== exp_s) begin
                $display("%0s: stall expected %b got %b", tag, exp_s, stall);
                errors = errors + 1;
            end
            if (flush !== exp_f) begin
                $display("%0s: flush expected %b got %b", tag, exp_f, flush);
                errors = errors + 1;
            end
        end
    endtask

    initial begin
        id_rs1 = 5'd5;  id_rs2 = 5'd6;
        ex_rd  = 5'd10; ex_mem_read = 1'b1; branch_taken = 1'b0;
        #1; check("no-hazard", 1'b0, 1'b0);

        id_rs1 = 5'd7;  id_rs2 = 5'd8;
        ex_rd  = 5'd7;  ex_mem_read = 1'b1; branch_taken = 1'b0;
        #1; check("load-use-rs1", 1'b1, 1'b0);

        id_rs1 = 5'd12; id_rs2 = 5'd13;
        ex_rd  = 5'd13; ex_mem_read = 1'b1; branch_taken = 1'b0;
        #1; check("load-use-rs2", 1'b1, 1'b0);

        id_rs1 = 5'd16; id_rs2 = 5'd17;
        ex_rd  = 5'd16; ex_mem_read = 1'b0; branch_taken = 1'b0;
        #1; check("alu-rd-match-noload", 1'b0, 1'b0);

        id_rs1 = 5'd0;  id_rs2 = 5'd0;
        ex_rd  = 5'd0;  ex_mem_read = 1'b1; branch_taken = 1'b0;
        #1; check("load-into-x0", 1'b0, 1'b0);

        id_rs1 = 5'd0;  id_rs2 = 5'd0;
        ex_rd  = 5'd0;  ex_mem_read = 1'b0; branch_taken = 1'b1;
        #1; check("branch-taken", 1'b0, 1'b1);

        id_rs1 = 5'd7;  id_rs2 = 5'd8;
        ex_rd  = 5'd7;  ex_mem_read = 1'b1; branch_taken = 1'b1;
        #1; check("load-use-and-branch", 1'b1, 1'b1);

        if (errors != 0) $fatal(1, "tb_hazard_detector: %0d errors", errors);
        $display("tb_hazard_detector: all cases passed");
        $finish;
    end

endmodule

`default_nettype wire
