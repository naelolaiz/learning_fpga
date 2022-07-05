LIBRARY ieee;

USE ieee.std_logic_1164.ALL;
use ieee.numeric_std.ALL;

---------------
-- Digit entity
entity Digit is
   generic (MAX_NUMBER: integer range 0 to 9 := 9);
   port (clockForIncrement : in std_logic := '0';
         currentNumber : out std_logic_vector (3 downto 0) := "0000";
         carryBit : out std_logic := '0');
end Digit;
architecture behaviorDigit of Digit is
   signal currentNumberSignal : integer range 0 to MAX_NUMBER := 0;
begin
    increment: process(clockForIncrement)
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
    end process;
    currentNumber <= std_logic_vector(to_unsigned(currentNumberSignal, 4));
end behaviorDigit;

---------------
-- Clock entity
LIBRARY ieee;

USE ieee.std_logic_1164.ALL;
use ieee.numeric_std.ALL;

entity Clock is
   generic (MAX_NUMBER: integer := 50000000);
   port (clock: in std_logic := '0';
	      reset: in std_logic := '0';
	      timerTriggered : out std_logic := '0');
end Clock;

architecture behaviorClock of Clock is
begin
   timerClock: process(clock, reset)
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
end behaviorClock;


----------------
-- CounterClock entity
LIBRARY ieee;
use ieee.std_logic_1164.ALL;
use ieee.numeric_std.ALL;

entity CounterClock is
   generic (MAX_NUMBER: integer := 50000000);
   port (clock: in std_logic := '0';
	      reset: in std_logic := '0';
	      timerTriggered : out std_logic := '0';
			counter : out std_logic_vector (63 downto 0):= "0000000000000000000000000000000000000000000000000000000000000000");
end CounterClock;

architecture behaviorCounterClock of CounterClock is
   signal clockTick : std_logic := '0';
   variable counterValue : std_logic_vector (63 downto 0) := "0000000000000000000000000000000000000000000000000000000000000000";
