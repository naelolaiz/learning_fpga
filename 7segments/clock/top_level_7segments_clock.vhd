------------------------------
-- top level entitry for clock

LIBRARY ieee;

USE ieee.std_logic_1164.ALL;
use ieee.numeric_std.ALL;

entity top_level_7segments_clock is
   port (
         clock50MHz: in std_logic;
         resetButton: in std_logic := '1';
         inputButtons : in std_logic_vector(3 downto 0);
         sevenSegments : out std_logic_vector(7 downto 0);
         cableSelect : buffer std_logic_vector(3 downto 0);
         buzzer : out std_logic := '1');
end top_level_7segments_clock;

architecture behavior of top_level_7segments_clock is
signal bcdDigitsMainClock, bcdDigitsDisplayed: std_logic_vector (23 downto 0) := std_logic_vector(to_unsigned(0,24));
signal enabledDigit: std_logic_vector (1 downto 0) := "00";
signal currentDigitValue: std_logic_vector (3 downto 0) := "0000";

--signal carryBitSecondsUnit, carryBitSecondsTens, carryBitMinutesUnit, carryBitMinutesTens, carryBitHoursUnit: std_logic := '0';
signal variableTimerTickForTimeSet: std_logic := '0';
signal timerTick00015Sec: std_logic := '0';
signal clockForMainClock: std_logic := '0';
signal oneSecondPeriodSquare: std_logic := '0';

type ClockMode is (MMSS,HHMM);
signal currentClockMode : ClockMode := MMSS;
signal buttonClockModeDebounced : std_logic := '0';
signal resetButtonSignal : std_logic := '0';
signal dotBlinkingSignal: std_logic := '0';

-- debouncing buttons signals
signal increaseTimeButtonDebounced : std_logic := '1';
signal decreaseTimeButtonDebounced : std_logic := '1';

-- alarm
signal clockForAlarmSet : std_logic := '0';
signal alarmBcdDigits : std_logic_vector (23 downto 0) := std_logic_vector(to_unsigned(0,24));
signal squareWaveForBuzzer : std_logic := '1';
type SelectedClock is (MAIN_CLOCK, ALARM_CLOCK);
signal currentSelectedClock : SelectedClock := MAIN_CLOCK;
signal buttonSelectedClockDebounced : std_logic := '1';

signal directionForMainClock : std_logic := '1';
signal directionForAlarmClock : std_logic := '1';


begin
resetButtonSignal <= not resetButton;
clockForMainClock <= oneSecondPeriodSquare when ((increaseTimeButtonDebounced = '1' and decreaseTimeButtonDebounced = '1') or currentSelectedClock = ALARM_CLOCK)
                      else variableTimerTickForTimeSet when currentClockMode = MMSS
                      else timerTick00015Sec;

clockForAlarmSet <= '0' when ((increaseTimeButtonDebounced = '1' and decreaseTimeButtonDebounced = '1') or currentSelectedClock = MAIN_CLOCK)
                       else variableTimerTickForTimeSet when currentClockMode = MMSS
                       else timerTick00015Sec;

bcdDigitsDisplayed <= bcdDigitsMainClock when currentSelectedClock = MAIN_CLOCK else alarmBcdDigits;

directionForMainClock  <= '1' when currentSelectedClock = ALARM_CLOCK else decreaseTimeButtonDebounced;
directionForAlarmClock <= '1' when currentSelectedClock = MAIN_CLOCK else decreaseTimeButtonDebounced;

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
      port map ( clock => clock50MHz,
                 timerTriggered => oneSecondPeriodSquare,
                 reset => resetButtonSignal);
                                
   timer00015Sec : entity work.Timer(behaviorTimer)
      generic map ( MAX_NUMBER => 75000 )
      port map ( clock => clock50MHz,
                 timerTriggered => timerTick00015Sec,
                 reset => resetButtonSignal);
   
   variableTimerForTimeSet : entity work.VariableTimer(behaviorVariableTimer)
   generic map ( MAX_NUMBER => 2500000 )
      port map ( clock => clock50MHz,
                 timerTriggered => variableTimerTickForTimeSet,
                 reset => resetButtonSignal);  
                 
                 
 ------------------------------------------------------------------
 -- counter for for multiplexer (4 digits, one increment every 2ms)                
   counterForMux : entity work.CounterTimer(behaviorCounterTimer)
    generic map (MAX_NUMBER_FOR_TIMER => 100000, -- tick every 100E3 / 50E6 = 2ms
                 MAX_NUMBER_FOR_COUNTER => 3)
    port map ( clock => clock50MHz,
               counter (1 downto 0) => enabledDigit);

 -----------------
 -- clock instances
   bcdClock : entity work.Clock(behaviorClock)
    port map (
      clock => clockForMainClock,
      direction => directionForMainClock,
      bcdDigits => bcdDigitsMainClock,
      reset => resetButtonSignal);
      
   alarmBcdClock : entity work.Clock(behaviorClock)
    port map (
      clock => clockForAlarmSet,
      direction => directionForAlarmClock,
      bcdDigits => alarmBcdDigits,
      reset => resetButtonSignal);
		
   square400Hz : entity work.Timer(behaviorTimer)
      generic map ( MAX_NUMBER => 125000, 
                    TRIGGER_DURATION => 62500)
      port map ( clock => clock50MHz,
                 timerTriggered => squareWaveForBuzzer,
                 reset => resetButtonSignal);		
		
