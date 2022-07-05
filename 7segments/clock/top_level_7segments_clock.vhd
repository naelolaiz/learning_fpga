LIBRARY ieee;

USE ieee.std_logic_1164.ALL;
use ieee.numeric_std.ALL;

---------------
-- Digit entity
entity Digit is
   generic (MAX_NUMBER: integer range 0 to 9 := 9);
   port (clockForIncrement : in std_logic := '0';
	      reset : in std_logic := '0';
         currentNumber : out std_logic_vector (3 downto 0) := "0000";
         carryBit : out std_logic := '0');
end Digit;
architecture behaviorDigit of Digit is
   signal currentNumberSignal : integer range 0 to MAX_NUMBER := 0;
begin
    increment: process(clockForIncrement, reset)
    begin
       if clockForIncrement'event and clockForIncrement = '1' then
          if currentNumberSignal = MAX_NUMBER then
             currentNumberSignal <= 0;
             carryBit <= '1';
          else
             currentNumberSignal <= currentNumberSignal + 1;
             carryBit <= '0';
          end if;
       end if;
		 if reset = '1' then
		    currentNumberSignal <= 0;
		 end if;
    end process;
    currentNumber <= std_logic_vector(to_unsigned(currentNumberSignal, 4));
end behaviorDigit;

---------------
-- Timer entity
LIBRARY ieee;

USE ieee.std_logic_1164.ALL;
use ieee.numeric_std.ALL;

entity Timer is
   generic (MAX_NUMBER: integer := 50000000);
   port (clock: in std_logic := '0';
         reset: in std_logic := '0';
         timerTriggered : out std_logic := '0');
end Timer;

architecture behaviorTimer of Timer is
begin
   timerTimer: process(clock, reset)
   variable counterForTriggerOut: integer range 0 to MAX_NUMBER := 0;
   begin
      if clock'event and clock = '1' then
         if reset = '1' then
             counterForTriggerOut := 0;
         end if;

         if counterForTriggerOut = MAX_NUMBER then
            counterForTriggerOut := 0;
            timerTriggered <= '1';
         else
            counterForTriggerOut := counterForTriggerOut + 1;
            timerTriggered <= '0';
         end if;
      end if;
   end process;
end behaviorTimer;


----------------
-- CounterTimer entity
LIBRARY ieee;
use ieee.std_logic_1164.ALL;
use ieee.numeric_std.ALL;

entity CounterTimer is
   generic (MAX_NUMBER_FOR_TIMER: integer := 50000000;
            MAX_NUMBER_FOR_COUNTER: integer := 10);
   port (clock: in std_logic := '0';
         reset: in std_logic := '0';
         timerTriggered : out std_logic := '0';
         counter : out std_logic_vector (63 downto 0):= std_logic_vector(to_unsigned(0,64)));
end CounterTimer;

architecture behaviorCounterTimer of CounterTimer is
   signal timerTick : std_logic := '0';
   signal counterValue : std_logic_vector (63 downto 0) := std_logic_vector(to_unsigned(0,64));
begin
   Timer : entity work.Timer(behaviorTimer)
      generic map ( MAX_NUMBER => MAX_NUMBER_FOR_TIMER )
      port map    ( clock => clock,
                    timerTriggered => timerTick,
                    reset => reset );
   counterProcess : process(timerTick, reset)
   begin
      if timerTick'event and timerTick = '1' then
         if counterValue = std_logic_vector(to_unsigned(MAX_NUMBER_FOR_COUNTER, counterValue'length)) then
            counterValue <= std_logic_vector(to_unsigned(0,64));
         else
            counterValue <= std_logic_vector(to_unsigned(to_integer(unsigned(counterValue))+1, counterValue'length));
         end if;
      end if;
      if reset = '1' then
          counterValue <= std_logic_vector(to_unsigned(0,64));
      end if;
   end process;
   timerTriggered <= TimerTick;
   counter <= counterValue;
end behaviorCounterTimer;
---------------
-- top level entiry


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

type ClockMode is (MMSS,HHMM);
signal currentClockMode : ClockMode := MMSS;
signal buttonClockModeDebounced : std_logic := '0';
signal resetButtonSignal : std_logic := '0';

begin
resetButtonSignal <= not resetButton;
 --------------------------------
 -- timer to get ticks every 1 sec
   timer1Sec : entity work.Timer(behaviorTimer)
      generic map ( MAX_NUMBER => 50000000 ) -- before it was 49999999. It was copied from examples. TODO: Check why!
      port map ( clock => clock,
                 timerTriggered => timerTick1Sec,
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
      clockForIncrement => timerTick1Sec,
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
  
--  debounce_clock_mode_switch : entity work.Debounce(RTL)
--    port map(
--    i_Clk    => clock,
--    i_Switch => inputButtons(0),
--    o_Switch => buttonClockModeDebounced
--  );


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
