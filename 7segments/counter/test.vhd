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
--   cableSelectDigit0 <= '0';
--   cableSelectDigit1 <= '0';
--   cableSelectDigit2 <= '0';
--   cableSelectDigit3 <= '0';
process(LED_BCD)
begin




--    case LED_BCD is
--    when "0000" => sevenSegments <= "0000001"; -- "0"     
--    when "0001" => sevenSegments <= "1001111"; -- "1" 
--    when "0010" => sevenSegments <= "0010010"; -- "2" 
--    when "0011" => sevenSegments <= "0000110"; -- "3" 
--    when "0100" => sevenSegments <= "1001100"; -- "4" 
--    when "0101" => sevenSegments <= "0100100"; -- "5" 
--    when "0110" => sevenSegments <= "0100000"; -- "6" 
--    when "0111" => sevenSegments <= "0001111"; -- "7" 
--    when "1000" => sevenSegments <= "0000000"; -- "8"     
--    when "1001" => sevenSegments <= "0000100"; -- "9" 
--    when "1010" => sevenSegments <= "0000010"; -- a
--
--    when "1011" => sevenSegments <= "1100000"; -- b
--    when "1100" => sevenSegments <= "0110001"; -- C
--    when "1101" => sevenSegments <= "1000010"; -- d
--    when "1110" => sevenSegments <= "0110000"; -- E
--    when "1111" => sevenSegments <= "0111000"; -- F
--end case;
end process;
   
   counter : process(clock)
   begin
      if clock'event and clock = '1' then
		   --refreshC
		   if counterForMultiplexer = 99999 then
			   counterForMultiplexer <= 0;
				enabledDigit <= std_logic_vector(shift_left(unsigned(enabledDigit),1));
				--ALU_Result <= std_logic_vector(shift_left(unsigned(inputB), to_integer(unsigned(shamt))));
				if enabledDigit = "0000" then
				   enabledDigit <=  "0001";
				end if;
		   else
			   counterForMultiplexer <= counterforMultiplexer + 1;
			end if;
         if counterForDelay = 14999999 then
            counterForDelay <= 0;
            --counterToDisplay <= std_logic_vector(unsigned(counterToDisplay + 1));
				counterToDisplay <= std_logic_vector(to_unsigned(to_integer(unsigned( counterToDisplay )) + 1, 16));
         else
            counterForDelay <= counterForDelay + 1;
         end if;
      end if;

   end process;
	
-- 4-to-1 MUX to generate anode activating signals for 4 LEDs 
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
--	 case enabledDigit is
--    when "0001" =>
--        LED_BCD <= counterToDisplay(3 downto 0);
--    when "0010" =>
--        LED_BCD <= counterToDisplay(7 downto 4);
--    when "0100" =>
--        LED_BCD <= counterToDisplay(11 downto 8);
--    when "1000" =>
--        LED_BCD <= counterToDisplay(15 downto 12);
--    end case;
end process;

--   sevenSegments <= "1000000" when counterToDisplay = 0 else
--        "1111001" when counterToDisplay =  1 else
--        "0100100" when counterToDisplay =  2 else
--        "0110000" when counterToDisplay =  3 else
--        "0011001" when counterToDisplay =  4 else
--        "0010010" when counterToDisplay =  5 else
--        "0000010" when counterToDisplay =  6 else
--        "1111000" when counterToDisplay =  7 else
--        "0000000" when counterToDisplay =  8 else
--        "0010000" when counterToDisplay =  9 else
--        "0001000" when counterToDisplay = 10 else
--        "0000011" when counterToDisplay = 11 else
--        "1000110" when counterToDisplay = 12 else
--        "0100001" when counterToDisplay = 13 else
--        "0000110" when counterToDisplay = 14 else
--        "0001110" ;
		  
		  
		  
--		  sevenSegments <= "0001110" when counterToDisplay = 0 else
--        "0001110" when counterToDisplay =  1 else
--        "0001110" when counterToDisplay =  2 else
--        "0001110" when counterToDisplay =  3 else
--        "0001110" when counterToDisplay =  4 else
--        "0100011" when counterToDisplay =  5 else
--        "0100011" when counterToDisplay =  6 else
--        "0100011" when counterToDisplay =  7 else
--        "0100011" when counterToDisplay =  8 else
--        "0100011" when counterToDisplay =  9 else
--        "0100011" when counterToDisplay = 10 else
--        "0100011" when counterToDisplay = 11 else
--        "0100001" when counterToDisplay = 12 else
--        "0100001" when counterToDisplay = 13 else
--        "0100001" when counterToDisplay = 14 else
--        "0100001" ;

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
