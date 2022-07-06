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
         cableSelect : out std_logic_vector(3 downto 0));
end top_level_7segments_clock;

architecture behavior of top_level_7segments_clock is
signal bcdDigits: std_logic_vector (23 downto 0) := std_logic_vector(to_unsigned(0,24));
signal enabledDigit: std_logic_vector (1 downto 0) := "00";
signal currentDigitValue: std_logic_vector (3 downto 0) := "0000";

signal carryBitSecondsUnit, carryBitSecondsTens, carryBitMinutesUnit, carryBitMinutesTens, carryBitHoursUnit: std_logic := '0';
signal timerTick1Sec: std_logic := '0';
signal timerTick005Sec: std_logic := '0';
signal timerTick00015Sec: std_logic := '0';
signal mainClockForClock: std_logic := '0';

type ClockMode is (MMSS,HHMM);
signal currentClockMode : ClockMode := MMSS;
signal buttonClockModeDebounced : std_logic := '0';
signal resetButtonSignal : std_logic := '0';

signal increaseTimeButtonDebounced : std_logic := '1';

begin
resetButtonSignal <= not resetButton;
mainClockForClock <= timerTick1Sec when increaseTimeButtonDebounced = '1' else timerTick005Sec when currentClockMode = MMSS else timerTick00015Sec;

 --------------------------------
 -- timer to get ticks every 1 sec
   timer1Sec : entity work.Timer(behaviorTimer)
      generic map ( MAX_NUMBER => 50000000 ) -- before it was 49999999. It was copied from examples. TODO: Check why!
      port map ( clock => clock,
                 timerTriggered => timerTick1Sec,
					  reset => resetButtonSignal);
					  
   timer005Sec : entity work.Timer(behaviorTimer)
      generic map ( MAX_NUMBER => 2500000 )
      port map ( clock => clock,
                 timerTriggered => timerTick005Sec,
					  reset => resetButtonSignal);					  
	timer00015Sec : entity work.Timer(behaviorTimer)
      generic map ( MAX_NUMBER => 75000 )
      port map ( clock => clock,
                 timerTriggered => timerTick00015Sec,
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
      clockForIncrement => mainClockForClock,
      currentNumber => bcdDigits(3 downto 0),
      carryBit => carryBitSecondsUnit,
      reset => resetButtonSignal);

      digitSecsTens : entity work.Digit(behaviorDigit)
    generic map (MAX_NUMBER => 5)
    port map (
      clockForIncrement => carryBitSecondsUnit,
      currentNumber => bcdDigits(7 downto 4),
      carryBit => carryBitSecondsTens,
      reset => resetButtonSignal); 
      
   digitMinsUnit : entity work.Digit(behaviorDigit)
    generic map (MAX_NUMBER => 9)
    port map (
      clockForIncrement => carryBitSecondsTens,
      currentNumber => bcdDigits(11 downto 8),
      carryBit => carryBitMinutesUnit,
      reset => resetButtonSignal); 
      
   digitMinsTens : entity work.Digit(behaviorDigit)
    generic map (MAX_NUMBER => 5)
    port map (
      clockForIncrement => carryBitMinutesUnit,
      currentNumber => bcdDigits(15 downto 12),
      carryBit => carryBitMinutesTens,
      reset => resetButtonSignal); 
 
   digitHoursUnit : entity work.Digit(behaviorDigit)
    generic map (MAX_NUMBER => 3)
    port map (
      clockForIncrement => carryBitMinutesTens,
      currentNumber => bcdDigits(19 downto 16),
      carryBit => carryBitHoursUnit,
      reset => resetButtonSignal); 
      
   digitHoursTens : entity work.Digit(behaviorDigit)
    generic map (MAX_NUMBER => 2)
    port map (
      clockForIncrement => carryBitHoursUnit,
      currentNumber => bcdDigits(23 downto 20),
      reset => resetButtonSignal);
  -- debounce copied from https://github.com/fsmiamoto/EasyFPGA-VGA/blob/master/Debounce.vhd 
  debounce_clock_mode_switch : entity work.Debounce(RTL)
    port map(
    i_Clk    => clock,
    i_Switch => inputButtons(0),
    o_Switch => buttonClockModeDebounced
  );
  
  debounce_increase_time_button : entity work.Debounce(RTL)
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
   sevenSegments <= "11000000" when currentDigitValue = "0000" else
      "11111001" when currentDigitValue =  "0001" else
      "10100100" when currentDigitValue =  "0010" else
      "10110000" when currentDigitValue =  "0011" else
      "10011001" when currentDigitValue =  "0100" else
      "10010010" when currentDigitValue =  "0101" else
      "10000010" when currentDigitValue =  "0110" else
      "11111000" when currentDigitValue =  "0111" else
      "10000000" when currentDigitValue =  "1000" else
      "10010000" when currentDigitValue =  "1001" else
      "10001000" when currentDigitValue =  "1010" else
      "10000011" when currentDigitValue =  "1011" else
      "11000110" when currentDigitValue =  "1100" else
      "10100001" when currentDigitValue =  "1101" else
      "10000110" when currentDigitValue =  "1110" else
      "10001110" ;
end behavior;
