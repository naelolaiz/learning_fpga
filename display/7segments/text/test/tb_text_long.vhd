library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

-- Long-window testbench for the 4-digit scrolling-text demo.
--
-- Companion to `tb_text` (10 ms, mux + segment invariants only). This
-- one exercises the *scroll* and *freeze* behaviours by overriding the
-- DUT's SCROLL_MAX generic to 250_000 (5 ms scroll period in sim);
-- on hardware the default 8_000_000 keeps a comfortable 160 ms
-- scrolling rate.
--
-- Two phases:
--   Phase 1 (0..18 ms, inputButtons(0)='1', no pause). The scroll
--           counter wraps every 5 ms; the character on digit 0 is
--           sampled each time the mux selects it. By end of phase 1
--           the sample must have changed at least once - proving the
--           scroll counter is actually advancing the offset.
--   Phase 2 (18..40 ms, inputButtons(0)='0', pause held). Without the
--           freeze, the scroll counter would wrap at t=20 ms, 25, 30,
--           35 - all inside this window. The freeze must hold the
--           offset constant: every sample of digit 0 in this phase
--           must equal the latched value from the start of the phase.
--
-- This TB pairs with NO_WAVEFORM_TBS in the Makefile: the dump would
-- be unreadable when rendered at 40 ms, but the assertions still
-- gate CI via GHDL's --assert-level=error.

entity tb_text_long is
end tb_text_long;

architecture testbench of tb_text_long is
   constant TEST_DURATION : time := 40 ms;
   constant PHASE1_END    : time := 18 ms;
   constant SIM_SCROLL    : integer := 250_000;  -- 5 ms scroll period in sim

   signal sClock50MHz       : std_logic := '0';
   signal sInputButtons     : std_logic_vector(3 downto 0) := (others => '1');
   signal sSevenSegments    : std_logic_vector(7 downto 0) := "11111111";
   signal sCableSelect      : std_logic_vector(3 downto 0) := "1110";
   signal sSimulationActive : boolean := true;

   -- Phase tracking. 1 = scrolling, 2 = frozen, 0 = warmup or post.
   signal sPhase : integer range 0 to 2 := 0;

   -- What was last seen at digit 0; latched at every digit-0 mux window.
   signal sLastDigit0       : std_logic_vector(7 downto 0) := (others => '0');
   signal sLastDigit0Valid  : boolean := false;

   -- Latched at the *first* digit-0 sample in phase 2; later samples
   -- in phase 2 must equal it.
   signal sFreezeBaseline       : std_logic_vector(7 downto 0) := (others => '0');
   signal sFreezeBaselineValid  : boolean := false;

   -- Outcome flags checked at end-of-sim.
   signal sScrollObserved : boolean := false;
   signal sFreezeViolated : boolean := false;
begin

   DUT : entity work.text(behavior)
      generic map (SCROLL_MAX => SIM_SCROLL)
      port map (
         clock         => sClock50MHz,
         inputButtons  => sInputButtons,
         sevenSegments => sSevenSegments,
         cableSelect   => sCableSelect);

   sClock50MHz <= not sClock50MHz after 10 ns when sSimulationActive;

   -- Sample the byte on the bus every clock edge while digit 0 is
   -- selected. In phase 1, set sScrollObserved if the sample changes
   -- compared to the previous digit-0 sample. In phase 2, latch the
   -- first sample as the baseline and flag any later sample that
   -- diverges from it.
   sample_digit0 : process (sClock50MHz)
   begin
      if rising_edge(sClock50MHz) then
         if sCableSelect = "1110" then
            -- Phase 1: scroll-watch.
            if sPhase = 1 then
               if sLastDigit0Valid and sLastDigit0 /= sSevenSegments then
                  sScrollObserved <= true;
               end if;
            end if;

            -- Phase 2: freeze-watch.
            if sPhase = 2 then
               if not sFreezeBaselineValid then
                  sFreezeBaseline      <= sSevenSegments;
                  sFreezeBaselineValid <= true;
               elsif sSevenSegments /= sFreezeBaseline then
                  sFreezeViolated <= true;
               end if;
            end if;

            sLastDigit0      <= sSevenSegments;
            sLastDigit0Valid <= true;
         end if;
      end if;
   end process;

   TEST_TERMINATOR : process
   begin
      sSimulationActive <= true;

      -- Phase 1: button released, scroll active.
      sInputButtons <= (others => '1');
      sPhase        <= 1;
      wait for PHASE1_END;

      -- Phase 2: button(0) held, scroll frozen.
      sInputButtons <= "1110";
      sPhase        <= 2;
      wait for TEST_DURATION - PHASE1_END;

      sPhase <= 0;

      -- Verify scroll was actually observed in phase 1.
      assert sScrollObserved
         report "scroll did not advance: digit-0 character never changed during phase 1 ("
              & time'image(PHASE1_END) & ", SCROLL_MAX=" & integer'image(SIM_SCROLL) & ")"
         severity failure;

      -- Verify freeze actually held in phase 2.
      assert not sFreezeViolated
         report "freeze violated: digit-0 character changed during phase 2 with inputButtons(0)=0"
         severity failure;

      -- And that phase 2 actually saw at least one sample (sanity check).
      assert sFreezeBaselineValid
         report "phase 2 saw no digit-0 sample at all - TB scheduling bug?"
         severity failure;

      sSimulationActive <= false;
      wait;
   end process;

end testbench;
