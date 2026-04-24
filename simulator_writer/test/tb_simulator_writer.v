// Verilog testbench mirror of tb_simulator_writer.vhd.
//
// Drives the writer with a 50 MHz clock until `done` pulses high
// (signals that the message has rendered once).

`timescale 1ns/1ps

module tb_simulator_writer;

    reg        clock = 1'b0;
    wire [4:0] outLines;
    wire       done;

    tl_simulator_writer dut (
        .inClock  (clock),
        .outLines (outLines),
        .done     (done)
    );

    // 20 ns period, run while not done.
    always begin
        if (!done) #10 clock = ~clock;
        else       #10 ;
    end

    initial begin
        $dumpfile(`VCD_OUT);
        $dumpvars(0, tb_simulator_writer);
        // Hard cap so a stuck `done` cannot hang CI.
        #5_000_000 $display("Reached time cap before done.");
        $finish;
    end

    // Stop early on done.
    always @(posedge done) begin
        $display("Writer signalled done at %0t ns", $time);
        $finish;
    end

endmodule
