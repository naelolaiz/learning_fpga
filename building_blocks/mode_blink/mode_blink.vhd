-- mode_blink
--
-- Two-mode blink driver: either pass an incoming pulse through to
-- the output unchanged, or toggle the output on every rising edge
-- of the input.
--
--   toggleMode = '0' → signalOut tracks signalIn directly. A 1 Hz
--                      square in produces a 1 Hz square out (2 Hz
--                      perceived blink — one transition per rising
--                      AND each falling edge of the input).
--   toggleMode = '1' → signalOut toggles only on rising edges of
--                      signalIn, so the apparent blink rate is
--                      halved.
--
-- Originally lived as `DotBlinker.vhd` inside the 7-segments clock
-- project, driving the middle decimal-point blink with HHMM/MMSS
-- mode selection. The logic itself is generic; lifted out here and
-- renamed with mode-agnostic port names so it can drive any pulsed
-- indicator with a "half rate / full rate" toggle.

LIBRARY ieee;
USE ieee.std_logic_1164.ALL;

entity mode_blink is
   port (signalIn   : in  std_logic;
         toggleMode : in  std_logic;
         signalOut  : out std_logic := '0');
end mode_blink;

architecture RTL of mode_blink is
   signal toggled : std_logic := '0';
begin
   toggle : process(signalIn)
   begin
      if rising_edge(signalIn) then
         toggled <= not toggled;
      end if;
   end process;

   signalOut <= signalIn when toggleMode = '0' else toggled;
end RTL;
