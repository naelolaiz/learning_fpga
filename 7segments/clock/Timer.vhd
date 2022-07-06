---------------
-- Timer entity
LIBRARY ieee;

USE ieee.std_logic_1164.ALL;
use ieee.numeric_std.ALL;

entity Timer is
   generic (MAX_NUMBER: integer := 50000000;
            TRIGGER_DURATION: integer := 1);
   port (clock: in std_logic := '0';
         reset: in std_logic := '0';
         timerTriggered : out std_logic := '0');
end Timer;

architecture behaviorTimer of Timer is
begin
   timerTimer: process(clock, reset)
   variable counterForTriggerOut: integer range 0 to MAX_NUMBER := 0;
   begin
      if clock'event and clock = '1' then
         if reset = '1' then
             counterForTriggerOut := 0;
         end if;

         if counterForTriggerOut = MAX_NUMBER then
            counterForTriggerOut := 0;
            timerTriggered <= '1';
         else
            counterForTriggerOut := counterForTriggerOut + 1;
            if counterForTriggerOut = TRIGGER_DURATION then
               timerTriggered <= '0';
            end if;
         end if;
      end if;
   end process;
end behaviorTimer;
