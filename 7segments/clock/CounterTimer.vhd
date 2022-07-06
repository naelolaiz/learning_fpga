----------------
-- CounterTimer entity
LIBRARY ieee;
use ieee.std_logic_1164.ALL;
use ieee.numeric_std.ALL;

entity CounterTimer is
   generic (MAX_NUMBER_FOR_TIMER: integer := 50000000;
            MAX_NUMBER_FOR_COUNTER: integer := 10);
   port (clock: in std_logic := '0';
         reset: in std_logic := '0';
         timerTriggered : out std_logic := '0';
         counter : out std_logic_vector (63 downto 0):= std_logic_vector(to_unsigned(0,64)));
end CounterTimer;

architecture behaviorCounterTimer of CounterTimer is
   signal timerTick : std_logic := '0';
   signal counterValue : std_logic_vector (63 downto 0) := std_logic_vector(to_unsigned(0,64));
begin
   Timer : entity work.Timer(behaviorTimer)
      generic map ( MAX_NUMBER => MAX_NUMBER_FOR_TIMER )
      port map    ( clock => clock,
                    timerTriggered => timerTick,
                    reset => reset );
   counterProcess : process(timerTick, reset)
   begin
      if timerTick'event and timerTick = '1' then
         if counterValue = std_logic_vector(to_unsigned(MAX_NUMBER_FOR_COUNTER, counterValue'length)) then
            counterValue <= std_logic_vector(to_unsigned(0,64));
         else
            counterValue <= std_logic_vector(to_unsigned(to_integer(unsigned(counterValue))+1, counterValue'length));
         end if;
      end if;
      if reset = '1' then
          counterValue <= std_logic_vector(to_unsigned(0,64));
      end if;
   end process;
   timerTriggered <= TimerTick;
   counter <= counterValue;
end behaviorCounterTimer;
