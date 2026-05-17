library ieee;
use ieee.std_logic_1164.ALL;
use ieee.numeric_std.ALL;

-- Testbench for mode_blink driving the middle-dot.
--
-- `mode_blink` is the building block the clock uses for its
-- middle-decimal-point blink (formerly the DotBlinker entity local
-- to this project; now lives in building_blocks/mode_blink/ with
-- mode-agnostic port names). This testbench exercises it in the
-- same role: square wave in, blink out, mode-selectable.
--
-- The cause-effect property under test:
--
--     switching `toggleMode` from '0' (MMSS view) to '1' (HHMM
--     view) halves the toggle rate of the output, given the same
--     square-wave input.
--
-- We drive a synthetic 1 Hz square wave at high simulated frequency,
-- count rising edges of the output in each mode, and assert MMSS
-- sees ~2× the edges of HHMM.
--
-- This file is plain VHDL-93 in style (no 2008-only constructs); it
-- compiles under `--std=08` because the project's ghdl analyse step
-- defaults to 08 and 93 is a strict subset of what's accepted.

entity tb_clock_dot_blink is
end tb_clock_dot_blink;

architecture testbench of tb_clock_dot_blink is
   -- Synthetic 1 Hz period: mode_blink only cares about the
   -- rising/falling-edge structure of its input, so we use a tiny
   -- period and the test completes in microseconds.
   constant SQ_PERIOD   : time := 200 ns;     -- "1 Hz" in shrunk time
   constant SQ_HALF     : time := SQ_PERIOD / 2;

   signal sSimulationActive : boolean := true;
   signal sSquare           : std_logic := '0';
   signal sIsHHMMMode       : std_logic := '0';
   signal sDotOut           : std_logic;

   signal sLastDot      : std_logic := '0';
   signal sEdgesMMSS    : natural := 0;
   signal sEdgesHHMM    : natural := 0;
   signal sCountingMMSS : boolean := false;
   signal sCountingHHMM : boolean := false;
begin

   DUT : entity work.mode_blink(RTL)
      port map (
         signalIn   => sSquare,
         toggleMode => sIsHHMMMode,
         signalOut  => sDotOut);

   -- Generate the synthetic square wave with absolute-time toggles, so
   -- this TB doesn't depend on the rest of the design's clock dividers.
   square_gen : process
   begin
      while sSimulationActive loop
         sSquare <= '0';
         wait for SQ_HALF;
         sSquare <= '1';
         wait for SQ_HALF;
      end loop;
      wait;
   end process;

   -- Edge counter: bumps the active phase's counter on every
   -- transition of mode_blink's output. No mux to alias through —
   -- the DUT drives sDotOut directly.
   edge_counter : process
   begin
      wait until sDotOut'event or not sSimulationActive;
      if not sSimulationActive then
         wait;
      end if;
      if sDotOut /= sLastDot then
         if sCountingMMSS then
            sEdgesMMSS <= sEdgesMMSS + 1;
         elsif sCountingHHMM then
            sEdgesHHMM <= sEdgesHHMM + 1;
         end if;
         sLastDot <= sDotOut;
      end if;
   end process;

   driver : process
      constant OBSERVE : time := 50 * SQ_PERIOD;   -- 50 simulated "seconds"
   begin
      -- Let the square wave start cleanly.
      wait for SQ_PERIOD;

      -- ===== Phase 1: MMSS view (dotOut = square wave) =====
      sIsHHMMMode  <= '0';
      sCountingMMSS <= true;
      wait for OBSERVE;
      sCountingMMSS <= false;

      -- ===== Phase 2: HHMM view (dotOut toggles on rising edge only) =====
      sIsHHMMMode  <= '1';
      sCountingHHMM <= true;
      wait for OBSERVE;
      sCountingHHMM <= false;

      -- Sanity: both modes must have produced edges.
      assert sEdgesMMSS > 4
         report "MMSS view: expected dot toggles, saw " &
                integer'image(sEdgesMMSS)
         severity failure;
      assert sEdgesHHMM > 1
         report "HHMM view: expected dot toggles, saw " &
                integer'image(sEdgesHHMM)
         severity failure;

      -- Cause-effect: MMSS sees one rising AND one falling per square
      -- period, HHMM sees one toggle per rising edge -- ratio is 2:1.
      -- Exact equality is the right assertion for this entity (no clock
      -- aliasing or mux windowing involved).
      assert sEdgesMMSS = 2 * sEdgesHHMM
         report "expected MMSS edges = 2 * HHMM edges, got MMSS=" &
                integer'image(sEdgesMMSS) & " HHMM=" &
                integer'image(sEdgesHHMM)
         severity failure;

      report "tb_clock_dot_blink PASSED. MMSS edges=" &
             integer'image(sEdgesMMSS) & " HHMM edges=" &
             integer'image(sEdgesHHMM)
         severity note;

      sSimulationActive <= false;
      wait;
   end process;

end testbench;