buzzer <= squareWaveForBuzzer and oneSecondPeriodSquare when alarmBcdDigits(23 downto 5) = bcdDigitsMainClock(23 downto 5) else 'Z';

-------------------
-- debouncing buttons      
   debounce_clock_mode_switch : entity work.Debounce(RTL)
    port map(
    i_Clk    => clock50MHz,
    i_Switch => inputButtons(0),
    o_Switch => buttonClockModeDebounced
  );

  debounce_view_alarm : entity work.Debounce(RTL)
    port map(
    i_Clk    => clock50MHz,
    i_Switch => inputButtons(1),
    o_Switch => buttonSelectedClockDebounced
  );

  debounce_increase_time_button : entity work.Debounce(RTL)
    port map(
    i_Clk    => clock50MHz,
    i_Switch => inputButtons(2),
    o_Switch => decreaseTimeButtonDebounced
  );
  
  debounce_decrease_time_button : entity work.Debounce(RTL)
    port map(
    i_Clk    => clock50MHz,
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
         -- currentSelectedClock is toggled with button 1
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

   -- BCD to 7 segments
   sevenSegments <= ((dotBlinkingSignal or cableSelect(2)) xor std_logic_vector(to_unsigned(SelectedClock'pos(currentSelectedClock), 1))(0))  & "1000000" when currentDigitValue = "0000" else
                    ((dotBlinkingSignal or cableSelect(2)) xor std_logic_vector(to_unsigned(SelectedClock'pos(currentSelectedClock), 1))(0))  & "1111001" when currentDigitValue =  "0001" else
                    ((dotBlinkingSignal or cableSelect(2)) xor std_logic_vector(to_unsigned(SelectedClock'pos(currentSelectedClock), 1))(0))  & "0100100" when currentDigitValue =  "0010" else
                    ((dotBlinkingSignal or cableSelect(2)) xor std_logic_vector(to_unsigned(SelectedClock'pos(currentSelectedClock), 1))(0))  & "0110000" when currentDigitValue =  "0011" else
                    ((dotBlinkingSignal or cableSelect(2)) xor std_logic_vector(to_unsigned(SelectedClock'pos(currentSelectedClock), 1))(0))  & "0011001" when currentDigitValue =  "0100" else
                    ((dotBlinkingSignal or cableSelect(2)) xor std_logic_vector(to_unsigned(SelectedClock'pos(currentSelectedClock), 1))(0))  & "0010010" when currentDigitValue =  "0101" else
                    ((dotBlinkingSignal or cableSelect(2)) xor std_logic_vector(to_unsigned(SelectedClock'pos(currentSelectedClock), 1))(0))  & "0000010" when currentDigitValue =  "0110" else
                    ((dotBlinkingSignal or cableSelect(2)) xor std_logic_vector(to_unsigned(SelectedClock'pos(currentSelectedClock), 1))(0))  & "1111000" when currentDigitValue =  "0111" else
                    ((dotBlinkingSignal or cableSelect(2)) xor std_logic_vector(to_unsigned(SelectedClock'pos(currentSelectedClock), 1))(0))  & "0000000" when currentDigitValue =  "1000" else
                    ((dotBlinkingSignal or cableSelect(2)) xor std_logic_vector(to_unsigned(SelectedClock'pos(currentSelectedClock), 1))(0))  & "0010000" when currentDigitValue =  "1001" else
                    ((dotBlinkingSignal or cableSelect(2)) xor std_logic_vector(to_unsigned(SelectedClock'pos(currentSelectedClock), 1))(0))  & "0001000" when currentDigitValue =  "1010" else
                    ((dotBlinkingSignal or cableSelect(2)) xor std_logic_vector(to_unsigned(SelectedClock'pos(currentSelectedClock), 1))(0))  & "0000011" when currentDigitValue =  "1011" else
                    ((dotBlinkingSignal or cableSelect(2)) xor std_logic_vector(to_unsigned(SelectedClock'pos(currentSelectedClock), 1))(0))  & "1000110" when currentDigitValue =  "1100" else
                    ((dotBlinkingSignal or cableSelect(2)) xor std_logic_vector(to_unsigned(SelectedClock'pos(currentSelectedClock), 1))(0))  & "0100001" when currentDigitValue =  "1101" else
                    ((dotBlinkingSignal or cableSelect(2)) xor std_logic_vector(to_unsigned(SelectedClock'pos(currentSelectedClock), 1))(0))  & "0000110" when currentDigitValue =  "1110" else
                    ((dotBlinkingSignal or cableSelect(2)) xor std_logic_vector(to_unsigned(SelectedClock'pos(currentSelectedClock), 1))(0))  & "0001110";
end behavior;
