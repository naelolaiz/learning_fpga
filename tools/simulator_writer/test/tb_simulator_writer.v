// Verilog testbench mirror of tb_simulator_writer.vhd.
//
// Drives the writer with a 50 MHz clock until the DUT's `done` pulses
// high (signals that the message has rendered once). The clock is
// gated on sSimulationActive so the VHDL and Verilog waveforms carry
// the same shutdown signal.

`timescale 1ns/1ps

module tb_simulator_writer;

    reg        clock = 1'b0;
    wire [4:0] outLines;

    reg        sSimulationActive = 1'b1;

    // The DUT's `done` is referenced via `dut.done` throughout — no
    // TB-level wire so the dump does not expose the same signal twice.
    tl_simulator_writer dut (
        .inClock  (clock),
        .outLines (outLines),
        .done     ()
    );

    // 20 ns period, gated on sSimulationActive.
    always #10 if (sSimulationActive) clock = ~clock;

    // Dump TB-level signals plus the DUT signals that the VHDL side
    // also exposes. tl_simulator_writer keeps the v* state counters
    // as module-scope integers for yosys synthesis; listing signals
    // explicitly here hides them from the FST so the VHDL and Verilog
    // waveforms carry the same set.
    initial begin
        $dumpfile(`FST_OUT);
        $dumpvars(1, tb_simulator_writer);
        $dumpvars(0, dut.inClock, dut.outLines, dut.done,
                     dut.sOutRow, dut.sCurrentBlank);
    end

    // Hard cap so a stuck `done` cannot hang CI.
    initial begin : driver
        #5_000_000 $display("Reached time cap before done.");
        sSimulationActive = 1'b0;
        $finish;
    end

    // Stop early on done.
    always @(posedge dut.done) begin
        $display("Writer signalled done at %0t ns", $time);
        sSimulationActive = 1'b0;
        $finish;
    end

endmodule
