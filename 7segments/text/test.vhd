library ieee;

use ieee.std_logic_1164.ALL;
use ieee.numeric_std.ALL;

entity test is
   port (
         clock : in std_logic;
         inputButtons : in std_logic_vector(3 downto 0);
         sevenSegments : out std_logic_vector(7 downto 0);
         cableSelect : out std_logic_vector(3 downto 0));
end test;

architecture behavior of test is
   constant stringToPrint: string := "_-+-_- Hello FPGA Wworld _-+-==- ";
   signal enabledDigit: std_logic_vector (1 downto 0) := "00";
   signal charForDigit: character := nul;
   signal stringOffset: integer range 0 to stringToPrint'length-1:= 0;
begin

-- counter for multiplexer and delay used for scrolling the text
   counter : process(clock)
   variable counterForMultiplexer : integer range 0 to 100000 := 0; -- ticks every 100E3 / 50E6 = 2ms
   variable counterForScrolling  : integer range 0 to 8000000 := 0; -- ticks every 8E6 / 50E6 = 160ms 

   begin
      if clock'event and clock = '1' then
      
         if counterForMultiplexer = counterForMultiplexer'HIGH - 1 then
         -- if it is equals to the highest possible value for counterForMultiplexer - 1
            counterForMultiplexer := 0;
            enabledDigit <= std_logic_vector(unsigned(enabledDigit)+1);
         else
            counterForMultiplexer := counterforMultiplexer + 1;
         end if;
         
         if counterForScrolling = counterForScrolling'HIGH - 1 then
         -- if it is equals to the highest possible value for counterForScrolling - 1
            counterForScrolling := 0;
            if stringOffset = stringToPrint'length-1 then
               stringOffset <= 0;
            else
               stringOffset <= stringOffset + 1;
            end if;
         else
            counterForScrolling := counterForScrolling + 1;
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
      
      -- select char to display according to the current enabled digit and the stringOffset
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
         when '=' => sevenSegments <= "11110110";
         when '+' => sevenSegments <= "11111110";
         when '-' => sevenSegments <= "10111111";
         when '_' => sevenSegments <= "11110111";
         when ' ' => sevenSegments <= "11111111";
         when ''' => sevenSegments <= "11111101";
         when ',' => sevenSegments <= "11111011";
         when '.' => sevenSegments <= "01111111";
         when 'A' => sevenSegments <= "10001000";
         when 'a' => sevenSegments <= "00100000";
         when 'B' => sevenSegments <= "10000011";
         when 'b' => sevenSegments <= "10000011";
         when 'C' => sevenSegments <= "11000110";
         when 'c' => sevenSegments <= "10100111";
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
         when 'M' => sevenSegments <= "11001100"; --first part of a multidigit M
         when 'm' => sevenSegments <= "11011000"; --second part of a multidigit M
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
         when 'W' => sevenSegments <= "11000011"; --first part of multidigit W
         when 'w' => sevenSegments <= "11100001"; --second part of multidigit W
         when 'X' => sevenSegments <= "11110000"; --first part of multidigit X
         when 'x' => sevenSegments <= "11000110"; --second part of multidigit X
         when 'Y' => sevenSegments <= "10011011"; --first part of multidigit y
         when 'y' => sevenSegments <= "10101101"; --second part of multidigit y
         when 'Z' => sevenSegments <= "10100100";
         when 'z' => sevenSegments <= "10100100";
         when others => sevenSegments <= "11111111";
      end case;
   end process;
end behavior;
