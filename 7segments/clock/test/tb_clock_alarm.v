// tb_clock_alarm.v - Verilog mirror of tb_clock_alarm.vhd.
//
// Same four cause-effect properties as the VHDL TB:
//   (A) match + tone + gate     -> buzzer = '1'
//   (B) match + tone + !gate    -> buzzer = '0'
//   (C) mismatch (regardless)   -> buzzer = 'z'
//   (D) match-broken transition -> buzzer goes 'z' immediately

`timescale 1ns/1ps

module tb_clock_alarm;

    reg  [23:0] sMainBcd  = 24'd0;
    reg  [23:0] sAlarmBcd = 24'd0;
    reg         sTone     = 1'b0;
    reg         sGate     = 1'b0;
    wire        sBuzzer;

    AlarmTrigger dut (
        .mainBcd   (sMainBcd),
        .alarmBcd  (sAlarmBcd),
        .tone      (sTone),
        .gate      (sGate),
        .buzzerOut (sBuzzer)
    );

    initial begin
        $dumpfile(`VCD_OUT);
        $dumpvars(1, tb_clock_alarm);
        $dumpvars(1, dut);
    end

    initial begin : driver
        // (A) match + tone + gate -> '1'
        sMainBcd  = 24'd0;
        sAlarmBcd = 24'd0;
        sTone     = 1'b1;
        sGate     = 1'b1;
        #10;
        if (sBuzzer !== 1'b1) begin
            $display("(A) expected buzzer 1, got %b", sBuzzer);
            $fatal;
        end

        // (B) match + tone + !gate -> '0'
        sGate = 1'b0;
        #10;
        if (sBuzzer !== 1'b0) begin
            $display("(B) expected buzzer 0, got %b", sBuzzer);
            $fatal;
        end

        // match + !tone + gate -> '0' (no carrier)
        sTone = 1'b0;
        sGate = 1'b1;
        #10;
        if (sBuzzer !== 1'b0) begin
            $display("match+!tone+gate: expected buzzer 0, got %b", sBuzzer);
            $fatal;
        end

        // (C) mismatch + tone + gate -> 'z'. Toggle a non-seconds-units
        // bit so the upper-20 compare fails.
        sMainBcd[8] = 1'b1;        // minutes-units bit
        sTone = 1'b1;
        sGate = 1'b1;
        #10;
        if (sBuzzer !== 1'bz) begin
            $display("(C) expected buzzer z, got %b", sBuzzer);
            $fatal;
        end

        // Seconds-units differences must NOT break the match (compare
        // is on bits 23..4). Drop minutes back to match, vary the
        // bottom nibble, expect buzzer = 1 again.
        sMainBcd        = 24'd0;
        sMainBcd[3:0]   = 4'b0101;        // units = 5, alarm units = 0
        #10;
        if (sBuzzer !== 1'b1) begin
            $display("seconds-units delta: expected buzzer 1 (match holds), got %b",
                     sBuzzer);
            $fatal;
        end

        // (D) Break match again on a seconds-tens bit -> 'z'.
        sMainBcd[7] = 1'b1;
        #10;
        if (sBuzzer !== 1'bz) begin
            $display("(D) match broken: expected buzzer z, got %b", sBuzzer);
            $fatal;
        end

        $display("tb_clock_alarm PASSED.");
        $finish;
    end

endmodule
