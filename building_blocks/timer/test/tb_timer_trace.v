`timescale 1ns/1ps

// Reads exactly the same stimulus rows as tb_timer_trace.vhd.
module tb_timer_trace #(
    parameter integer MAX_NUMBER = 8,
    parameter integer TRIGGER_DURATION = 3
);
    reg clock = 0;
    reg reset = 0;
    reg [31:0] limit = MAX_NUMBER;
    wire tick;
    reg previous_tick = 0;
    integer input_file, output_file, fields, reset_value, limit_value;

    Timer #(.MAX_NUMBER(MAX_NUMBER), .TRIGGER_DURATION(TRIGGER_DURATION)) DUT (
        .clock(clock), .reset(reset), .maxLimit(limit), .timerTriggered(tick)
    );

    initial begin
        input_file = $fopen("stimulus.txt", "r");
        output_file = $fopen("trace.txt", "w");
        if (!input_file || !output_file) $fatal(1, "Cannot open trace files");
        while (!$feof(input_file)) begin
            fields = $fscanf(input_file, "%d %d\n", reset_value, limit_value);
            if (fields == 2) begin
                reset = reset_value;
                limit = limit_value;
                #1;
                if (tick !== previous_tick)
                    $fatal(1, "Timer output changed between rising edges");
                #4 clock = 1;
                #1;
                if (tick !== 1'b0 && tick !== 1'b1)
                    $fatal(1, "Timer output is unknown");
                $fwrite(output_file, "%b\n", tick);
                previous_tick = tick;
                #4 clock = 0;
            end else if (fields != -1) begin
                $fatal(1, "Malformed stimulus row");
            end
        end
        $fclose(input_file);
        $fclose(output_file);
        $finish;
    end
endmodule
