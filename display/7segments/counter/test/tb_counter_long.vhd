library ieee;
use ieee.std_logic_1164.ALL;
use ieee.numeric_std.ALL;

-- Long-window view of the 4-digit 7-segment multiplexed counter.
--
-- Companion to `tb_counter` (10 ms window, useful for seeing individual
-- clock edges and mux rotation in the gallery PNG). This one zooms
-- out to 150 ms so the internal `numberToDisplay` counter — which
-- ticks every ~62.5 ms — is observed incrementing.
--
-- At 1 fs GHDL timescale a 150 ms VCD would be ~650 MB (too large for
-- the waveform render pipeline). Dumped in FST format instead via
-- `FST_TBS := tb_counter_long` in the Makefile; waveview reads FST
-- natively, so the rest of the flow is unchanged.
--
-- Assertion added on top of the tb_counter three:
--   (D) By end-of-sim, the internal counter must have incremented
--       at least once. Observed via sevenSegments transitioning to a
--       non-zero BCD encoding while digit 0 is selected.
--
-- (A), (B), (C) from tb_counter are intentionally NOT duplicated here -
-- they cover the same invariants and run against the same DUT; the
-- short-window TB asserts them. This TB's job is purely the slower
-- observation tb_counter can't afford to wait for.

entity tb_counter_long is
end tb_counter_long;

architecture testbench of tb_counter_long is
   constant TEST_DURATION : time := 150 ms;

   signal sClock50MHz       : std_logic := '0';
   signal sSevenSegments    : std_logic_vector(6 downto 0) := "1000000"; -- "0"
   signal sCableSelect      : std_logic_vector(3 downto 0) := "1110";    -- digit 0 selected
   signal sSimulationActive : boolean := true;

   -- Latches high as soon as we observe a non-zero BCD value for
   -- digit 0. Checked at end-of-sim.
   signal sCounterTicked    : boolean := false;

   -- Encoding for digit "0" in the DUT's BCD-to-7seg table. Anything
   -- else on the 7-segment bus while digit 0 is selected means
   -- numberToDisplay has incremented past 0.
   constant ENCODING_ZERO : std_logic_vector(6 downto 0) := "1000000";
begin

   DUT : entity work.counter(behavior)
      port map (
         clock         => sClock50MHz,
         sevenSegments => sSevenSegments,
         cableSelect   => sCableSelect);

   sClock50MHz <= not sClock50MHz after 10 ns when sSimulationActive;

   -- Watch for the counter-tick: when digit 0 is being mux-selected
   -- (cableSelect = "1110") and sevenSegments shows something other
   -- than the zero encoding, the counter has rolled past 0.
   track_counter_tick : process (sClock50MHz)
   begin
      if rising_edge(sClock50MHz) then
         if sCableSelect = "1110" and sSevenSegments /= ENCODING_ZERO then
            sCounterTicked <= true;
         end if;
      end if;
   end process;

   TEST_TERMINATOR : process
   begin
      sSimulationActive <= true;
      wait for TEST_DURATION;

      -- (D) numberToDisplay must have incremented at least once.
      -- At 62.5 ms per tick, 150 ms guarantees two increments --
      -- a stuck counter (e.g. stuck enable, frozen counterForCounter)
      -- leaves sCounterTicked false and fails the build.
      assert sCounterTicked
         report "counter stuck: numberToDisplay never incremented in 150 ms"
         severity failure;

      sSimulationActive <= false;
      wait;
   end process;

end testbench;
