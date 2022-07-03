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
	signal enabledDigit: std_logic_vector (1 downto 0) := "00";
	signal counterForScroll: integer range 0 to 3 := 0;
	signal counterForMultiplexer : integer range 0 to 100000 := 0;
	signal LED_BCD: std_logic_vector (3 downto 0);
	signal charForDigit: character := nul;
	signal charsToPrint: string (1 to 4);
	constant stringToPrint: string := "HiHI";
	
begin

   counter : process(clock)
      --variable arrayPointer: integer range stringToPrint'length - 3 downto 1:= stringToPrint'length - 3;
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
				--charsToPrint <= stringToPrint (arrayPointer to arrayPointer+3); -- & stringToPrint (1 to charsToPrint'length - charsLeft);
            --arrayPointer := arrayPointer + 1;
				charsToPrint <= stringToPrint (1 to 4);
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
		   charForDigit <= charsToPrint(4);
		 when "01" =>
			charForDigit <= charsToPrint(3);
		 when "10" =>
			charForDigit <= charsToPrint(2);
		 when "11" =>
			charForDigit <= charsToPrint(1);
		 end case;
	end process;
	
	process(charForDigit)
	begin
		case charForDigit is
			when '0' => sevenSegments <= "1000000";
			when '1' => sevenSegments <= "1111001";
			when '2' => sevenSegments <= "0100100";
			when '3' => sevenSegments <= "0110000";
			when '4' => sevenSegments <= "0011001";
			when '5' => sevenSegments <= "0010010";
			when '6' => sevenSegments <= "0000010";
			when '7' => sevenSegments <= "1111000";
			when '8' => sevenSegments <= "0000000";
			when '9' => sevenSegments <= "0010000";
			when ' ' => sevenSegments <= "1111111";
			when 'A' => sevenSegments <= "0001000";
			when 'a' => sevenSegments <= "0001000";
			when 'B' => sevenSegments <= "0000011";
			when 'b' => sevenSegments <= "0000011";
			when 'C' => sevenSegments <= "1000110";
			when 'c' => sevenSegments <= "1000110";
			when 'D' => sevenSegments <= "0100001";
			when 'd' => sevenSegments <= "0100001";
			when 'E' => sevenSegments <= "0000110";
			when 'e' => sevenSegments <= "0000100";
			when 'F' => sevenSegments <= "0001110";
			when 'f' => sevenSegments <= "0001110";
			when 'G' => sevenSegments <= "0010000";
			when 'g' => sevenSegments <= "0010000";
			when 'H' => sevenSegments <= "0001001";
			when 'h' => sevenSegments <= "0001011";
			when 'I' => sevenSegments <= "1001111";
			when 'i' => sevenSegments <= "1101111";
			when 'J' => sevenSegments <= "1110001";
			when 'j' => sevenSegments <= "1110001";
			when 'L' => sevenSegments <= "1000111";
			when 'l' => sevenSegments <= "1000111";
			when 'N' => sevenSegments <= "0101011";
			when 'n' => sevenSegments <= "0101011";
			when 'O' => sevenSegments <= "1000000"; 
			when 'o' => sevenSegments <= "0100011";
			when 'P' => sevenSegments <= "0001100";
			when 'p' => sevenSegments <= "0001100";
			when 'R' => sevenSegments <= "0101111";
			when 'r' => sevenSegments <= "0101111";
			when 'S' => sevenSegments <= "0010010";
			when 's' => sevenSegments <= "0010010";
			when 'U' => sevenSegments <= "1000001";
			when 'u' => sevenSegments <= "1100011";
			when others => sevenSegments <= "1111111";
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
