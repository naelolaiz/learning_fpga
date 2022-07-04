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
signal counterForDelay  : integer range 0 to 15000000 := 0; -- ticks every 10E6 / 50E6 = 200ms 
--signal counterToDisplay : integer range 0 to 9 := 0; -- TODO: multiplex cableSelectDigits -- 0xFFFF := 0;
signal counterToDisplay: STD_LOGIC_VECTOR (15 downto 0);

signal enabledDigit: std_logic_vector (3 downto 0) := "0001";
--signal enabledDigit : integer range 0 to 4;
signal counterForMultiplexer : integer range 0 to 100000 := 0;
signal LED_BCD: STD_LOGIC_VECTOR (3 downto 0);

begin
   counter : process(clock)
   begin
      if clock'event and clock = '1' then
         --refreshC
         if counterForMultiplexer = 99999 then
            counterForMultiplexer <= 0;
            enabledDigit <= std_logic_vector(unsigned(enabledDigit) rol 1);
         else
            counterForMultiplexer <= counterforMultiplexer + 1;
         end if;
         if counterForDelay = 14999999 then
            counterForDelay <= 0;
            counterToDisplay <= std_logic_vector(unsigned(counterToDisplay) + 1);
         else
            counterForDelay <= counterForDelay + 1;
         end if;
      end if;

   end process;
   
   -- MUX to generate anode activating signals for 4 LEDs 
   process(enabledDigit)
   begin
       cableSelect <= not enabledDigit;
       if enabledDigit = "0001" then
           LED_BCD <= counterToDisplay(3 downto 0);
       elsif enabledDigit = "0010" then
           LED_BCD <= counterToDisplay(7 downto 4);
       elsif enabledDigit = "0100" then
           LED_BCD <= counterToDisplay(11 downto 8);
       else
           LED_BCD <= counterToDisplay(15 downto 12);
       end if;
   end process;

   sevenSegments <= "1000000" when LED_BCD = "0000" else
        "1111001" when LED_BCD =  "0001" else
        "0100100" when LED_BCD =  "0010" else
        "0110000" when LED_BCD =  "0011" else
        "0011001" when LED_BCD =  "0100" else
        "0010010" when LED_BCD =  "0101" else
        "0000010" when LED_BCD =  "0110" else
        "1111000" when LED_BCD =  "0111" else
        "0000000" when LED_BCD =  "1000" else
        "0010000" when LED_BCD =  "1001" else
        "0001000" when LED_BCD =  "1010" else
        "0000011" when LED_BCD =  "1011" else
        "1000110" when LED_BCD =  "1100" else
        "0100001" when LED_BCD =  "1101" else
        "0000110" when LED_BCD =  "1110" else
        "0001110" ;
end behavior;
