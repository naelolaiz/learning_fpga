---------------
-- VariableTimer entity
LIBRARY ieee;

USE ieee.std_logic_1164.ALL;
use ieee.numeric_std.ALL;


entity VariableTimer is
   generic (MAX_NUMBER: integer := 50000000;
            TRIGGER_DURATION: integer := 1);
   port (clock: in std_logic := '0';
         reset: in std_logic := '0';
         setMax: in std_logic := '0';
         dataIn: in std_logic := '0';
         timerTriggered : out std_logic := '0');
end VariableTimer;


architecture behaviorVariableTimer of VariableTimer is
begin
   timerTimer: process(clock, reset, setMax, dataIn)
   variable counterForTriggerOut: integer range 0 to MAX_NUMBER := 0;
   variable setMaxStarted: boolean := false;
   variable maxNumber: std_logic_vector (63 downto 0) := std_logic_vector(to_unsigned(MAX_NUMBER,64));
   variable serialInDataCounter: integer range 0 to 63 := 0;
   begin
      if clock'event and clock = '1' then
         if reset = '1' then
             counterForTriggerOut := 0;
             maxNumber := std_logic_vector(to_unsigned(MAX_NUMBER,64));
         end if;
         if setMax = '0' then
            setMaxStarted := false;
            serialInDataCounter := 0;
            if counterForTriggerOut = MAX_NUMBER then
               counterForTriggerOut := 0;
               timerTriggered <= '1';
            else
               counterForTriggerOut := counterForTriggerOut + 1;
               if counterForTriggerOut = TRIGGER_DURATION then
                  timerTriggered <= '0';
               end if;
            end if;
         else -- setMax = '1', we are setting the timer value
            if setMaxStarted = false then -- first time
               maxNumber := std_logic_vector(to_unsigned(0,64));
               setMaxStarted := true;
            end if;
            if serialInDataCounter < serialInDataCounter'HIGH then
               maxNumber := maxNumber(62 downto 0) & dataIn;
               serialInDataCounter := serialInDataCounter + 1;
            end if;
            counterForTriggerOut := 0;
         end if;                 
      end if;
   end process;
end behaviorVariableTimer;
