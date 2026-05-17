library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

-- Timer: smoke test for both ways of setting the period.
--
-- (A) generic-only: instantiate with MAX_NUMBER=10, leave maxLimit
--     unconnected so it defaults to MAX_NUMBER; expect a tick every
--     11 clocks (counter walks 0..10 inclusive then wraps).
-- (B) runtime maxLimit override: same DUT with MAX_NUMBER=10 (the
--     compile-time upper bound), drive maxLimit=4 at runtime; expect
--     a tick every 5 clocks.
--
-- The two sub-DUTs run from the same clock so the test fits in one
-- short simulation window.

entity tb_timer is
end tb_timer;

architecture testbench of tb_timer is
   constant CLK_PERIOD : time := 20 ns;   -- 50 MHz

   signal sClock            : std_logic := '0';
   signal sReset            : std_logic := '0';
   signal sSimulationActive : boolean   := true;

   signal sTickFromGeneric  : std_logic := '0';
   signal sTickFromRuntime  : std_logic := '0';

   signal sGenericTickCount : integer := 0;
   signal sRuntimeTickCount : integer := 0;
begin

   -- (A) generic-only: maxLimit defaults to MAX_NUMBER.
   DUT_GENERIC : entity work.Timer
      generic map (MAX_NUMBER => 10, TRIGGER_DURATION => 1)
      port map (clock          => sClock,
                reset          => sReset,
                timerTriggered => sTickFromGeneric);

   -- (B) runtime override: same compile-time range, smaller runtime limit.
   DUT_RUNTIME : entity work.Timer
      generic map (MAX_NUMBER => 10, TRIGGER_DURATION => 1)
      port map (clock          => sClock,
                reset          => sReset,
                maxLimit       => 4,
                timerTriggered => sTickFromRuntime);

   sClock <= not sClock after CLK_PERIOD / 2 when sSimulationActive;

   -- Count rising edges of each tick directly. Counting on the system
   -- clock instead would race the DUT's same-delta-cycle assignment to
   -- the tick signal and undercount by one.
   count_generic : process(sTickFromGeneric)
   begin
      if rising_edge(sTickFromGeneric) then
         sGenericTickCount <= sGenericTickCount + 1;
      end if;
   end process;

   count_runtime : process(sTickFromRuntime)
   begin
      if rising_edge(sTickFromRuntime) then
         sRuntimeTickCount <= sRuntimeTickCount + 1;
      end if;
   end process;

   STIMULUS : process
   begin
      -- Run for 110 clocks. With MAX_NUMBER=10 the generic-only Timer
      -- ticks every 11 clocks → 10 ticks. The runtime-override Timer
      -- ticks every 5 clocks → 22 ticks.
      wait for 110 * CLK_PERIOD;

      assert sGenericTickCount = 10
         report "generic-only Timer: expected 10 ticks in 110 clocks, got "
                & integer'image(sGenericTickCount)
         severity failure;

      assert sRuntimeTickCount = 22
         report "runtime-override Timer: expected 22 ticks in 110 clocks, got "
                & integer'image(sRuntimeTickCount)
         severity failure;

      sSimulationActive <= false;
      wait;
   end process;

end testbench;
