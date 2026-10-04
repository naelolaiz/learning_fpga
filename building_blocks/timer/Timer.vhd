-- Timer
--
-- Free-running tick generator. A `MAX_NUMBER`-counter increments on
-- every rising edge of `clock`; when the count reaches `maxLimit` the
-- output `timerTriggered` goes high for `TRIGGER_DURATION` cycles and
-- the counter wraps to 0.
--
-- `maxLimit` is exposed as a port so a wrapper (e.g. VariableTimer)
-- can override the trigger period at runtime. When the port is left
-- unconnected the default — the `MAX_NUMBER` generic — is used, so
-- existing call-sites that only set the generic keep working.
--
-- The counter is typed `integer range 0 to MAX_NUMBER`, so any
-- runtime `maxLimit` value must fit in that range. Wrappers that
-- accept arbitrary user input should clamp before driving the port.
-- Reset is synchronous and clears both the count and the output. A
-- lowered limit already passed by the counter triggers on the next edge.
-- Pulses overlap when TRIGGER_DURATION >= maxLimit + 1, leaving the
-- output high until reset or until a longer period lets the pulse end.

LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
use ieee.numeric_std.ALL;

entity Timer is
   generic (MAX_NUMBER       : natural := 50000000;
            TRIGGER_DURATION : positive := 1);
   port (clock          : in  std_logic := '0';
         reset          : in  std_logic := '0';
         maxLimit       : in  integer range 0 to MAX_NUMBER := MAX_NUMBER;
         timerTriggered : out std_logic := '0');
end Timer;

architecture behaviorTimer of Timer is
begin
   timerTimer : process(clock)
      variable counterForTriggerOut : integer range 0 to MAX_NUMBER := 0;
   begin
      if rising_edge(clock) then
         if reset = '1' then
            counterForTriggerOut := 0;
            timerTriggered <= '0';
         elsif counterForTriggerOut >= maxLimit then
            counterForTriggerOut := 0;
            timerTriggered <= '1';
         else
            counterForTriggerOut := counterForTriggerOut + 1;
            if counterForTriggerOut >= TRIGGER_DURATION then
               timerTriggered <= '0';
            end if;
         end if;
      end if;
   end process;
end behaviorTimer;
