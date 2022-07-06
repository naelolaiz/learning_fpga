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
         cableSelect : buffer std_logic_vector(3 downto 0));
end top_level_7segments_clock;

architecture behavior of top_level_7segments_clock is
signal bcdDigits: std_logic_vector (23 downto 0) := std_logic_vector(to_unsigned(0,24));
signal enabledDigit: std_logic_vector (1 downto 0) := "00";
signal currentDigitValue: std_logic_vector (3 downto 0) := "0000";

signal carryBitSecondsUnit, carryBitSecondsTens, carryBitMinutesUnit, carryBitMinutesTens, carryBitHoursUnit: std_logic := '0';
signal variableTimerTickForTimeSet: std_logic := '0';
signal timerTick00015Sec: std_logic := '0';
signal mainClockForClock: std_logic := '0';
signal oneSecondPeriodSquare: std_logic := '0';

type ClockMode is (MMSS,HHMM);
signal currentClockMode : ClockMode := MMSS;
signal buttonClockModeDebounced : std_logic := '0';
signal resetButtonSignal : std_logic := '0';


signal increaseTimeButtonDebounced : std_logic := '1';
signal decreaseTimeButtonDebounced : std_logic := '1';

begin
resetButtonSignal <= not resetButton;
mainClockForClock <= oneSecondPeriodSquare when (increaseTimeButtonDebounced = '1' and decreaseTimeButtonDebounced = '1')
                      else variableTimerTickForTimeSet when currentClockMode = MMSS
							 else timerTick00015Sec;

 --------------------------------
 -- timer to get ticks every 1 sec
   timer1Sec : entity work.Timer(behaviorTimer)
      generic map ( MAX_NUMBER => 50000000, -- before it was 49999999. It was copied from examples. TODO: Check why!
		              TRIGGER_DURATION => 25000000 ) -- so we can use the 50% duty cycle for blinking the led
      port map ( clock => clock,
                 timerTriggered => oneSecondPeriodSquare,
                 reset => resetButtonSignal);
                 
