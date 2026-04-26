library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

-- Debounce: bouncing-input case.
--
-- DEBOUNCE_LIMIT is overridden to 100 cycles (2 us at 50 MHz) so the
-- whole sequence fits in a short sim window. The DUT then needs the
-- input to stay at the new value for at least 100 ticks before
-- propagating it to the output.
--
-- Sequence:
--   t = 0..2 us       input held low (matches initial output)
--   t = 2..6 us       input bounces 0/1/0/1 every ~500 ns; no
--                     individual high stretch is long enough to cross
--                     DEBOUNCE_LIMIT, so output must stay 0.
--   t = 6 us onward   input held steady at 1; output should propagate
--                     once 2 us have elapsed (== 8 us absolute).
--
-- Asserts:
--   (A) o_Switch is 0 throughout the bouncing window (4 us).
--   (B) o_Switch is 1 once the input has been steady-high for >= 2 us.

entity tb_debounce_bounce is
end tb_debounce_bounce;

architecture testbench of tb_debounce_bounce is
   constant SIM_LIMIT : integer := 100;             -- 100 cycles = 2 us
   constant TEST_DURATION : time := 12 us;

   signal sClock50MHz       : std_logic := '0';
   signal sSwitchIn         : std_logic := '0';
   signal sSwitchOut        : std_logic;
   signal sSimulationActive : boolean := true;

   signal sBouncingPhase    : boolean := false;
   signal sBouncingViolated : boolean := false;
begin

   DUT : entity work.Debounce
      generic map (DEBOUNCE_LIMIT => SIM_LIMIT)
      port map (
         i_Clk    => sClock50MHz,
         i_Switch => sSwitchIn,
         o_Switch => sSwitchOut);

   sClock50MHz <= not sClock50MHz after 10 ns when sSimulationActive;

   -- (A) o_Switch must stay at 0 throughout the bouncing phase.
   -- Check explicitly for '1' rather than "not '0'": sSwitchOut starts
   -- as 'U' before the DUT drives it, which otherwise would trip a
   -- false positive at t=0.
   bouncing_watch : process (sSwitchOut)
   begin
      if sBouncingPhase and sSwitchOut = '1' then
         sBouncingViolated <= true;
      end if;
   end process;

   STIMULUS : process
   begin
      -- Initial steady-low window so the DUT has reached its idle state.
      sSwitchIn <= '0';
      wait for 2 us;

      -- Bouncing phase: 4 short pulses high (~500 ns each), each well
      -- below the 2 us debounce limit.
      sBouncingPhase <= true;
      for i in 1 to 4 loop
         sSwitchIn <= '1';
         wait for 500 ns;
         sSwitchIn <= '0';
         wait for 500 ns;
      end loop;
      sBouncingPhase <= false;

      -- Steady-high phase. Allow >= DEBOUNCE_LIMIT plus a margin.
      sSwitchIn <= '1';
      wait for 4 us;

      -- (B) o_Switch must have propagated to 1 by now.
      assert sSwitchOut = '1'
         report "o_Switch did not propagate to 1 after sustained press"
         severity failure;

      -- (A) Bouncing must not have leaked to the output.
      assert not sBouncingViolated
         report "o_Switch went high during the bouncing window"
         severity failure;

      sSimulationActive <= false;
      wait;
   end process;

end testbench;
