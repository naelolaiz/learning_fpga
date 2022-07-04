LIBRARY ieee;

USE ieee.std_logic_1164.ALL;
use ieee.numeric_std.ALL;

entity test is
   port (
         clock : in std_logic;
         inputButtons : in std_logic_vector(3 downto 0);
         sevenSegments : out std_logic_vector(6 downto 0);
         cableSelect : out std_logic_vector(3 downto 0));
end test;

architecture behavior of test is
signal counterForCounter: integer range 0 to 3125000 := 0; -- ticks every 3.125E6 / 50E6 = 62.5 ms (0.0625*16 = 1, so the second digit increases every second)
signal counterForMux: integer range 0 to 100000 := 0; -- ticks every 100E3 / 50E6 = 2ms

signal numberToDisplay: std_logic_vector (15 downto 0);
signal enabledDigit: integer range 0 to 3:= 0;
signal currentDigitValue: std_logic_vector (3 downto 0);

begin
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
            numberToDisplay <= std_logic_vector(unsigned(numberToDisplay) + 1);
         else
            counterForCounter <= counterForCounter + 1;
         end if;
      end if;
   end process;
   
   -- MUX to generate anode activating signals for 4 LEDs 
   process(enabledDigit)
	constant nibbleToShift: std_logic_vector(3 downto 0) := "0001";
   begin
       cableSelect <= not std_logic_vector(unsigned(nibbleToShift) sll enabledDigit);
		 currentDigitValue <= std_logic_vector(unsigned(numberToDisplay) srl (enabledDigit*4)) (3 downto 0);
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
