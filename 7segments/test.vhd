LIBRARY ieee;

USE ieee.std_logic_1164.ALL;

entity test is
   port (
         clock : in std_logic;
         inputButtons : in std_logic_vector(3 downto 0);
         sevenSegments : out std_logic_vector(6 downto 0);
         cableSelectDigit0 : out std_logic;
         cableSelectDigit1 : out std_logic;
         cableSelectDigit2 : out std_logic;
         cableSelectDigit3 : out std_logic);
end test;

architecture behavior of test is
signal counterForDelay  : integer range 0 to 10000000 := 0; -- ticks every 10E6 / 50E6 = 200ms 
signal counterToDisplay : integer range 0 to 9 := 0; -- TODO: multiplex cableSelectDigits -- 0xFFFF := 0;

begin
   cableSelectDigit0 <= '0';
   cableSelectDigit1 <= '0';
   cableSelectDigit2 <= '0';
   cableSelectDigit3 <= '0';
   
   counter : process(clock)
   begin
      if clock'event and clock = '1' then
         if counterForDelay = 9999999 then
            counterForDelay <= 0;
            counterToDisplay <= counterToDisplay + 1;
         else
            counterForDelay <= counterForDelay + 1;
         end if;
      end if;

   end process;

   sevenSegments <= "1000000" when counterToDisplay = 0 else
        "1111001" when counterToDisplay =  1 else
        "0100100" when counterToDisplay =  2 else
        "0110000" when counterToDisplay =  3 else
        "0011001" when counterToDisplay =  4 else
        "0010010" when counterToDisplay =  5 else
        "0000010" when counterToDisplay =  6 else
        "1111000" when counterToDisplay =  7 else
        "0000000" when counterToDisplay =  8 else
        "0010000" when counterToDisplay =  9 else
        "0001000" when counterToDisplay = 10 else
        "0000011" when counterToDisplay = 11 else
        "1000110" when counterToDisplay = 12 else
        "0100001" when counterToDisplay = 13 else
        "0000110" when counterToDisplay = 14 else
        "0001110" ;
end behavior;