begin
   clock1Sec : entity work.Clock(behaviorClock)
	   generic map ( MAX_NUMBER => MAX_NUMBER ) -- before it was 49999999. It was copied from examples. TODO: Check why!
		port map    ( clock => clock,
		              timerTriggered => clockTick,
					     reset => reset );
   counterProcess : process(clockTick)
   begin
      if clockTick'event and clockTick = '1' then
         if counterValue = std_logic_vector(to_unsigned(MAX_NUMBER, counterValue'length)) then
            counterValue := "0000000000000000000000000000000000000000000000000000000000000000";
         else
            counterValue := std_logic_vector(to_unsigned(to_integer(unsigned(counterValue))+1, 64));
			end if;
      end if;
   end process;
	resetProcess: process(reset)
	begin
		if reset'event and reset = '1' then
		    counterValue := "0000000000000000000000000000000000000000000000000000000000000000";
		end if;
	end process;
	timerTriggered <= clockTick;
end behaviorCounterClock;
---------------
-- top level entiry


LIBRARY ieee;

USE ieee.std_logic_1164.ALL;
use ieee.numeric_std.ALL;

entity top_level_7segments_clock is
   port (
         clock : in std_logic;
         inputButtons : in std_logic_vector(3 downto 0);
         sevenSegments : out std_logic_vector(6 downto 0);
         cableSelect : out std_logic_vector(3 downto 0));
end top_level_7segments_clock;

architecture behavior of top_level_7segments_clock is
signal bcdDigits: std_logic_vector (23 downto 0);
signal enabledDigit: integer range 0 to 3:= 0;
signal currentDigitValue: std_logic_vector (3 downto 0);

signal carryBitSecondsUnit, carryBitSecondsTens, carryBitMinutesUnit, carryBitMinutesTens, carryBitHoursUnit: std_logic := '0';
signal clockTick1Sec: std_logic := '0';

type ClockMode is (MMSS,HHMM);
signal currentClockMode : ClockMode := MMSS;

begin
   clock1Sec : entity work.Clock(behaviorClock)
	   generic map ( MAX_NUMBER => 50000000 ) -- before it was 49999999. It was copied from examples. TODO: Check why!
		port map ( clock => clock,
		           timerTriggered => clockTick1Sec );
					  
   digitSecsUnit : entity work.Digit(behaviorDigit)
    generic map (MAX_NUMBER => 9)
    port map (
      clockForIncrement => clockTick1Sec,
      currentNumber => bcdDigits(3 downto 0),
      carryBit => carryBitSecondsUnit);

		digitSecsTens : entity work.Digit(behaviorDigit)
    generic map (MAX_NUMBER => 5)
    port map (
      clockForIncrement => carryBitSecondsUnit,
      currentNumber => bcdDigits(7 downto 4),
      carryBit => carryBitSecondsTens); 
      
   digitMinsUnit : entity work.Digit(behaviorDigit)
    generic map (MAX_NUMBER => 9)
    port map (
      clockForIncrement => carryBitSecondsTens,
      currentNumber => bcdDigits(11 downto 8),
      carryBit => carryBitMinutesUnit); 
      
   digitMinsTens : entity work.Digit(behaviorDigit)
    generic map (MAX_NUMBER => 5)
    port map (
      clockForIncrement => carryBitMinutesUnit,
      currentNumber => bcdDigits(15 downto 12),
      carryBit => carryBitMinutesTens); 
 
   digitHoursUnit : entity work.Digit(behaviorDigit)
    generic map (MAX_NUMBER => 3)
    port map (
      clockForIncrement => carryBitMinutesTens,
      currentNumber => bcdDigits(19 downto 16),
      carryBit => carryBitHoursUnit); 
      
   digitHoursTens : entity work.Digit(behaviorDigit)
    generic map (MAX_NUMBER => 2)
    port map (
      clockForIncrement => carryBitHoursUnit,
      currentNumber => bcdDigits(23 downto 20));       
      
      
   mainClock: process(clock)
   variable counterForMux: integer range 0 to 100000 := 0; -- tick every 100E3 / 50E6 = 2ms
   begin
      if clock'event and clock = '1' then

         if counterForMux = counterForMux'HIGH-1 then
            counterForMux := 0;
            if enabledDigit = enabledDigit'HIGH then
               enabledDigit <= 0;
            else
               enabledDigit <= enabledDigit + 1;
            end if;
         else
            counterForMux := counterForMux + 1;
         end if;
      end if;
   end process;
	
	-- TODO: implement debounce
	buttonHandler: process(inputButtons)
	begin
	   if inputButtons(0)'event and inputButtons(0) = '0' then
		   -- currentClockMode is toggled with button 0
		   ----unsigned'('0' & inputButtons(0));  see https://stackoverflow.com/questions/63278766/convert-std-logic-vector-to-enum-type-in-vhdl
			-- and https://stackoverflow.com/questions/34039510/std-logic-to-integer-conversion
			currentClockMode <= ClockMode'val(to_integer(unsigned(not std_logic_vector(to_unsigned(ClockMode'pos(currentClockMode),1)))));
		end if;
	end process;
   
   -- MUX to generate anode activating signals for 4 LEDs 
   process(enabledDigit)
      constant nibbleToShift: std_logic_vector(3 downto 0) := "0001";
   begin
      cableSelect <= not std_logic_vector(unsigned(nibbleToShift) sll enabledDigit);
      currentDigitValue <= std_logic_vector(unsigned(bcdDigits) srl ((enabledDigit + (ClockMode'pos(currentClockMode) * 2))*4)) (3 downto 0);
   end process;

   sevenSegments <= "1000000" when currentDigitValue = "0000" else
      "1111001" when currentDigitValue =  "0001" else
      "0100100" when currentDigitValue =  "0010" else
      "0110000" when currentDigitValue =  "0011" else
      "0011001" when currentDigitValue =  "0100" else
      "0010010" when currentDigitValue =  "0101" else
      "0000010" when currentDigitValue =  "0110" else
      "1111000" when currentDigitValue =  "0111" else
      "0000000" when currentDigitValue =  "1000" else
      "0010000" when currentDigitValue =  "1001" else
      "0001000" when currentDigitValue =  "1010" else
      "0000011" when currentDigitValue =  "1011" else
      "1000110" when currentDigitValue =  "1100" else
      "0100001" when currentDigitValue =  "1101" else
      "0000110" when currentDigitValue =  "1110" else
      "0001110" ;
end behavior;
