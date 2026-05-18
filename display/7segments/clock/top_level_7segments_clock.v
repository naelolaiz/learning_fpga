// Verilog mirror of top_level_7segments_clock.vhd.
//
// Mirrors the VHDL top-level 1:1: same port names, same generic-
// shaped parameters (so testbenches can shrink the timers
// identically), same internal signal names where reasonable. The
// shape is:
//
//   +-- Timer (1 Hz square)         --+
//   +-- Timer (~666 Hz fast-set)    --+
//   +-- VariableTimer (set-time UX) --+--> tick selectors -> mainClock /
//   +-- Timer (~400 Hz buzzer tone) --+    clockForAlarmSet
//   +-- CounterTimer (mux 4 digits) --+
//   |
//   +-- mod_counter cascade (main, 6 digits)
//   +-- mod_counter cascade (alarm, 6 digits)
//   +-- mode_blink (drives the middle-dot bit)
//   +-- Debounce x4 (mode toggle, alarm-view toggle, +/- buttons)
//
// The alarm comparator + buzzer gating is a single inline expression
// (the AlarmTrigger entity from the 2022 source has been dropped
// since its body was three combinational lines).
//
// The Verilog encoder for the BCD-to-7-seg lookup uses a `case`, where
// the VHDL uses a chained when-else. Logically identical.

