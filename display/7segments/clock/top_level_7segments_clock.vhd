------------------------------
-- top level entitry for clock
--
-- VHDL-2008 (compiled with `--std=08`). The original 2022 source used
-- pre-2008 dialects, but the testbenches that ship with this project
-- target VHDL-2008, and the entire build runs through ghdl in that
-- mode. Two specific 2008 incompatibilities had to be cleaned up while
-- bringing this file forward (both flagged inline below):
--
--   1) `<integer-variable>'HIGH` was rejected as "prefix must be an
--      array"; spell the upper bound as a literal instead. (See
--      VariableTimer.vhd:50.)
--   2) Indexing the result of a type conversion --
--      `std_logic_vector(...)(0)` and `std_logic_vector(... srl ...) (3 downto 0)`
--      -- is rejected as "type conversion cannot be indexed or sliced".
--      Bind the conversion to a signal first, then slice the signal.
--
-- The body otherwise sticks to constructs that work under both -93 and
-- -08, so this file remains readable as plain-old VHDL.

LIBRARY ieee;

USE ieee.std_logic_1164.ALL;
use ieee.numeric_std.ALL;

entity top_level_7segments_clock is
   -- All timer constants are exposed as generics so testbenches can shrink
   -- them by orders of magnitude while keeping their ratios; the defaults
   -- match the 50 MHz on-board clock and produce real-time behaviour.
   generic (
         MAX_NUMBER_FOR_1SEC_TIMER       : integer := 50000000;
         TRIGGER_DURATION_FOR_1SEC_TIMER : integer := 25000000;
         MAX_NUMBER_FOR_FAST_SET_TIMER   : integer := 75000;
         MAX_NUMBER_FOR_VARIABLE_TIMER   : integer := 2500000;
         MAX_NUMBER_FOR_BUZZER_TIMER     : integer := 125000;
         TRIGGER_DURATION_FOR_BUZZER_TIMER : integer := 62500;
         MAX_NUMBER_FOR_MUX_TIMER        : integer := 100000);
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
-- Full-width sink for the CounterTimer's `counter` port: GHDL-08 rejects
-- partial port-map associations like `counter(1 downto 0) => enabledDigit`,
-- so we bind the full 64-bit output and slice off the two LSBs we need.
signal muxCounterFull : std_logic_vector (63 downto 0) := (others => '0');
signal currentDigitValue: std_logic_vector (3 downto 0) := "0000";
-- Pre-shifted form of bcdDigitsDisplayed so we can slice it without
-- indexing a type-conversion expression (also rejected by VHDL-08).
signal shiftedBcdDigits : std_logic_vector (23 downto 0) := (others => '0');

-- Carry bits for the main-clock cascade and a parallel alarm-clock cascade.
signal carryBitSecondsUnit, carryBitSecondsTens, carryBitMinutesUnit, carryBitMinutesTens, carryBitHoursUnit: std_logic := '0';
signal alarmCarryBitSecondsUnit, alarmCarryBitSecondsTens, alarmCarryBitMinutesUnit, alarmCarryBitMinutesTens, alarmCarryBitHoursUnit: std_logic := '0';

signal variableTimerTickForTimeSet: std_logic := '0';
signal timerTick00015Sec: std_logic := '0';
signal mainClockForClock: std_logic := '0';
signal clockForAlarmSet: std_logic := '0';
signal oneSecondPeriodSquare: std_logic := '0';
signal squareWaveForBuzzer: std_logic := '0';
signal alarmMatch: std_logic := '0';

type ClockMode is (MMSS,HHMM);
signal currentClockMode : ClockMode := MMSS;
signal buttonClockModeDebounced : std_logic := '0';
signal resetButtonSignal : std_logic := '0';

-- Currently-displayed clock and the toggle signal driven by inputButtons(1).
type SelectedClock is (MAIN_CLOCK, ALARM_CLOCK);
signal currentSelectedClock : SelectedClock := MAIN_CLOCK;
signal buttonSelectedClockDebounced : std_logic := '1';

