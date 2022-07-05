LIBRARY ieee;

USE ieee.std_logic_1164.ALL;
use ieee.numeric_std.ALL;

entity digit is
   generic (MAX_NUMBER: integer range 0 to 9 := 9);
   port (clockForIncrement : in std_logic := '0';
         currentNumber : out std_logic_vector (3 downto 0) := "0000";
         carryBit : out std_logic := '0');
end digit;
architecture behaviorDigit of digit is
   signal currentNumberSignal : integer range 0 to MAX_NUMBER := 0;
begin
    clock: process(clockForIncrement)
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

----------------

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
signal counterForCounter: integer range 0 to 50000000 := 0; -- tick every second
signal counterForMux: integer range 0 to 100000 := 0; -- ticks every 100E3 / 50E6 = 2ms

signal bcdDigits: std_logic_vector (23 downto 0);
signal enabledDigit: integer range 0 to 3:= 0;
signal currentDigitValue: std_logic_vector (3 downto 0);

signal mainClockForDigits: std_logic := '0';

signal carryBitSecondsUnit, carryBitSecondsTens, carryBitMinutesUnit, carryBitMinutesTens, carryBitHoursUnit: std_logic := '0';

begin


   digitSecsUnit : entity work.digit(behaviorDigit)
    generic map (MAX_NUMBER => 9)
    port map (
      clockForIncrement => mainClockForDigits,
      currentNumber => bcdDigits(3 downto 0),
      carryBit => carryBitSecondsUnit);
      
   digitSecsTens : entity work.digit(behaviorDigit)
    generic map (MAX_NUMBER => 5)
    port map (
      clockForIncrement => carryBitSecondsUnit,
      currentNumber => bcdDigits(7 downto 4),
      carryBit => carryBitSecondsTens); 
      
   digitMinsUnit : entity work.digit(behaviorDigit)
    generic map (MAX_NUMBER => 9)
    port map (
      clockForIncrement => carryBitSecondsTens,
      currentNumber => bcdDigits(11 downto 8),
      carryBit => carryBitMinutesUnit); 
      
   digitMinsTens : entity work.digit(behaviorDigit)
    generic map (MAX_NUMBER => 5)
    port map (
      clockForIncrement => carryBitMinutesUnit,
      currentNumber => bcdDigits(15 downto 12),
      carryBit => carryBitMinutesTens); 
 
   digitHoursUnit : entity work.digit(behaviorDigit)
    generic map (MAX_NUMBER => 4)
    port map (
      clockForIncrement => carryBitMinutesTens,
      currentNumber => bcdDigits(19 downto 16),
      carryBit => carryBitHoursUnit); 
      
   digitHoursTens : entity work.digit(behaviorDigit)
    generic map (MAX_NUMBER => 2)
    port map (
      clockForIncrement => carryBitHoursUnit,
      currentNumber => bcdDigits(23 downto 20));       
      
      
   counter: process(clock)
   begin
      if clock'event and clock = '1' then

         if counterForMux = counterForMux'HIGH-1 then
            counterForMux <= 0;
            if enabledDigit = enabledDigit'HIGH then
               enabledDigit <= 0;
            else
               enabledDigit <= enabledDigit + 1;
            end if;
         else
            counterForMux <= counterForMux + 1;
         end if;
         
         if counterForCounter = counterForCounter'HIGH-1 then
            counterForCounter <= 0;
            mainClockForDigits <= '1';
         else
            mainClockForDigits <= '0';
            counterForCounter <= counterForCounter + 1;
         end if;
      end if;
   end process;
   
   -- MUX to generate anode activating signals for 4 LEDs 
   process(enabledDigit)
   constant nibbleToShift: std_logic_vector(3 downto 0) := "0001";
   begin
       cableSelect <= not std_logic_vector(unsigned(nibbleToShift) sll enabledDigit);
       currentDigitValue <= std_logic_vector(unsigned(bcdDigits) srl (enabledDigit*4)) (3 downto 0);
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
