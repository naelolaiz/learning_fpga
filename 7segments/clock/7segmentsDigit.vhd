LIBRARY ieee;

USE ieee.std_logic_1164.ALL;
use ieee.numeric_std.ALL;

---------------
-- Digit entity
entity Digit is
   generic (MAX_NUMBER: integer range 0 to 9 := 9);
   port (clock : in std_logic := '0';
         reset : in std_logic := '0';
         direction: in std_logic := '1'; -- 1 is forward
         currentNumber : out std_logic_vector (3 downto 0) := "0000";
         carryBit : out std_logic := '0');
end Digit;
architecture behaviorDigit of Digit is
   signal currentNumberSignal : integer range 0 to MAX_NUMBER := 0;
begin
    increment: process(clock, reset)
    begin
       if clock'event and clock = '1' then
       -- TODO: simplify
          if direction = '1' then
             if currentNumberSignal = MAX_NUMBER then
                currentNumberSignal <= 0;
                carryBit <= '1';
             else
                currentNumberSignal <= currentNumberSignal + 1;
                carryBit <= '0';
             end if;
          else
             if currentNumberSignal = 0 then
                currentNumberSignal <= MAX_NUMBER;
                carryBit <= '1';
             else
                currentNumberSignal <= currentNumberSignal - 1;
                carryBit <= '0';
             end if;
          end if;
          
       end if;
       if reset = '1' then
          currentNumberSignal <= 0;
       end if;
    end process;
    currentNumber <= std_logic_vector(to_unsigned(currentNumberSignal, 4));
end behaviorDigit;

