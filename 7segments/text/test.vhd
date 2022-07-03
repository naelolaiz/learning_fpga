library ieee;

use ieee.std_logic_1164.ALL;
use ieee.numeric_std.ALL;
--use ieee.std_logic_unsigned.all;

entity test is
   port (
         clock : in std_logic;
         inputButtons : in std_logic_vector(3 downto 0);
         sevenSegments : out std_logic_vector(7 downto 0);
         cableSelect : out std_logic_vector(3 downto 0));
end test;

architecture behavior of test is
	signal counterForDelay  : integer range 0 to 15000000 := 0; -- ticks every 10E6 / 50E6 = 200ms 
	signal enabledDigit: std_logic_vector (1 downto 0) := "00";
	--signal counterForScroll: integer range 0 to 3 := 0;
	signal counterForMultiplexer : integer range 0 to 100000 := 0;
	signal LED_BCD: std_logic_vector (3 downto 0);
	signal charForDigit: character := nul;
	constant stringToPrint: string := " - HELLO - hello - THIS IS A TEST - not enough chars -";
	signal stringOffset: integer range 0 to stringToPrint'length-1:= 0;
begin

   counter : process(clock)

   begin
      if clock'event and clock = '1' then
		   if counterForMultiplexer = 99999 then
			   counterForMultiplexer <= 0;
				enabledDigit <= std_logic_vector(unsigned(enabledDigit)+1);
		   else
			   counterForMultiplexer <= counterforMultiplexer + 1;
			end if;
         if counterForDelay = 14999999 then
            counterForDelay <= 0;
            --counterForScroll <= counterForScroll + 1;
				if stringOffset = stringToPrint'length-1 then
				   stringOffset <= 0;
				else
				   stringOffset <= stringOffset + 1;
				end if;
         else
            counterForDelay <= counterForDelay + 1;
         end if;
      end if;
   end process;
	
-- 4-to-1 MUX to active each of the digits 
	process(enabledDigit, stringOffset)
		constant InputForShifter: std_logic_vector(3 downto 0) := "0001";
	begin
		-- see https://nandland.com/common-vhdl-conversions/#Numeric-Std_Logic_Vector-To-Integer 
		-- and http://atlas.physics.arizona.edu/~kjohns/downloads/vhdl/VHDL-xilinx-help.pdf : Foundation Express Packages -> std_logic_arith Package -> Conversion Functions : rol
		cableSelect <= not std_logic_vector(unsigned(InputForShifter) rol (to_integer(unsigned(enabledDigit))));
		
      -- select char to display according to the current mux active output and the stringOffset
		charForDigit <= stringToPrint(((stringOffset + to_integer(unsigned(not(enabledDigit)))) mod stringToPrint'length)+1);
	end process;
	
--ASCII to 7 segment conversions
	process(charForDigit)
	begin
		case charForDigit is
			when '0' => sevenSegments <= "11000000";
			when '1' => sevenSegments <= "11111001";
			when '2' => sevenSegments <= "10100100";
			when '3' => sevenSegments <= "10110000";
			when '4' => sevenSegments <= "10011001";
			when '5' => sevenSegments <= "10010010";
			when '6' => sevenSegments <= "10000010";
			when '7' => sevenSegments <= "11111000";
			when '8' => sevenSegments <= "10000000";
			when '9' => sevenSegments <= "10010000";
			when '-' => sevenSegments <= "10111111";
			when ' ' => sevenSegments <= "11111111";
			when 'A' => sevenSegments <= "10001000";
			when 'a' => sevenSegments <= "00100000";
			when 'B' => sevenSegments <= "10000011";
			when 'b' => sevenSegments <= "10000011";
			when 'C' => sevenSegments <= "11000110";
			when 'c' => sevenSegments <= "11000110";
			when 'D' => sevenSegments <= "10100001";
			when 'd' => sevenSegments <= "10100001";
			when 'E' => sevenSegments <= "10000110";
			when 'e' => sevenSegments <= "10000100";
			when 'F' => sevenSegments <= "10001110";
			when 'f' => sevenSegments <= "10001110";
			when 'G' => sevenSegments <= "10010000";
			when 'g' => sevenSegments <= "10010000";
			when 'H' => sevenSegments <= "10001001";
			when 'h' => sevenSegments <= "10001011";
			when 'I' => sevenSegments <= "11001111";
			when 'i' => sevenSegments <= "11101111";
			when 'J' => sevenSegments <= "11110001";
			when 'j' => sevenSegments <= "11110001";
			when 'L' => sevenSegments <= "11000111";
			when 'l' => sevenSegments <= "11001111";
			when 'N' => sevenSegments <= "10101011";
			when 'n' => sevenSegments <= "10101011";
			when 'O' => sevenSegments <= "11000000"; 
			when 'o' => sevenSegments <= "10100011";
			when 'P' => sevenSegments <= "10001100";
			when 'p' => sevenSegments <= "10001100";
			when 'Q' => sevenSegments <= "01000000";
			when 'q' => sevenSegments <= "01000000";
			when 'R' => sevenSegments <= "10101111";
			when 'r' => sevenSegments <= "10101111";
			when 'S' => sevenSegments <= "10010010";
			when 's' => sevenSegments <= "10010010";
			when 'T' => sevenSegments <= "10001111";
			when 't' => sevenSegments <= "10001111";
			when 'U' => sevenSegments <= "11000001";
			when 'u' => sevenSegments <= "11100011";
			when others => sevenSegments <= "11111111";
		end case;
	end process;
--   sevenSegments <= "0100011" when LED_BCD = "0000" else
--	--"1000000" when LED_BCD = "0000" else
--        "1111001" when LED_BCD =  "0001" else
--        "0100100" when LED_BCD =  "0010" else
--        "0110000" when LED_BCD =  "0011" else
--        "0011001" when LED_BCD =  "0100" else
--        "0010010" when LED_BCD =  "0101" else
--        "0000010" when LED_BCD =  "0110" else
--        "1111000" when LED_BCD =  "0111" else
--        "0000000" when LED_BCD =  "1000" else
--        "0010000" when LED_BCD =  "1001" else
--        "0001000" when LED_BCD =  "1010" else
--        "0000011" when LED_BCD =  "1011" else
--        "1000110" when LED_BCD =  "1100" else
--        "0100001" when LED_BCD =  "1101" else
--        "0000110" when LED_BCD =  "1110" else
--        "0001110" ;
end behavior;
