`timescale 1ns / 1ps

// Verilog mirror of test/tb_vga_top.vhd. Same four cause/effect
// stages on control_panel: pause toggle, speed-cycler walk, reset
// level, heartbeat passthrough. DEBOUNCE_LIMIT shrunk to 100 ticks
// so each press settles in ~2 us; total sim time stays well under
// 100 us.

module tb_vga_top;
    localparam integer CLK_HALF      = 10;     // 50 MHz
    localparam integer DBLIM         = 100;
    localparam integer SETTLE_CYCLES = DBLIM + 20;

    reg              tbClock           = 1'b0;
    reg              sSimulationActive = 1'b1;
    integer          tbStage           = 0;

    reg  [2:0]       tbButtons    = 3'b111;
    reg              tbHeartbeat  = 1'b0;

    wire             tbPaused;
    wire             tbResetActive;
    wire [1:0]       tbSpeedSelect;
    wire [2:0]       tbPanelLeds;

    control_panel #(.DEBOUNCE_LIMIT(DBLIM)) dut (
        .clk           (tbClock),
        .inputButtons  (tbButtons),
        .heartbeatTick (tbHeartbeat),
        .paused        (tbPaused),
        .resetActive   (tbResetActive),
        .speedSelect   (tbSpeedSelect),
        .panelLeds     (tbPanelLeds)
    );

    always begin
        if (!sSimulationActive) begin
            tbClock = 1'b0;
            #(2 * CLK_HALF);
        end else begin
            #CLK_HALF tbClock = ~tbClock;
        end
    end

    task press(input integer idx);
    begin
        tbButtons[idx] = 1'b0;
        repeat (SETTLE_CYCLES) @(posedge tbClock);
        tbButtons[idx] = 1'b1;
        repeat (SETTLE_CYCLES) @(posedge tbClock);
    end
    endtask

    initial begin
        $dumpfile(`FST_OUT);
        // Explicit signal list to keep the dump readable: the visible
        // testbench wiring + DUT outputs, no internal Debounce state.
        $dumpvars(0, tbClock, sSimulationActive, tbStage,
                     tbButtons, tbHeartbeat,
                     tbPaused, tbResetActive, tbSpeedSelect, tbPanelLeds);

        // Stage 0: settle the debouncers' o_Switch outputs from their
        // power-on '0' to '1'.
        tbStage = 0;
        repeat (SETTLE_CYCLES) @(posedge tbClock);

        // Stage 1: pause toggle.
        tbStage = 1;
        if (tbPaused !== 1'b0) begin
            $display("FAIL stage 1: paused must start cleared"); $fatal;
        end
        if (tbPanelLeds[0] !== 1'b0) begin
            $display("FAIL stage 1: panelLeds[0] must mirror paused"); $fatal;
        end

        press(0);
        if (tbPaused !== 1'b1) begin
            $display("FAIL stage 1a: paused should latch high after one press"); $fatal;
        end
        if (tbPanelLeds[0] !== 1'b1) begin
            $display("FAIL stage 1a: panelLeds[0] must follow paused"); $fatal;
        end

        press(0);
        if (tbPaused !== 1'b0) begin
            $display("FAIL stage 1b: paused should clear after second press"); $fatal;
        end

        // Stage 2: speed cycler.
        tbStage = 2;
        if (tbSpeedSelect !== 2'b00) begin
            $display("FAIL stage 2: speedSelect must start at MEDIUM"); $fatal;
        end
        if (tbPanelLeds[2] !== 1'b0) begin
            $display("FAIL stage 2: fast LED must start cleared"); $fatal;
        end

        press(2);
        if (tbSpeedSelect !== 2'b01) begin
            $display("FAIL stage 2a: MEDIUM -> SLOW expected"); $fatal;
        end
        if (tbPanelLeds[2] !== 1'b0) begin
            $display("FAIL stage 2a: SLOW must not light fast LED"); $fatal;
        end

        press(2);
        if (tbSpeedSelect !== 2'b10) begin
            $display("FAIL stage 2b: SLOW -> FAST expected"); $fatal;
        end
        if (tbPanelLeds[2] !== 1'b1) begin
            $display("FAIL stage 2b: FAST must light fast LED"); $fatal;
        end

        press(2);
        if (tbSpeedSelect !== 2'b00) begin
            $display("FAIL stage 2c: FAST -> MEDIUM expected"); $fatal;
        end

        // Stage 3: reset level.
        tbStage = 3;
        if (tbResetActive !== 1'b0) begin
            $display("FAIL stage 3: resetActive must start cleared"); $fatal;
        end

        tbButtons[1] = 1'b0;
        repeat (SETTLE_CYCLES) @(posedge tbClock);
        if (tbResetActive !== 1'b1) begin
            $display("FAIL stage 3a: resetActive should rise while held"); $fatal;
        end

        tbButtons[1] = 1'b1;
        repeat (SETTLE_CYCLES) @(posedge tbClock);
        if (tbResetActive !== 1'b0) begin
            $display("FAIL stage 3b: resetActive should fall when released"); $fatal;
        end

        // Stage 4: heartbeat passthrough.
        tbStage = 4;
        tbHeartbeat = 1'b1;
        @(posedge tbClock); #1;
        if (tbPanelLeds[1] !== 1'b1) begin
            $display("FAIL stage 4a: panelLeds[1] must follow heartbeat high"); $fatal;
        end
        tbHeartbeat = 1'b0;
        @(posedge tbClock); #1;
        if (tbPanelLeds[1] !== 1'b0) begin
            $display("FAIL stage 4b: panelLeds[1] must follow heartbeat low"); $fatal;
        end

        tbStage = 99;
        repeat (4) @(posedge tbClock);
        sSimulationActive = 1'b0;
        $finish;
    end
endmodule
