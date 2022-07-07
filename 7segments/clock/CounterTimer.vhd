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
	 direction: in std_logic := '1'; -- 1 = forward
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
         -- TODO : simplify?
	 if direction = '1' then
            if counterValue = std_logic_vector(to_unsigned(MAX_NUMBER_FOR_COUNTER, counterValue'length)) then
               counterValue <= std_logic_vector(to_unsigned(0, counterValue'length));
            else
               counterValue <= std_logic_vector(to_unsigned(to_integer(unsigned(counterValue))+1, counterValue'length));
            end if;
	 else -- going backwards
            if counterValue = std_logic_vector(to_unsigned(0, counterValue'length)) then
               counterValue <= std_logic_vector(to_unsigned(MAX_NUMBER_FOR_COUNTER,counterValue'length));
            else
               counterValue <= std_logic_vector(to_unsigned(to_integer(unsigned(counterValue))-1, counterValue'length));
            end if;
	 end if;
      end if;
      if reset = '1' then
          counterValue <= std_logic_vector(to_unsigned(0,64));
      end if;
   end process;
   timerTriggered <= TimerTick;
   counter <= counterValue;
end behaviorCounterTimer;

LIBRARY ieee;
use ieee.std_logic_1164.ALL;
use ieee.numeric_std.ALL;
entity Counter is
   generic (MAX_NUMBER_FOR_COUNTER: integer := 10);
   port (clock: in std_logic := '0';
         reset: in std_logic := '0';
	 direction: in std_logic := '1'; -- 1 = forward
         timerTriggered : out std_logic := '0';
         counter : out std_logic_vector (63 downto 0):= std_logic_vector(to_unsigned(0,64)));
end Counter;
architecture behaviorCounterForDigit of Counter is
   signal counterValue : std_logic_vector (63 downto 0) := std_logic_vector(to_unsigned(0,64));
begin
   counterProcess : process(clock, reset)
   begin
      if clock'event and clock = '1' then
         -- TODO : simplify?
	 if direction = '1' then
            if counterValue = std_logic_vector(to_unsigned(MAX_NUMBER_FOR_COUNTER, 64)) then --counterValue'length)) then
               counterValue <= std_logic_vector(to_unsigned(0, 64));
	       timerTriggered <= '1';
            else
               counterValue <= std_logic_vector(to_unsigned(to_integer(unsigned(counterValue))+1, 64));
	       timerTriggered <= '0';
            end if;
	 else -- going backwards
            if counterValue = std_logic_vector(to_unsigned(0, 64)) then
               counterValue <= std_logic_vector(to_unsigned(MAX_NUMBER_FOR_COUNTER, 64));
	       timerTriggered <= '1';
            else
               counterValue <= std_logic_vector(to_unsigned(to_integer(unsigned(counterValue))-1, 64));
	       timerTriggered <= '0';
            end if;
	 end if;
      end if;
      if reset = '1' then
          counterValue <= std_logic_vector(to_unsigned(0,64));
      end if;
   end process;
   counter <= counterValue;
end behaviorCounterForDigit;
