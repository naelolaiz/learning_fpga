-- DotBlinker.vhd
--
-- Drives the middle-digit decimal-point blink signal.
--
--   isHHMMMode = '0' (MMSS view): dotOut tracks oneSecondPeriodSquare
--                                  directly => 1 toggle each rising AND
--                                  each falling edge of the 1 Hz square.
--   isHHMMMode = '1' (HHMM view): dotOut toggles only on rising edges of
--                                  oneSecondPeriodSquare => half the rate.
--
-- Pulled into its own entity so a testbench can drive `oneSecondPeriodSquare`
-- and `isHHMMMode` directly and assert the cause-effect ratio without
-- having to push 50_000_000-tick timers through the full top-level.
--
-- Pure VHDL-93 (no 2008 features), so it compiles under either standard.

LIBRARY ieee;
USE ieee.std_logic_1164.ALL;

entity DotBlinker is
   port (
      oneSecondPeriodSquare : in  std_logic;
      isHHMMMode            : in  std_logic;
      dotOut                : out std_logic := '0');
end DotBlinker;

architecture RTL of DotBlinker is
   signal toggled : std_logic := '0';
begin
   -- Edge-triggered toggle for the HHMM half-rate path.
   toggle : process(oneSecondPeriodSquare)
   begin
      if rising_edge(oneSecondPeriodSquare) then
         toggled <= not toggled;
      end if;
   end process;

   dotOut <= oneSecondPeriodSquare when isHHMMMode = '0' else toggled;
end RTL;