--   timer005Sec : entity work.Timer(behaviorTimer)
--      generic map ( MAX_NUMBER => 2500000 )
--      port map ( clock => clock,
--                 timerTriggered => variableTimerTickForTimeSet,
--                 reset => resetButtonSignal);  
					  
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
                 
                 
 ------------------------------------------------------------------
 -- counter for for multiplexer (4 digits, one increment every 2ms)                
   counterForMux : entity work.CounterTimer(behaviorCounterTimer)
    generic map (MAX_NUMBER_FOR_TIMER => 100000, -- tick every 100E3 / 50E6 = 2ms
                 MAX_NUMBER_FOR_COUNTER => 3)
    port map ( clock => clock,
               counter (1 downto 0) => enabledDigit);
 -- digit instances ...               
   digitSecsUnit : entity work.Digit(behaviorDigit)
    generic map (MAX_NUMBER => 9)
    port map (
      clock => mainClockForClock,
      direction => decreaseTimeButtonDebounced,
      currentNumber => bcdDigits(3 downto 0),
      carryBit => carryBitSecondsUnit,
      reset => resetButtonSignal);

      digitSecsTens : entity work.Digit(behaviorDigit)
    generic map (MAX_NUMBER => 5)
    port map (
      clock => carryBitSecondsUnit,
      direction => decreaseTimeButtonDebounced,
      currentNumber => bcdDigits(7 downto 4),
      carryBit => carryBitSecondsTens,
      reset => resetButtonSignal); 
      
   digitMinsUnit : entity work.Digit(behaviorDigit)
    generic map (MAX_NUMBER => 9)
    port map (
      clock => carryBitSecondsTens,
      direction => decreaseTimeButtonDebounced,
      currentNumber => bcdDigits(11 downto 8),
      carryBit => carryBitMinutesUnit,
      reset => resetButtonSignal); 
      
   digitMinsTens : entity work.Digit(behaviorDigit)
    generic map (MAX_NUMBER => 5)
    port map (
      clock => carryBitMinutesUnit,
      direction => decreaseTimeButtonDebounced,
      currentNumber => bcdDigits(15 downto 12),
      carryBit => carryBitMinutesTens,
      reset => resetButtonSignal); 
 
   digitHoursUnit : entity work.Digit(behaviorDigit)
    generic map (MAX_NUMBER => 3)
    port map (
      clock => carryBitMinutesTens,
      direction => decreaseTimeButtonDebounced,
      currentNumber => bcdDigits(19 downto 16),
      carryBit => carryBitHoursUnit,
      reset => resetButtonSignal); 
      
   digitHoursTens : entity work.Digit(behaviorDigit)
    generic map (MAX_NUMBER => 2)
    port map (
      clock => carryBitHoursUnit,
      direction => decreaseTimeButtonDebounced,
      currentNumber => bcdDigits(23 downto 20),
      reset => resetButtonSignal);
		
	debounce_clock_mode_switch : entity work.Debounce(RTL)
    port map(
    i_Clk    => clock,
    i_Switch => inputButtons(0),
    o_Switch => buttonClockModeDebounced
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
   buttonHandler: process(buttonClockModeDebounced)
   begin
      if buttonClockModeDebounced'event and buttonClockModeDebounced = '0' then
         -- currentClockMode is toggled with button 0
         ----unsigned'('0' & inputButtons(0));  see https://stackoverflow.com/questions/63278766/convert-std-logic-vector-to-enum-type-in-vhdl
         -- and https://stackoverflow.com/questions/34039510/std-logic-to-integer-conversion
         currentClockMode <= ClockMode'val(to_integer(unsigned(not std_logic_vector(to_unsigned(ClockMode'pos(currentClockMode),1)))));
      end if;
   end process;
   
   -- MUX to generate anode activating signals for 4 LEDs 
   process(enabledDigit, bcdDigits, currentClockMode)
      constant nibbleToShift: std_logic_vector(3 downto 0) := "0001";
   begin
      cableSelect <= not std_logic_vector(unsigned(nibbleToShift) sll to_integer(unsigned(enabledDigit)));
      currentDigitValue <= std_logic_vector(unsigned(bcdDigits) srl ((to_integer(unsigned(enabledDigit)) + (ClockMode'pos(currentClockMode) * 2))*4)) (3 downto 0);
   end process;

   -- BCD to 7 segments
   sevenSegments <= (oneSecondPeriodSquare or cableSelect(2)) & "1000000" when currentDigitValue = "0000" else
                    (oneSecondPeriodSquare or cableSelect(2)) & "1111001" when currentDigitValue =  "0001" else
                    (oneSecondPeriodSquare or cableSelect(2)) & "0100100" when currentDigitValue =  "0010" else
                    (oneSecondPeriodSquare or cableSelect(2)) & "0110000" when currentDigitValue =  "0011" else
                    (oneSecondPeriodSquare or cableSelect(2)) & "0011001" when currentDigitValue =  "0100" else
                    (oneSecondPeriodSquare or cableSelect(2)) & "0010010" when currentDigitValue =  "0101" else
                    (oneSecondPeriodSquare or cableSelect(2)) & "0000010" when currentDigitValue =  "0110" else
                    (oneSecondPeriodSquare or cableSelect(2)) & "1111000" when currentDigitValue =  "0111" else
                    (oneSecondPeriodSquare or cableSelect(2)) & "0000000" when currentDigitValue =  "1000" else
                    (oneSecondPeriodSquare or cableSelect(2)) & "0010000" when currentDigitValue =  "1001" else
                    (oneSecondPeriodSquare or cableSelect(2)) & "0001000" when currentDigitValue =  "1010" else
                    (oneSecondPeriodSquare or cableSelect(2)) & "0000011" when currentDigitValue =  "1011" else
                    (oneSecondPeriodSquare or cableSelect(2)) & "1000110" when currentDigitValue =  "1100" else
                    (oneSecondPeriodSquare or cableSelect(2)) & "0100001" when currentDigitValue =  "1101" else
                    (oneSecondPeriodSquare or cableSelect(2)) & "0000110" when currentDigitValue =  "1110" else
                    (oneSecondPeriodSquare or cableSelect(2)) & "0001110";
end behavior;
