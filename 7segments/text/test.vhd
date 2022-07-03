library ieee;

use ieee.std_logic_1164.ALL;
use ieee.numeric_std.ALL;
--use ieee.std_logic_unsigned.all;

entity test is
   port (
         clock : in std_logic;
         inputButtons : in std_logic_vector(3 downto 0);
         sevenSegments : out std_logic_vector(6 downto 0);
         cableSelect : out std_logic_vector(3 downto 0));
end test;

architecture behavior of test is
	signal counterForDelay  : integer range 0 to 15000000 := 0; -- ticks every 10E6 / 50E6 = 200ms 
	signal counterToDisplay: std_logic_vector (15 downto 0) := "1111000000001101";
	signal enabledDigit: std_logic_vector (1 downto 0) := "00";
	signal counterForScroll: integer range 0 to 3 := 0;
	signal counterForMultiplexer : integer range 0 to 100000 := 0;
	signal LED_BCD: std_logic_vector (3 downto 0);
begin

--process(LED_BCD)
--begin
--
----    case LED_BCD is
----    when "0000" => sevenSegments <= "0000001"; -- "0"     
----    when "0001" => sevenSegments <= "1001111"; -- "1" 
----    when "0010" => sevenSegments <= "0010010"; -- "2" 
----    when "0011" => sevenSegments <= "0000110"; -- "3" 
----    when "0100" => sevenSegments <= "1001100"; -- "4" 
----    when "0101" => sevenSegments <= "0100100"; -- "5" 
----    when "0110" => sevenSegments <= "0100000"; -- "6" 
----    when "0111" => sevenSegments <= "0001111"; -- "7" 
----    when "1000" => sevenSegments <= "0000000"; -- "8"     
----    when "1001" => sevenSegments <= "0000100"; -- "9" 
----    when "1010" => sevenSegments <= "0000010"; -- a
----
----    when "1011" => sevenSegments <= "1100000"; -- b
----    when "1100" => sevenSegments <= "0110001"; -- C
----    when "1101" => sevenSegments <= "1000010"; -- d
----    when "1110" => sevenSegments <= "0110000"; -- E
----    when "1111" => sevenSegments <= "0111000"; -- F
----end case;
--end process;
   
   counter : process(clock)
   begin
      if clock'event and clock = '1' then
		   --refreshC
		   if counterForMultiplexer = 99999 then
			   counterForMultiplexer <= 0;
				enabledDigit <= std_logic_vector(unsigned(enabledDigit)+1);
		   else
			   counterForMultiplexer <= counterforMultiplexer + 1;
			end if;
         if counterForDelay = 14999999 then
            counterForDelay <= 0;
            counterForScroll <= counterForScroll + 1;
         else
            counterForDelay <= counterForDelay + 1;
         end if;
      end if;
   end process;
	
-- 4-to-1 MUX to generate anode activating signals for 4 LEDs 
	process(enabledDigit)
		constant InputForShifter: std_logic_vector(3 downto 0) := "0001";

	begin
		cableSelect <= not std_logic_vector(unsigned(InputForShifter) rol (to_integer(unsigned(enabledDigit)) + counterForScroll));
		-- see https://nandland.com/common-vhdl-conversions/#Numeric-Std_Logic_Vector-To-Integer 
		-- and http://atlas.physics.arizona.edu/~kjohns/downloads/vhdl/VHDL-xilinx-help.pdf : Foundation Express Packages -> std_logic_arith Package -> Conversion Functions : rol
		
		 case enabledDigit is
		 when "00" =>
			  LED_BCD <= counterToDisplay(3 downto 0);
		 when "01" =>
			  LED_BCD <= counterToDisplay(7 downto 4);
		 when "10" =>
			  LED_BCD <= counterToDisplay(11 downto 8);
		 when "11" =>
			  LED_BCD <= counterToDisplay(15 downto 12);
		 end case;
	end process;

   sevenSegments <= "0100011" when LED_BCD = "0000" else
	--"1000000" when LED_BCD = "0000" else
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