signal dotBlinkingSignal : std_logic := '0';
signal isHHMMModeBit     : std_logic := '0';

-- '1' when the alarm view is currently selected. Used to XOR-invert the
-- decimal-point polarity in the BCD-to-7-seg encoder. Pulled out into a
-- standalone signal because the older inline form
-- `std_logic_vector(to_unsigned(SelectedClock'pos(...), 1))(0)` is
-- rejected under strict VHDL-08 ("type conversion cannot be indexed").
signal selectedClockBit : std_logic := '0';

signal increaseTimeButtonDebounced : std_logic := '1';
signal decreaseTimeButtonDebounced : std_logic := '1';

-- The +/- buttons drive whichever clock is currently selected; the other
-- always counts forward (decrease=1 means "forward" in the Digit entity).
signal directionForMainClock  : std_logic := '1';
signal directionForAlarmClock : std_logic := '1';

begin
resetButtonSignal <= not resetButton;
selectedClockBit  <= '1' when currentSelectedClock = ALARM_CLOCK else '0';
isHHMMModeBit     <= '1' when currentClockMode = HHMM else '0';

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

-- Middle-dot blink — delegated to the mode_blink building block so a
-- testbench can drive the 1 Hz square directly without paying for
-- the divider chain. mode_blink's neutral port names map cleanly:
-- signalIn = the 1 Hz square, toggleMode selects between full-rate
-- pass-through (MMSS) and rising-edge-toggle half rate (HHMM).
dotBlinker : entity work.mode_blink(RTL)
   port map (
      signalIn   => oneSecondPeriodSquare,
      toggleMode => isHHMMModeBit,
      signalOut  => dotBlinkingSignal);

 --------------------------------
 -- timer to get ticks every 1 sec
   timer1Sec : entity work.Timer(behaviorTimer)
      generic map ( MAX_NUMBER => MAX_NUMBER_FOR_1SEC_TIMER,
                    TRIGGER_DURATION => TRIGGER_DURATION_FOR_1SEC_TIMER )
      port map ( clock => clock,
                 timerTriggered => oneSecondPeriodSquare,
                 reset => resetButtonSignal);

   timer00015Sec : entity work.Timer(behaviorTimer)
      generic map ( MAX_NUMBER => MAX_NUMBER_FOR_FAST_SET_TIMER )
      port map ( clock => clock,
                 timerTriggered => timerTick00015Sec,
                 reset => resetButtonSignal);

   variableTimerForTimeSet : entity work.VariableTimer(composition)
      generic map ( MAX_NUMBER => MAX_NUMBER_FOR_VARIABLE_TIMER )
      port map ( clock => clock,
                 timerTriggered => variableTimerTickForTimeSet,
                 reset => resetButtonSignal);

   -- ~400 Hz square used as the buzzer tone source.
   square400Hz : entity work.Timer(behaviorTimer)
      generic map ( MAX_NUMBER => MAX_NUMBER_FOR_BUZZER_TIMER,
                    TRIGGER_DURATION => TRIGGER_DURATION_FOR_BUZZER_TIMER )
      port map ( clock => clock,
                 timerTriggered => squareWaveForBuzzer,
                 reset => resetButtonSignal);

 ------------------------------------------------------------------
 -- counter for for multiplexer (4 digits, one increment every 2ms)
   counterForMux : entity work.CounterTimer(behaviorCounterTimer)
    generic map (MAX_NUMBER_FOR_TIMER => MAX_NUMBER_FOR_MUX_TIMER,
                 MAX_NUMBER_FOR_COUNTER => 3)
    port map ( clock => clock,
               counter => muxCounterFull);
   enabledDigit <= muxCounterFull(1 downto 0);

 -- Main-clock digit cascade.
   digitSecsUnit : entity work.mod_counter(behaviorModCounter)
    generic map (MAX_NUMBER => 9)
    port map (
      clock => mainClockForClock,
      direction => directionForMainClock,
      currentNumber => bcdDigits(3 downto 0),
      carryBit => carryBitSecondsUnit,
      reset => resetButtonSignal);

   digitSecsTens : entity work.mod_counter(behaviorModCounter)
    generic map (MAX_NUMBER => 5)
    port map (
      clock => carryBitSecondsUnit,
      direction => directionForMainClock,
      currentNumber => bcdDigits(7 downto 4),
      carryBit => carryBitSecondsTens,
      reset => resetButtonSignal);

   digitMinsUnit : entity work.mod_counter(behaviorModCounter)
    generic map (MAX_NUMBER => 9)
    port map (
      clock => carryBitSecondsTens,
      direction => directionForMainClock,
      currentNumber => bcdDigits(11 downto 8),
      carryBit => carryBitMinutesUnit,
      reset => resetButtonSignal);

   digitMinsTens : entity work.mod_counter(behaviorModCounter)
    generic map (MAX_NUMBER => 5)
    port map (
      clock => carryBitMinutesUnit,
      direction => directionForMainClock,
      currentNumber => bcdDigits(15 downto 12),
      carryBit => carryBitMinutesTens,
      reset => resetButtonSignal);

   digitHoursUnit : entity work.mod_counter(behaviorModCounter)
    generic map (MAX_NUMBER => 3)
    port map (
      clock => carryBitMinutesTens,
      direction => directionForMainClock,
      currentNumber => bcdDigits(19 downto 16),
      carryBit => carryBitHoursUnit,
      reset => resetButtonSignal);

   digitHoursTens : entity work.mod_counter(behaviorModCounter)
    generic map (MAX_NUMBER => 2)
    port map (
      clock => carryBitHoursUnit,
      direction => directionForMainClock,
      currentNumber => bcdDigits(23 downto 20),
      reset => resetButtonSignal);

 -- Alarm-clock digit cascade (same shape, fed from clockForAlarmSet).
   alarmDigitSecsUnit : entity work.mod_counter(behaviorModCounter)
    generic map (MAX_NUMBER => 9)
    port map (
      clock => clockForAlarmSet,
      direction => directionForAlarmClock,
      currentNumber => alarmBcdDigits(3 downto 0),
      carryBit => alarmCarryBitSecondsUnit,
      reset => resetButtonSignal);

   alarmDigitSecsTens : entity work.mod_counter(behaviorModCounter)
    generic map (MAX_NUMBER => 5)
    port map (
      clock => alarmCarryBitSecondsUnit,
      direction => directionForAlarmClock,
      currentNumber => alarmBcdDigits(7 downto 4),
      carryBit => alarmCarryBitSecondsTens,
      reset => resetButtonSignal);

   alarmDigitMinsUnit : entity work.mod_counter(behaviorModCounter)
    generic map (MAX_NUMBER => 9)
    port map (
      clock => alarmCarryBitSecondsTens,
      direction => directionForAlarmClock,
      currentNumber => alarmBcdDigits(11 downto 8),
      carryBit => alarmCarryBitMinutesUnit,
      reset => resetButtonSignal);

   alarmDigitMinsTens : entity work.mod_counter(behaviorModCounter)
    generic map (MAX_NUMBER => 5)
    port map (
      clock => alarmCarryBitMinutesUnit,
      direction => directionForAlarmClock,
      currentNumber => alarmBcdDigits(15 downto 12),
      carryBit => alarmCarryBitMinutesTens,
      reset => resetButtonSignal);

   alarmDigitHoursUnit : entity work.mod_counter(behaviorModCounter)
    generic map (MAX_NUMBER => 3)
    port map (
      clock => alarmCarryBitMinutesTens,
      direction => directionForAlarmClock,
      currentNumber => alarmBcdDigits(19 downto 16),
      carryBit => alarmCarryBitHoursUnit,
      reset => resetButtonSignal);

   alarmDigitHoursTens : entity work.mod_counter(behaviorModCounter)
    generic map (MAX_NUMBER => 2)
    port map (
      clock => alarmCarryBitHoursUnit,
      direction => directionForAlarmClock,
      currentNumber => alarmBcdDigits(23 downto 20),
      reset => resetButtonSignal);

   -- Alarm comparator + buzzer gating, inlined.
   --
   -- Compare bits 23..4 (everything above seconds-units) so a single
   -- match holds for ~10 simulated seconds before the units roll
   -- over; AND the ~400 Hz tone with the 1 Hz square so the alarm
   -- beeps once per second instead of holding a continuous tone.
   alarmMatch <= '1' when alarmBcdDigits(23 downto 4) = bcdDigits(23 downto 4)
                 else '0';
   buzzer     <= alarmMatch and squareWaveForBuzzer and oneSecondPeriodSquare;

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

   -- MUX to generate anode activating signals for 4 LEDs.
   -- Pre-shift bcdDigitsDisplayed into a signal so the slice on the
   -- right-hand side is a plain object reference, not a slice of a
   -- type-conversion (which VHDL-08 rejects).
   shiftedBcdDigits <= std_logic_vector(
                          unsigned(bcdDigitsDisplayed)
                          srl ((to_integer(unsigned(enabledDigit))
                                + (ClockMode'pos(currentClockMode) * 2)) * 4));

   process(enabledDigit, shiftedBcdDigits)
      constant nibbleToShift: std_logic_vector(3 downto 0) := "0001";
   begin
      cableSelect <= not std_logic_vector(unsigned(nibbleToShift) sll to_integer(unsigned(enabledDigit)));
      currentDigitValue <= shiftedBcdDigits(3 downto 0);
   end process;

   -- BCD to 7 segments. The dot bit is dotBlinkingSignal (gated by
   -- cableSelect(2) so only the middle digit's dot lights), XOR-inverted
   -- in alarm view as a visual cue that ALARM is selected.
   sevenSegments <= ((dotBlinkingSignal or cableSelect(2)) xor selectedClockBit) & "1000000" when currentDigitValue = "0000" else
                    ((dotBlinkingSignal or cableSelect(2)) xor selectedClockBit) & "1111001" when currentDigitValue =  "0001" else
                    ((dotBlinkingSignal or cableSelect(2)) xor selectedClockBit) & "0100100" when currentDigitValue =  "0010" else
                    ((dotBlinkingSignal or cableSelect(2)) xor selectedClockBit) & "0110000" when currentDigitValue =  "0011" else
                    ((dotBlinkingSignal or cableSelect(2)) xor selectedClockBit) & "0011001" when currentDigitValue =  "0100" else
                    ((dotBlinkingSignal or cableSelect(2)) xor selectedClockBit) & "0010010" when currentDigitValue =  "0101" else
                    ((dotBlinkingSignal or cableSelect(2)) xor selectedClockBit) & "0000010" when currentDigitValue =  "0110" else
                    ((dotBlinkingSignal or cableSelect(2)) xor selectedClockBit) & "1111000" when currentDigitValue =  "0111" else
                    ((dotBlinkingSignal or cableSelect(2)) xor selectedClockBit) & "0000000" when currentDigitValue =  "1000" else
                    ((dotBlinkingSignal or cableSelect(2)) xor selectedClockBit) & "0010000" when currentDigitValue =  "1001" else
                    ((dotBlinkingSignal or cableSelect(2)) xor selectedClockBit) & "0001000" when currentDigitValue =  "1010" else
                    ((dotBlinkingSignal or cableSelect(2)) xor selectedClockBit) & "0000011" when currentDigitValue =  "1011" else
                    ((dotBlinkingSignal or cableSelect(2)) xor selectedClockBit) & "1000110" when currentDigitValue =  "1100" else
                    ((dotBlinkingSignal or cableSelect(2)) xor selectedClockBit) & "0100001" when currentDigitValue =  "1101" else
                    ((dotBlinkingSignal or cableSelect(2)) xor selectedClockBit) & "0000110" when currentDigitValue =  "1110" else
                    ((dotBlinkingSignal or cableSelect(2)) xor selectedClockBit) & "0001110";
end behavior;
