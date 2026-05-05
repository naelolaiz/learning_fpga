// Verilog mirror of control_panel.vhd. 1:1 port — same generic
// (DEBOUNCE_LIMIT), same ports, same behaviour. Module name kept in
// snake_case to match the VHDL entity so the gallery's stem-based
// pairing puts both diagrams on the same row.
//
// Pause / speed cycler use the debounced switch as their clock — the
// VHDL idiom is `falling_edge(sBtnXxxDebounced)`, which Verilog
// expresses as `always @(negedge sBtnXxxDebounced)`. Synthesis treats
// the button level as a (very-slow) clock domain; that's the standard
// "press = falling edge of debounced output" pattern this project uses
// elsewhere (see display/7segments/clock).

module control_panel #(
    parameter integer DEBOUNCE_LIMIT = 250_000
) (
    input              clk,
    input      [2:0]   inputButtons,
    input              heartbeatTick,
    output             paused,
    output             resetActive,
    output     [1:0]   speedSelect,
    output     [2:0]   panelLeds
);

    wire sBtnPauseDebounced;
    wire sBtnResetDebounced;
    wire sBtnSpeedDebounced;

    reg       sPaused      = 1'b0;
    reg [1:0] sSpeedSelect = 2'b00;   // 00 = MEDIUM, 01 = SLOW, 10 = FAST

    Debounce #(.DEBOUNCE_LIMIT(DEBOUNCE_LIMIT)) debouncePause (
        .i_Clk    (clk),
        .i_Switch (inputButtons[0]),
        .o_Switch (sBtnPauseDebounced)
    );
    Debounce #(.DEBOUNCE_LIMIT(DEBOUNCE_LIMIT)) debounceReset (
        .i_Clk    (clk),
        .i_Switch (inputButtons[1]),
        .o_Switch (sBtnResetDebounced)
    );
    Debounce #(.DEBOUNCE_LIMIT(DEBOUNCE_LIMIT)) debounceSpeed (
        .i_Clk    (clk),
        .i_Switch (inputButtons[2]),
        .o_Switch (sBtnSpeedDebounced)
    );

    // Pause toggle on each press of button 0 — falling edge of the
    // debounced output (active-low button, so a press = 1→0 transition
    // after settle).
    always @(negedge sBtnPauseDebounced) begin
        sPaused <= ~sPaused;
    end

    // Speed cycler. Each press of button 2 advances the 2-bit code:
    //   00 (MEDIUM) -> 01 (SLOW) -> 10 (FAST) -> 00 (MEDIUM).
    always @(negedge sBtnSpeedDebounced) begin
        case (sSpeedSelect)
            2'b00:   sSpeedSelect <= 2'b01;
            2'b01:   sSpeedSelect <= 2'b10;
            default: sSpeedSelect <= 2'b00;
        endcase
    end

    assign paused       = sPaused;
    assign resetActive  = ~sBtnResetDebounced;     // active-low → active-high
    assign speedSelect  = sSpeedSelect;
    assign panelLeds[0] = sPaused;
    assign panelLeds[1] = heartbeatTick;
    assign panelLeds[2] = (sSpeedSelect == 2'b10);

endmodule // control_panel
