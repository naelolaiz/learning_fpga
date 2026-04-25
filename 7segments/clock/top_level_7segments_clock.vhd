------------------------------
-- top level entitry for clock

LIBRARY ieee;

USE ieee.std_logic_1164.ALL;
use ieee.numeric_std.ALL;

entity top_level_7segments_clock is
   port (
         clock: in std_logic;
         resetButton: in std_logic := '1';
         inputButtons : in std_logic_vector(3 downto 0);
         sevenSegments : out std_logic_vector(7 downto 0);
         cableSelect : buffer std_logic_vector(3 downto 0);
         buzzer : out std_logic := '1');
end top_level_7segments_clock;

architecture behavior of top_level_7segments_clock is
-- Main clock display digits and the alarm display digits live in separate
-- BCD vectors; bcdDigitsDisplayed is what the multiplexer ultimately reads.
signal bcdDigits         : std_logic_vector (23 downto 0) := std_logic_vector(to_unsigned(0,24));
signal alarmBcdDigits    : std_logic_vector (23 downto 0) := std_logic_vector(to_unsigned(0,24));
signal bcdDigitsDisplayed: std_logic_vector (23 downto 0) := std_logic_vector(to_unsigned(0,24));

signal enabledDigit: std_logic_vector (1 downto 0) := "00";
signal currentDigitValue: std_logic_vector (3 downto 0) := "0000";

-- Carry bits for the main-clock cascade and a parallel alarm-clock cascade.
signal carryBitSecondsUnit, carryBitSecondsTens, carryBitMinutesUnit, carryBitMinutesTens, carryBitHoursUnit: std_logic := '0';
signal alarmCarryBitSecondsUnit, alarmCarryBitSecondsTens, alarmCarryBitMinutesUnit, alarmCarryBitMinutesTens, alarmCarryBitHoursUnit: std_logic := '0';

signal variableTimerTickForTimeSet: std_logic := '0';
signal timerTick00015Sec: std_logic := '0';
signal mainClockForClock: std_logic := '0';
signal clockForAlarmSet: std_logic := '0';
signal oneSecondPeriodSquare: std_logic := '0';
signal squareWaveForBuzzer: std_logic := '0';

type ClockMode is (MMSS,HHMM);
signal currentClockMode : ClockMode := MMSS;
signal buttonClockModeDebounced : std_logic := '0';
signal resetButtonSignal : std_logic := '0';

-- Currently-displayed clock and the toggle signal driven by inputButtons(1).
type SelectedClock is (MAIN_CLOCK, ALARM_CLOCK);
signal currentSelectedClock : SelectedClock := MAIN_CLOCK;
signal buttonSelectedClockDebounced : std_logic := '1';

signal dotBlinkingSignal : std_logic := '0';

signal increaseTimeButtonDebounced : std_logic := '1';
signal decreaseTimeButtonDebounced : std_logic := '1';

-- The +/- buttons drive whichever clock is currently selected; the other
-- always counts forward (decrease=1 means "forward" in the Digit entity).
signal directionForMainClock  : std_logic := '1';
signal directionForAlarmClock : std_logic := '1';

begin
resetButtonSignal <= not resetButton;

-- Main clock keeps ticking on the 1 Hz square wave when the user is idle
-- OR when the alarm is the focus (so real time doesn't freeze while
-- setting the alarm). When MAIN is focused and a +/- button is held it
-- accelerates: variable rate in MMSS, fixed fast rate in HHMM.
mainClockForClock <= oneSecondPeriodSquare when ((increaseTimeButtonDebounced = '1' and decreaseTimeButtonDebounced = '1') or currentSelectedClock = ALARM_CLOCK)
                      else variableTimerTickForTimeSet when currentClockMode = MMSS
                      else timerTick00015Sec;

-- Alarm cascade only ticks while ALARM is focused AND a +/- button is held;
-- otherwise it stays put (no implicit drift while the user is reading time).
clockForAlarmSet <= '0' when ((increaseTimeButtonDebounced = '1' and decreaseTimeButtonDebounced = '1') or currentSelectedClock = MAIN_CLOCK)
                       else variableTimerTickForTimeSet when currentClockMode = MMSS
                       else timerTick00015Sec;

bcdDigitsDisplayed <= bcdDigits when currentSelectedClock = MAIN_CLOCK else alarmBcdDigits;

directionForMainClock  <= '1' when currentSelectedClock = ALARM_CLOCK else decreaseTimeButtonDebounced;
directionForAlarmClock <= '1' when currentSelectedClock = MAIN_CLOCK  else decreaseTimeButtonDebounced;

