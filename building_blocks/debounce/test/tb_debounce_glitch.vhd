library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

-- Debounce: short-glitch-rejection case.
--
-- DEBOUNCE_LIMIT is overridden to 100 cycles (2 us at 50 MHz). A
-- single ~600 ns glitch — well below the 2 us limit — must NOT
-- propagate to the output.
--
-- Sequence:
--   t = 0..2 us       input held low; output settles low.
--   t = 2..2.6 us     input goes high for 600 ns (glitch).
--   t = 2.6 us..end   input back to low.
--
-- Asserts:
--   (A) o_Switch stays at 0 for the entire run.

entity tb_debounce_glitch is
end tb_debounce_glitch;

architecture testbench of tb_debounce_glitch is
   constant SIM_LIMIT     : integer := 100;
   constant TEST_DURATION : time := 8 us;

   signal sClock50MHz       : std_logic := '0';
   signal sSwitchIn         : std_logic := '0';
   signal sSwitchOut        : std_logic;
   signal sSimulationActive : boolean := true;

   signal sGlitchLeaked : boolean := false;
begin

   DUT : entity work.Debounce
      generic map (DEBOUNCE_LIMIT => SIM_LIMIT)
      port map (
         i_Clk    => sClock50MHz,
         i_Switch => sSwitchIn,
         o_Switch => sSwitchOut);

   sClock50MHz <= not sClock50MHz after 10 ns when sSimulationActive;

   -- Check explicitly for '1' rather than "not '0'" — sSwitchOut starts
   -- as 'U' before the DUT drives it on the first clock edge, and 'U /= 0'
   -- would otherwise trip a false positive.
   watch : process (sSwitchOut)
   begin
      if sSwitchOut = '1' then
         sGlitchLeaked <= true;
      end if;
   end process;

   STIMULUS : process
   begin
      sSwitchIn <= '0';
      wait for 2 us;

      sSwitchIn <= '1';
      wait for 600 ns;        -- well under DEBOUNCE_LIMIT (2 us)

      sSwitchIn <= '0';
      wait for TEST_DURATION - 2 us - 600 ns;

      assert not sGlitchLeaked
         report "o_Switch went high; a sub-DEBOUNCE_LIMIT glitch leaked through"
         severity failure;

      sSimulationActive <= false;
      wait;
   end process;

end testbench;
