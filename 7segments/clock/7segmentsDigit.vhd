LIBRARY ieee;

USE ieee.std_logic_1164.ALL;
use ieee.numeric_std.ALL;

---------------
-- Digit entity
entity Digit is
   generic (MAX_NUMBER: integer range 0 to 9 := 9);
   port (clockForIncrement : in std_logic := '0';
         reset : in std_logic := '0';
         --set: in std_logic := 0; -- when 1, clock is use to increment the currentNumber 
         currentNumber : out std_logic_vector (3 downto 0) := "0000";
         carryBit : out std_logic := '0');
end Digit;
architecture behaviorDigit of Digit is
   signal currentNumberSignal : integer range 0 to MAX_NUMBER := 0;
begin
    increment: process(clockForIncrement, reset)
    begin
       if clockForIncrement'event and clockForIncrement = '1' then
          --if set = '1' then        
          --end if;
          if currentNumberSignal = MAX_NUMBER then
             currentNumberSignal <= 0;
             carryBit <= '1';
          else
             currentNumberSignal <= currentNumberSignal + 1;
             carryBit <= '0';
          end if;
       end if;
       if reset = '1' then
          currentNumberSignal <= 0;
       end if;
    end process;
    currentNumber <= std_logic_vector(to_unsigned(currentNumberSignal, 4));
end behaviorDigit;