-- Middle dot — 1 Hz square in MMSS view; in HHMM, halve the toggle rate
-- (one toggle per second-edge), making the dot blink slower so the view
-- mode is visually distinguishable.
updateDotBlinkingSignal : process(currentClockMode, oneSecondPeriodSquare)
begin
   if currentClockMode = MMSS then
      dotBlinkingSignal <= oneSecondPeriodSquare;
   elsif rising_edge(oneSecondPeriodSquare) then
      dotBlinkingSignal <= not dotBlinkingSignal;
   end if;
end process;

 --------------------------------
 -- timer to get ticks every 1 sec
   timer1Sec : entity work.Timer(behaviorTimer)
      generic map ( MAX_NUMBER => 50000000, -- before it was 49999999. It was copied from examples. TODO: Check why!
                    TRIGGER_DURATION => 25000000 ) -- so we can use the 50% duty cycle for blinking the led
      port map ( clock => clock,
                 timerTriggered => oneSecondPeriodSquare,
                 reset => resetButtonSignal);

   timer00015Sec : entity work.Timer(behaviorTimer)
      generic map ( MAX_NUMBER => 75000 )
      port map ( clock => clock,
                 timerTriggered => timerTick00015Sec,
                 reset => resetButtonSignal);

   variableTimerForTimeSet : entity work.VariableTimer(behaviorVariableTimer)
   generic map ( MAX_NUMBER => 2500000 )
      port map ( clock => clock,
                 timerTriggered => variableTimerTickForTimeSet,
                 reset => resetButtonSignal);

   -- ~400 Hz square used as the buzzer tone source.
   square400Hz : entity work.Timer(behaviorTimer)
      generic map ( MAX_NUMBER => 125000,
                    TRIGGER_DURATION => 62500)
      port map ( clock => clock,
                 timerTriggered => squareWaveForBuzzer,
                 reset => resetButtonSignal);

 ------------------------------------------------------------------
 -- counter for for multiplexer (4 digits, one increment every 2ms)
   counterForMux : entity work.CounterTimer(behaviorCounterTimer)
    generic map (MAX_NUMBER_FOR_TIMER => 100000, -- tick every 100E3 / 50E6 = 2ms
                 MAX_NUMBER_FOR_COUNTER => 3)
    port map ( clock => clock,
               counter (1 downto 0) => enabledDigit);

 -- Main-clock digit cascade.
   digitSecsUnit : entity work.Digit(behaviorDigit)
    generic map (MAX_NUMBER => 9)
    port map (
      clock => mainClockForClock,
      direction => directionForMainClock,
      currentNumber => bcdDigits(3 downto 0),
      carryBit => carryBitSecondsUnit,
      reset => resetButtonSignal);

   digitSecsTens : entity work.Digit(behaviorDigit)
    generic map (MAX_NUMBER => 5)
    port map (
      clock => carryBitSecondsUnit,
      direction => directionForMainClock,
      currentNumber => bcdDigits(7 downto 4),
      carryBit => carryBitSecondsTens,
      reset => resetButtonSignal);

   digitMinsUnit : entity work.Digit(behaviorDigit)
    generic map (MAX_NUMBER => 9)
    port map (
      clock => carryBitSecondsTens,
      direction => directionForMainClock,
      currentNumber => bcdDigits(11 downto 8),
      carryBit => carryBitMinutesUnit,
      reset => resetButtonSignal);

   digitMinsTens : entity work.Digit(behaviorDigit)
    generic map (MAX_NUMBER => 5)
    port map (
      clock => carryBitMinutesUnit,
      direction => directionForMainClock,
      currentNumber => bcdDigits(15 downto 12),
      carryBit => carryBitMinutesTens,
      reset => resetButtonSignal);

   digitHoursUnit : entity work.Digit(behaviorDigit)
    generic map (MAX_NUMBER => 3)
    port map (
      clock => carryBitMinutesTens,
      direction => directionForMainClock,
      currentNumber => bcdDigits(19 downto 16),
      carryBit => carryBitHoursUnit,
      reset => resetButtonSignal);

   digitHoursTens : entity work.Digit(behaviorDigit)
    generic map (MAX_NUMBER => 2)
    port map (
      clock => carryBitHoursUnit,
      direction => directionForMainClock,
      currentNumber => bcdDigits(23 downto 20),
      reset => resetButtonSignal);

 -- Alarm-clock digit cascade (same shape, fed from clockForAlarmSet).
   alarmDigitSecsUnit : entity work.Digit(behaviorDigit)
    generic map (MAX_NUMBER => 9)
    port map (
      clock => clockForAlarmSet,
      direction => directionForAlarmClock,
      currentNumber => alarmBcdDigits(3 downto 0),
      carryBit => alarmCarryBitSecondsUnit,
      reset => resetButtonSignal);

   alarmDigitSecsTens : entity work.Digit(behaviorDigit)
    generic map (MAX_NUMBER => 5)
    port map (
      clock => alarmCarryBitSecondsUnit,
      direction => directionForAlarmClock,
      currentNumber => alarmBcdDigits(7 downto 4),
      carryBit => alarmCarryBitSecondsTens,
      reset => resetButtonSignal);

   alarmDigitMinsUnit : entity work.Digit(behaviorDigit)
    generic map (MAX_NUMBER => 9)
    port map (
      clock => alarmCarryBitSecondsTens,
      direction => directionForAlarmClock,
      currentNumber => alarmBcdDigits(11 downto 8),
      carryBit => alarmCarryBitMinutesUnit,
      reset => resetButtonSignal);

   alarmDigitMinsTens : entity work.Digit(behaviorDigit)
    generic map (MAX_NUMBER => 5)
    port map (
      clock => alarmCarryBitMinutesUnit,
      direction => directionForAlarmClock,
      currentNumber => alarmBcdDigits(15 downto 12),
      carryBit => alarmCarryBitMinutesTens,
      reset => resetButtonSignal);

   alarmDigitHoursUnit : entity work.Digit(behaviorDigit)
    generic map (MAX_NUMBER => 3)
    port map (
      clock => alarmCarryBitMinutesTens,
      direction => directionForAlarmClock,
      currentNumber => alarmBcdDigits(19 downto 16),
      carryBit => alarmCarryBitHoursUnit,
      reset => resetButtonSignal);

   alarmDigitHoursTens : entity work.Digit(behaviorDigit)
    generic map (MAX_NUMBER => 2)
    port map (
      clock => alarmCarryBitHoursUnit,
      direction => directionForAlarmClock,
      currentNumber => alarmBcdDigits(23 downto 20),
      reset => resetButtonSignal);

   -- Intermittent alarm tone: when the alarm matches the main clock above
   -- the seconds-units field, the buzzer is gated by the 1 Hz square so
   -- the ~400 Hz tone pulses on/off once per second. The match window
   -- naturally lasts ~10 s of seconds (until the seconds-tens advances
   -- past the alarm value), recreating commit 083576f's behaviour.
   buzzer <= squareWaveForBuzzer and oneSecondPeriodSquare
                when alarmBcdDigits(23 downto 4) = bcdDigits(23 downto 4)
                else 'Z';

   debounce_clock_mode_switch : entity work.Debounce(RTL)
    port map(
    i_Clk    => clock,
    i_Switch => inputButtons(0),
    o_Switch => buttonClockModeDebounced
  );

  debounce_view_alarm : entity work.Debounce(RTL)
    port map(
    i_Clk    => clock,
    i_Switch => inputButtons(1),
    o_Switch => buttonSelectedClockDebounced
  );

  debounce_increase_time_button : entity work.Debounce(RTL)
    port map(
    i_Clk    => clock,
    i_Switch => inputButtons(2),
    o_Switch => decreaseTimeButtonDebounced
  );

  debounce_decrease_time_button : entity work.Debounce(RTL)
    port map(
    i_Clk    => clock,
    i_Switch => inputButtons(3),
    o_Switch => increaseTimeButtonDebounced
  );


   ---- button handler
   buttonClockModeHandler: process(buttonClockModeDebounced)
   begin
      if buttonClockModeDebounced'event and buttonClockModeDebounced = '0' then
         -- currentClockMode is toggled with button 0
         ----unsigned'('0' & inputButtons(0));  see https://stackoverflow.com/questions/63278766/convert-std-logic-vector-to-enum-type-in-vhdl
         -- and https://stackoverflow.com/questions/34039510/std-logic-to-integer-conversion
         currentClockMode <= ClockMode'val(to_integer(unsigned(not std_logic_vector(to_unsigned(ClockMode'pos(currentClockMode),1)))));
      end if;
   end process;

   buttonSelectedClockHandler: process(buttonSelectedClockDebounced)
   begin
      if buttonSelectedClockDebounced'event and buttonSelectedClockDebounced = '0' then
         currentSelectedClock <= SelectedClock'val(to_integer(unsigned(not std_logic_vector(to_unsigned(SelectedClock'pos(currentSelectedClock),1)))));
      end if;
   end process;

   -- MUX to generate anode activating signals for 4 LEDs
   process(enabledDigit, bcdDigitsDisplayed, currentClockMode)
      constant nibbleToShift: std_logic_vector(3 downto 0) := "0001";
   begin
      cableSelect <= not std_logic_vector(unsigned(nibbleToShift) sll to_integer(unsigned(enabledDigit)));
      currentDigitValue <= std_logic_vector(unsigned(bcdDigitsDisplayed) srl ((to_integer(unsigned(enabledDigit)) + (ClockMode'pos(currentClockMode) * 2))*4)) (3 downto 0);
   end process;

   -- BCD to 7 segments. The dot bit is dotBlinkingSignal (gated by
   -- cableSelect(2) so only the middle digit's dot lights), XOR-inverted
   -- in alarm view as a visual cue that ALARM is selected.
   sevenSegments <= ((dotBlinkingSignal or cableSelect(2)) xor std_logic_vector(to_unsigned(SelectedClock'pos(currentSelectedClock), 1))(0)) & "1000000" when currentDigitValue = "0000" else
                    ((dotBlinkingSignal or cableSelect(2)) xor std_logic_vector(to_unsigned(SelectedClock'pos(currentSelectedClock), 1))(0)) & "1111001" when currentDigitValue =  "0001" else
                    ((dotBlinkingSignal or cableSelect(2)) xor std_logic_vector(to_unsigned(SelectedClock'pos(currentSelectedClock), 1))(0)) & "0100100" when currentDigitValue =  "0010" else
                    ((dotBlinkingSignal or cableSelect(2)) xor std_logic_vector(to_unsigned(SelectedClock'pos(currentSelectedClock), 1))(0)) & "0110000" when currentDigitValue =  "0011" else
                    ((dotBlinkingSignal or cableSelect(2)) xor std_logic_vector(to_unsigned(SelectedClock'pos(currentSelectedClock), 1))(0)) & "0011001" when currentDigitValue =  "0100" else
                    ((dotBlinkingSignal or cableSelect(2)) xor std_logic_vector(to_unsigned(SelectedClock'pos(currentSelectedClock), 1))(0)) & "0010010" when currentDigitValue =  "0101" else
                    ((dotBlinkingSignal or cableSelect(2)) xor std_logic_vector(to_unsigned(SelectedClock'pos(currentSelectedClock), 1))(0)) & "0000010" when currentDigitValue =  "0110" else
                    ((dotBlinkingSignal or cableSelect(2)) xor std_logic_vector(to_unsigned(SelectedClock'pos(currentSelectedClock), 1))(0)) & "1111000" when currentDigitValue =  "0111" else
                    ((dotBlinkingSignal or cableSelect(2)) xor std_logic_vector(to_unsigned(SelectedClock'pos(currentSelectedClock), 1))(0)) & "0000000" when currentDigitValue =  "1000" else
                    ((dotBlinkingSignal or cableSelect(2)) xor std_logic_vector(to_unsigned(SelectedClock'pos(currentSelectedClock), 1))(0)) & "0010000" when currentDigitValue =  "1001" else
                    ((dotBlinkingSignal or cableSelect(2)) xor std_logic_vector(to_unsigned(SelectedClock'pos(currentSelectedClock), 1))(0)) & "0001000" when currentDigitValue =  "1010" else
                    ((dotBlinkingSignal or cableSelect(2)) xor std_logic_vector(to_unsigned(SelectedClock'pos(currentSelectedClock), 1))(0)) & "0000011" when currentDigitValue =  "1011" else
                    ((dotBlinkingSignal or cableSelect(2)) xor std_logic_vector(to_unsigned(SelectedClock'pos(currentSelectedClock), 1))(0)) & "1000110" when currentDigitValue =  "1100" else
                    ((dotBlinkingSignal or cableSelect(2)) xor std_logic_vector(to_unsigned(SelectedClock'pos(currentSelectedClock), 1))(0)) & "0100001" when currentDigitValue =  "1101" else
                    ((dotBlinkingSignal or cableSelect(2)) xor std_logic_vector(to_unsigned(SelectedClock'pos(currentSelectedClock), 1))(0)) & "0000110" when currentDigitValue =  "1110" else
                    ((dotBlinkingSignal or cableSelect(2)) xor std_logic_vector(to_unsigned(SelectedClock'pos(currentSelectedClock), 1))(0)) & "0001110";
end behavior;