module top_level_7segments_clock #(
    parameter integer MAX_NUMBER_FOR_1SEC_TIMER         = 50_000_000,
    parameter integer TRIGGER_DURATION_FOR_1SEC_TIMER   = 25_000_000,
    parameter integer MAX_NUMBER_FOR_FAST_SET_TIMER     = 75_000,
    parameter integer MAX_NUMBER_FOR_VARIABLE_TIMER     = 2_500_000,
    parameter integer MAX_NUMBER_FOR_BUZZER_TIMER       = 125_000,
    parameter integer TRIGGER_DURATION_FOR_BUZZER_TIMER = 62_500,
    parameter integer MAX_NUMBER_FOR_MUX_TIMER          = 100_000
) (
    input  wire       clock,
    input  wire       resetButton,
    input  wire [3:0] inputButtons,
    output reg  [7:0] sevenSegments,
    output wire [3:0] cableSelect,
    output wire       buzzer
);

    localparam MMSS = 1'b0;
    localparam HHMM = 1'b1;
    localparam MAIN_CLOCK  = 1'b0;
    localparam ALARM_CLOCK = 1'b1;

    wire resetButtonSignal = ~resetButton;

    // ---- BCD vectors -----------------------------------------------------
    wire [23:0] bcdDigits;
    wire [23:0] alarmBcdDigits;
    wire [23:0] bcdDigitsDisplayed;
    reg  [3:0]  currentDigitValue = 4'd0;

    wire [63:0] muxCounterFull;
    wire [1:0]  enabledDigit = muxCounterFull[1:0];

    wire variableTimerTickForTimeSet;
    wire timerTick00015Sec;
    wire oneSecondPeriodSquare;
    wire squareWaveForBuzzer;

    reg  currentClockMode      = MMSS;
    wire buttonClockModeDebounced;
    reg  currentSelectedClock  = MAIN_CLOCK;
    wire buttonSelectedClockDebounced;

    wire dotBlinkingSignal;
    wire isHHMMModeBit       = (currentClockMode == HHMM);
    wire selectedClockBit    = (currentSelectedClock == ALARM_CLOCK);

    wire increaseTimeButtonDebounced;
    wire decreaseTimeButtonDebounced;

    // Active clock tick + direction selectors. See the VHDL mirror for
    // the rationale; these are bit-for-bit equivalent.
    wire mainClockForClock =
        ((increaseTimeButtonDebounced && decreaseTimeButtonDebounced) ||
         (currentSelectedClock == ALARM_CLOCK)) ? oneSecondPeriodSquare :
        (currentClockMode == MMSS)              ? variableTimerTickForTimeSet :
                                                  timerTick00015Sec;

    wire clockForAlarmSet =
        ((increaseTimeButtonDebounced && decreaseTimeButtonDebounced) ||
         (currentSelectedClock == MAIN_CLOCK)) ? 1'b0 :
        (currentClockMode == MMSS)             ? variableTimerTickForTimeSet :
                                                 timerTick00015Sec;

    assign bcdDigitsDisplayed = (currentSelectedClock == MAIN_CLOCK)
                                    ? bcdDigits : alarmBcdDigits;

    wire directionForMainClock  = (currentSelectedClock == ALARM_CLOCK)
                                    ? 1'b1 : decreaseTimeButtonDebounced;
    wire directionForAlarmClock = (currentSelectedClock == MAIN_CLOCK)
                                    ? 1'b1 : decreaseTimeButtonDebounced;

    // ---- Middle-dot blinker ---------------------------------------------
    mode_blink dotBlinker (
        .signalIn   (oneSecondPeriodSquare),
        .toggleMode (isHHMMModeBit),
        .signalOut  (dotBlinkingSignal)
    );

    // ---- Timers ----------------------------------------------------------
    // Each instance drives `maxLimit` explicitly (Verilog input ports
    // have no default value, so leaving it unconnected would feed Z).
    Timer #(.MAX_NUMBER(MAX_NUMBER_FOR_1SEC_TIMER),
            .TRIGGER_DURATION(TRIGGER_DURATION_FOR_1SEC_TIMER))
        timer1Sec (
            .clock          (clock),
            .reset          (resetButtonSignal),
            .maxLimit       (MAX_NUMBER_FOR_1SEC_TIMER[31:0]),
            .timerTriggered (oneSecondPeriodSquare));

    Timer #(.MAX_NUMBER(MAX_NUMBER_FOR_FAST_SET_TIMER))
        timer00015Sec (
            .clock          (clock),
            .reset          (resetButtonSignal),
            .maxLimit       (MAX_NUMBER_FOR_FAST_SET_TIMER[31:0]),
            .timerTriggered (timerTick00015Sec));

    VariableTimer #(.MAX_NUMBER(MAX_NUMBER_FOR_VARIABLE_TIMER))
        variableTimerForTimeSet (
            .clock          (clock),
            .reset          (resetButtonSignal),
            .setMax         (1'b0),
            .dataIn         (1'b0),
            .timerTriggered (variableTimerTickForTimeSet));

    Timer #(.MAX_NUMBER(MAX_NUMBER_FOR_BUZZER_TIMER),
            .TRIGGER_DURATION(TRIGGER_DURATION_FOR_BUZZER_TIMER))
        square400Hz (
            .clock          (clock),
            .reset          (resetButtonSignal),
            .maxLimit       (MAX_NUMBER_FOR_BUZZER_TIMER[31:0]),
            .timerTriggered (squareWaveForBuzzer));

    // ---- Mux counter (4 digits) -----------------------------------------
    CounterTimer #(.MAX_NUMBER_FOR_TIMER(MAX_NUMBER_FOR_MUX_TIMER),
                   .MAX_NUMBER_FOR_COUNTER(3))
        counterForMux (
            .clock          (clock),
            .reset          (resetButtonSignal),
            .timerTriggered (),
            .counter        (muxCounterFull));

    // ---- Main-clock digit cascade ---------------------------------------
    wire carryBitSecondsUnit, carryBitSecondsTens;
    wire carryBitMinutesUnit, carryBitMinutesTens, carryBitHoursUnit;

    mod_counter #(.MAX_NUMBER(9)) digitSecsUnit (
        .clock(mainClockForClock), .reset(resetButtonSignal),
        .direction(directionForMainClock),
        .currentNumber(bcdDigits[3:0]),  .carryBit(carryBitSecondsUnit));
    mod_counter #(.MAX_NUMBER(5)) digitSecsTens (
        .clock(carryBitSecondsUnit), .reset(resetButtonSignal),
        .direction(directionForMainClock),
        .currentNumber(bcdDigits[7:4]),  .carryBit(carryBitSecondsTens));
    mod_counter #(.MAX_NUMBER(9)) digitMinsUnit (
        .clock(carryBitSecondsTens), .reset(resetButtonSignal),
        .direction(directionForMainClock),
        .currentNumber(bcdDigits[11:8]), .carryBit(carryBitMinutesUnit));
    mod_counter #(.MAX_NUMBER(5)) digitMinsTens (
        .clock(carryBitMinutesUnit), .reset(resetButtonSignal),
        .direction(directionForMainClock),
        .currentNumber(bcdDigits[15:12]), .carryBit(carryBitMinutesTens));
    mod_counter #(.MAX_NUMBER(3)) digitHoursUnit (
        .clock(carryBitMinutesTens), .reset(resetButtonSignal),
        .direction(directionForMainClock),
        .currentNumber(bcdDigits[19:16]), .carryBit(carryBitHoursUnit));
    mod_counter #(.MAX_NUMBER(2)) digitHoursTens (
        .clock(carryBitHoursUnit), .reset(resetButtonSignal),
        .direction(directionForMainClock),
        .currentNumber(bcdDigits[23:20]), .carryBit());

    // ---- Alarm-clock digit cascade --------------------------------------
    wire alarmCarryBitSecondsUnit, alarmCarryBitSecondsTens;
    wire alarmCarryBitMinutesUnit, alarmCarryBitMinutesTens, alarmCarryBitHoursUnit;

    mod_counter #(.MAX_NUMBER(9)) alarmDigitSecsUnit (
        .clock(clockForAlarmSet), .reset(resetButtonSignal),
        .direction(directionForAlarmClock),
        .currentNumber(alarmBcdDigits[3:0]),  .carryBit(alarmCarryBitSecondsUnit));
    mod_counter #(.MAX_NUMBER(5)) alarmDigitSecsTens (
        .clock(alarmCarryBitSecondsUnit), .reset(resetButtonSignal),
        .direction(directionForAlarmClock),
        .currentNumber(alarmBcdDigits[7:4]),  .carryBit(alarmCarryBitSecondsTens));
    mod_counter #(.MAX_NUMBER(9)) alarmDigitMinsUnit (
        .clock(alarmCarryBitSecondsTens), .reset(resetButtonSignal),
        .direction(directionForAlarmClock),
        .currentNumber(alarmBcdDigits[11:8]), .carryBit(alarmCarryBitMinutesUnit));
    mod_counter #(.MAX_NUMBER(5)) alarmDigitMinsTens (
        .clock(alarmCarryBitMinutesUnit), .reset(resetButtonSignal),
        .direction(directionForAlarmClock),
        .currentNumber(alarmBcdDigits[15:12]), .carryBit(alarmCarryBitMinutesTens));
    mod_counter #(.MAX_NUMBER(3)) alarmDigitHoursUnit (
        .clock(alarmCarryBitMinutesTens), .reset(resetButtonSignal),
        .direction(directionForAlarmClock),
        .currentNumber(alarmBcdDigits[19:16]), .carryBit(alarmCarryBitHoursUnit));
    mod_counter #(.MAX_NUMBER(2)) alarmDigitHoursTens (
        .clock(alarmCarryBitHoursUnit), .reset(resetButtonSignal),
        .direction(directionForAlarmClock),
        .currentNumber(alarmBcdDigits[23:20]), .carryBit());

    // ---- Alarm comparator + buzzer gating (inlined) ---------------------
    // Compare bits 23..4 (everything above seconds-units) so a single
    // match holds for ~10 simulated seconds before the units roll
    // over; AND the ~400 Hz tone with the 1 Hz square so the alarm
    // beeps once per second instead of holding a continuous tone.
    wire alarmMatch = (bcdDigits[23:4] == alarmBcdDigits[23:4]);
    assign buzzer = alarmMatch & squareWaveForBuzzer & oneSecondPeriodSquare;

    // ---- Debounced buttons ----------------------------------------------
    Debounce debounce_clock_mode_switch (
        .i_Clk    (clock),
        .i_Switch (inputButtons[0]),
        .o_Switch (buttonClockModeDebounced));
    Debounce debounce_view_alarm (
        .i_Clk    (clock),
        .i_Switch (inputButtons[1]),
        .o_Switch (buttonSelectedClockDebounced));
    Debounce debounce_increase_time_button (
        .i_Clk    (clock),
        .i_Switch (inputButtons[2]),
        .o_Switch (decreaseTimeButtonDebounced));
    Debounce debounce_decrease_time_button (
        .i_Clk    (clock),
        .i_Switch (inputButtons[3]),
        .o_Switch (increaseTimeButtonDebounced));

    // Toggle clockMode on each falling edge of buttonClockModeDebounced.
    reg buttonClockModeDebounced_d = 1'b0;
    always @(posedge clock) begin
        buttonClockModeDebounced_d <= buttonClockModeDebounced;
        if (buttonClockModeDebounced_d && !buttonClockModeDebounced)
            currentClockMode <= ~currentClockMode;
    end
    // Toggle selectedClock on each falling edge of buttonSelectedClockDebounced.
    reg buttonSelectedClockDebounced_d = 1'b1;
    always @(posedge clock) begin
        buttonSelectedClockDebounced_d <= buttonSelectedClockDebounced;
        if (buttonSelectedClockDebounced_d && !buttonSelectedClockDebounced)
            currentSelectedClock <= ~currentSelectedClock;
    end

    // ---- Anode mux ------------------------------------------------------
    assign cableSelect = ~(4'b0001 << enabledDigit);

    // Pre-shifted form so we can take the bottom nibble as a clean slice.
    wire [23:0] shiftedBcdDigits =
        bcdDigitsDisplayed >> ((enabledDigit + (currentClockMode ? 2 : 0)) * 4);

    always @(*) begin
        currentDigitValue = shiftedBcdDigits[3:0];
    end

    // ---- BCD -> 7-segment encoder (active-low cathodes) -----------------
    // Top bit (sevenSegments[7]) is the dot, gated and XOR-inverted in
    // alarm view (matches the VHDL encoder exactly).
    always @(*) begin
        reg dot;
        reg [6:0] seg;
        dot = (dotBlinkingSignal | cableSelect[2]) ^ selectedClockBit;
        case (currentDigitValue)
            4'h0: seg = 7'b1000000;
            4'h1: seg = 7'b1111001;
            4'h2: seg = 7'b0100100;
            4'h3: seg = 7'b0110000;
            4'h4: seg = 7'b0011001;
            4'h5: seg = 7'b0010010;
            4'h6: seg = 7'b0000010;
            4'h7: seg = 7'b1111000;
            4'h8: seg = 7'b0000000;
            4'h9: seg = 7'b0010000;
            4'ha: seg = 7'b0001000;
            4'hb: seg = 7'b0000011;
            4'hc: seg = 7'b1000110;
            4'hd: seg = 7'b0100001;
            4'he: seg = 7'b0000110;
            default: seg = 7'b0001110;
        endcase
        sevenSegments = {dot, seg};
    end

endmodule
