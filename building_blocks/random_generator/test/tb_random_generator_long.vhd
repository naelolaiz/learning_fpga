library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

-- Long-window testbench for the random-hex display.
--
-- Companion to `tb_random_generator` (5 ms, mux + encoding invariants).
-- This one exercises the *update* and *freeze* behaviours by running
-- long enough to observe several refresh cycles, then holding the
-- freeze button for the second half.
--
-- IS_SIM is true so neoTRNG uses its built-in LFSR (deterministic,
-- simulator-friendly). DIVIDER_MAX / ENABLE_HIGH are compressed so
-- the ~140 ms hardware refresh becomes ~50 us in sim.
--
-- Two phases:
--   Phase 1 (0..6 ms, inputButtons(0)='1'). The character on digit 0
--           is sampled each time the mux selects it. By end of phase
--           1, the sample must have changed at least once - proves
--           the shift register is taking new bytes from neoTRNG.
--   Phase 2 (6..12 ms, inputButtons(0)='0'). Without freeze, neoTRNG
--           would keep refreshing numberToDisplay (~120 refreshes in
--           this window). With freeze, every sample of digit 0 must
--           equal the first sample latched at the start of the phase.

entity tb_random_generator_long is
end tb_random_generator_long;

architecture testbench of tb_random_generator_long is
   constant TEST_DURATION : time := 12 ms;
   constant PHASE1_END    : time := 6 ms;

   -- SIM_GATE = SIM_DIVIDER means counterForGenerator never reaches
   -- ENABLE_HIGH (it wraps first), so the gate is held open for the
   -- whole sim. This keeps the underlying LFSR running continuously
   -- — neoTRNG resets its internal sim-LFSR whenever enable_i goes
   -- low, so a gating sim would produce identical bytes every cycle
   -- and numberToDisplay would reach steady state immediately. With
   -- the gate always open, the LFSR cycles through varied state and
   -- numberToDisplay keeps updating, which is what the test needs.
   constant SIM_DIVIDER : integer := 2_500;
   constant SIM_GATE    : integer := SIM_DIVIDER;

   signal sClock50MHz       : std_logic := '0';
   signal sInputButtons     : std_logic_vector(3 downto 0) := (others => '1');
   signal sSevenSegments    : std_logic_vector(6 downto 0) := "1000000";
   signal sCableSelect      : std_logic_vector(3 downto 0) := "1110";
   signal sLeds             : std_logic_vector(3 downto 0);
   signal sSimulationActive : boolean := true;

   signal sPhase : integer range 0 to 2 := 0;

   signal sLastDigit0       : std_logic_vector(6 downto 0) := (others => '0');
   signal sLastDigit0Valid  : boolean := false;

   signal sFreezeBaseline       : std_logic_vector(6 downto 0) := (others => '0');
   signal sFreezeBaselineValid  : boolean := false;

   signal sUpdateObserved : boolean := false;
   signal sFreezeViolated : boolean := false;
begin

   DUT : entity work.random_generator(behavior)
      generic map (
         IS_SIM      => true,
         DIVIDER_MAX => SIM_DIVIDER,
         ENABLE_HIGH => SIM_GATE)
      port map (
         clock         => sClock50MHz,
         inputButtons  => sInputButtons,
         sevenSegments => sSevenSegments,
         cableSelect   => sCableSelect,
         leds          => sLeds);

   sClock50MHz <= not sClock50MHz after 10 ns when sSimulationActive;

   sample_digit0 : process (sClock50MHz)
   begin
      if rising_edge(sClock50MHz) then
         if sCableSelect = "1110" then
            if sPhase = 1 then
               if sLastDigit0Valid and sLastDigit0 /= sSevenSegments then
                  sUpdateObserved <= true;
               end if;
            end if;

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

      sInputButtons <= (others => '1');
      sPhase        <= 1;
      wait for PHASE1_END;

      sInputButtons <= "1110";
      sPhase        <= 2;
      wait for TEST_DURATION - PHASE1_END;

      sPhase <= 0;

      assert sUpdateObserved
         report "shift register stuck: digit-0 nibble never changed during phase 1 ("
              & time'image(PHASE1_END) & ", DIVIDER=" & integer'image(SIM_DIVIDER) & ")"
         severity failure;

      assert not sFreezeViolated
         report "freeze violated: digit-0 nibble changed during phase 2 with inputButtons(0)=0"
         severity failure;

      assert sFreezeBaselineValid
         report "phase 2 saw no digit-0 sample at all - TB scheduling bug?"
         severity failure;

      sSimulationActive <= false;
      wait;
   end process;

end testbench;
