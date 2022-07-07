----------------
-- Counter entity
LIBRARY ieee;
use ieee.std_logic_1164.ALL;
use ieee.numeric_std.ALL;

entity Counter is
   generic (MAX_NUMBER_FOR_COUNTER: std_logic_vector (63 downto 0) := std_logic_vector(to_unsigned(10, 64)));
   port (clock: in std_logic := '0';
         reset: in std_logic := '0';
	 direction: in std_logic := '1'; -- 1 = forward
         overflow : out std_logic := '0';
         counter : out std_logic_vector (63 downto 0):= std_logic_vector(to_unsigned(0, 64)));
end Counter;
architecture behaviorCounterForDigit of Counter is
   signal counterValue : std_logic_vector (63 downto 0) := std_logic_vector(to_unsigned(0, 64));
begin
   counterProcess : process(clock, reset)
   begin
      if clock'event and clock = '1' then
      -- TODO: simplify?
	 if direction = '1' then
            if counterValue = MAX_NUMBER_FOR_COUNTER then 
               counterValue <= std_logic_vector(to_unsigned(0, counterValue'length));
	       overflow <= '1';
            else
               counterValue <= std_logic_vector(to_unsigned(to_integer(unsigned(counterValue))+1, counterValue'length));
	       overflow <= '0';
            end if;
	 else -- going backwards
            if counterValue = std_logic_vector(to_unsigned(0, counterValue'length)) then
               counterValue <= MAX_NUMBER_FOR_COUNTER;
	       overflow <= '1';
            else
               counterValue <= std_logic_vector(to_unsigned(to_integer(unsigned(counterValue))-1, counterValue'length));
	       overflow <= '0';
            end if;
	 end if;
      end if;
      if reset = '1' then
          counterValue <= std_logic_vector(to_unsigned(0,counterValue'length));
      end if;
   end process;
   counter <= counterValue;
end behaviorCounterForDigit;
