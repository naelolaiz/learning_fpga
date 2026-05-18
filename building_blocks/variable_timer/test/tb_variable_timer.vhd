library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

-- VariableTimer: serial-load programs a smaller limit at runtime.
--
-- MAX_NUMBER is set to 100 so the unconstrained default would tick
-- every 101 clocks. The stimulus then shifts in the bit pattern for
-- 9 (so the runtime limit becomes 9 → tick every 10 clocks) and
-- counts the ticks in the post-load window.

entity tb_variable_timer is
end tb_variable_timer;

architecture testbench of tb_variable_timer is
   constant CLK_PERIOD : time := 20 ns;

   signal sClock            : std_logic := '0';
   signal sReset            : std_logic := '0';
   signal sSetMax           : std_logic := '0';
   signal sDataIn           : std_logic := '0';
   signal sTick             : std_logic := '0';
   signal sSimulationActive : boolean   := true;

   signal sTickCount        : integer   := 0;
   -- Snapshot of sTickCount at the start of the measurement window;
   -- we compare against (final - snapshot) instead of resetting the
   -- counter, which would otherwise add a second driver to the
   -- signal and fail elaboration with "several sources for
   -- unresolved signal".
   signal sBaselineCount    : integer   := 0;

   -- 64-bit binary representation of the desired runtime limit (9),
   -- MSB-first — matches how the shift register lands the value
   -- after 64 successive shifts.
   constant NEW_LIMIT_BITS  : std_logic_vector(63 downto 0) :=
       std_logic_vector(to_unsigned(9, 64));
begin

   DUT : entity work.VariableTimer
      generic map (MAX_NUMBER => 100, TRIGGER_DURATION => 1)
      port map (clock          => sClock,
                reset          => sReset,
                setMax         => sSetMax,
                dataIn         => sDataIn,
                timerTriggered => sTick);

   sClock <= not sClock after CLK_PERIOD / 2 when sSimulationActive;

   count_ticks : process(sTick)
   begin
      if rising_edge(sTick) then
         sTickCount <= sTickCount + 1;
      end if;
   end process;

   STIMULUS : process
   begin
      sReset <= '1';
      wait for 2 * CLK_PERIOD;
      sReset <= '0';

      -- Shift the new limit (= 9) in MSB-first, one bit per clock.
      -- The first setMax='1' clock clears the shift register, so we
      -- need 64 shifts of dataIn to land all 64 bits.
      sSetMax <= '1';
      wait until rising_edge(sClock);   -- first clock: register cleared
      for i in 63 downto 0 loop
         sDataIn <= NEW_LIMIT_BITS(i);
         wait until rising_edge(sClock);
      end loop;
      sSetMax <= '0';
      sDataIn <= '0';

      -- Reset our tick counter at the start of the measurement window
      -- by waiting a few clocks (the new limit needs one clock to
      -- propagate the inner Timer out of reset).
      wait for 2 * CLK_PERIOD;
      sBaselineCount <= sTickCount;

      -- Measurement window: 200 clocks. With runtime limit = 9 the
      -- Timer ticks every 10 clocks → 20 ticks.
      wait for 200 * CLK_PERIOD;

      assert (sTickCount - sBaselineCount) = 20
         report "VariableTimer with runtime limit=9 should tick 20 times in 200 clocks, got "
                & integer'image(sTickCount)
         severity failure;

      sSimulationActive <= false;
      wait;
   end process;

end testbench;
