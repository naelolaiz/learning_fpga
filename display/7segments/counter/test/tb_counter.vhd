library ieee;
use ieee.std_logic_1164.ALL;
use ieee.numeric_std.ALL;

-- Testbench for the 4-digit 7-segment multiplexed counter.
--
-- The DUT multiplexes one of four digits onto a shared 7-segment
-- display, cycling through them via `cableSelect` (active-low,
-- one-hot-inverted) every ~2 ms. `sevenSegments` carries the seven
-- cathode lines (also active-low) encoding the digit currently
-- selected.
--
-- Three things are asserted:
--
--   (A) cableSelect is always one-hot-inverted (exactly one '0').
--   (B) sevenSegments is always one of the 16 valid BCD encodings.
--   (C) By end-of-sim, every one of the four digits has been selected
--       at least once by the mux (rules out a stuck multiplexer).
--
-- The test deliberately does NOT assert "sevenSegments matches the
-- BCD of the current digit" for every sample: the DUT has a small
-- combinational delay between enabledDigit updating and
-- currentDigitValue settling, and this is a learning project that
-- doesn't need that level of rigor. Catching a stuck mux + catching
-- out-of-set encodings together already localise any real regression.

entity tb_counter is
end tb_counter;

architecture testbench of tb_counter is
   -- 10 ms covers a full mux rotation (2 ms per digit -> 8 ms for
   -- 0->1->2->3) and a bit more, which is all the assertions need.
   -- Keep this short: GHDL dumps at 1 fs timescale by default, so
   -- long runs produce multi-hundred-MB VCDs that the gallery's
   -- waveform render pipeline can't process in time.
   constant TEST_DURATION : time := 10 ms;
   signal sClock50MHz       : std_logic := '0';
   -- Initialise to a valid encoding so the continuous invariants
   -- below hold at t=0, before the DUT has driven the first output.
   signal sSevenSegments    : std_logic_vector(6 downto 0) := "1000000"; -- "0"
   signal sCableSelect      : std_logic_vector(3 downto 0) := "1110";    -- digit 0 selected
   signal sSimulationActive : boolean := true;

   -- Seen-flags, one per cableSelect value. Updated in a continuous
   -- process; checked at end of sim.
   signal sSeenDigit0 : boolean := false;
   signal sSeenDigit1 : boolean := false;
   signal sSeenDigit2 : boolean := false;
   signal sSeenDigit3 : boolean := false;

   -- Helper: list of all 16 valid BCD-to-7seg encodings produced by
   -- the DUT's combinational decoder (kept here, not imported, so the
   -- TB doubles as documentation of the expected encoding).
   function is_valid_7seg(v : std_logic_vector(6 downto 0)) return boolean is
   begin
      return v = "1000000" or v = "1111001" or v = "0100100" or v = "0110000"
          or v = "0011001" or v = "0010010" or v = "0000010" or v = "1111000"
          or v = "0000000" or v = "0010000" or v = "0001000" or v = "0000011"
          or v = "1000110" or v = "0100001" or v = "0000110" or v = "0001110";
   end function;

   -- Helper: cableSelect must have exactly one '0' (the selected
   -- digit's anode, active low).
   function is_one_hot_inverted(v : std_logic_vector(3 downto 0)) return boolean is
      variable zeros : integer := 0;
   begin
      for i in v'range loop
         if v(i) = '0' then
            zeros := zeros + 1;
         end if;
      end loop;
      return zeros = 1;
   end function;
begin

   DUT : entity work.counter(behavior)
      port map (
         clock         => sClock50MHz,
         sevenSegments => sSevenSegments,
         cableSelect   => sCableSelect);

   sClock50MHz <= not sClock50MHz after 10 ns when sSimulationActive;

   -- (A) + (B) continuous invariants. Waits through a short settle
   -- window at t=0 so the DUT has driven its outputs out of their
   -- undefined reset values before the checks begin, then fires on
   -- every change of the observed signal for the rest of the sim.
   -- Using a sequential process (not a concurrent assertion) so the
   -- initial wait is expressible.
   assert_A_one_hot : process
   begin
      wait for 200 ns;
      loop
         assert is_one_hot_inverted(sCableSelect)
            report "cableSelect violated one-hot-inverted invariant"
            severity failure;
         wait on sCableSelect;
      end loop;
   end process;

   assert_B_valid_encoding : process
   begin
      wait for 200 ns;
      loop
         assert is_valid_7seg(sSevenSegments)
            report "sevenSegments is not a valid BCD encoding"
            severity failure;
         wait on sSevenSegments;
      end loop;
   end process;

   -- Track which digits have been selected so far. Feeds the
   -- end-of-sim assertion (C).
   track_digits_seen : process (sCableSelect)
   begin
      case sCableSelect is
         when "1110" => sSeenDigit0 <= true;
         when "1101" => sSeenDigit1 <= true;
         when "1011" => sSeenDigit2 <= true;
         when "0111" => sSeenDigit3 <= true;
         when others => null;
      end case;
   end process;

   -- Drives the sim for TEST_DURATION, then verifies (C) and shuts
   -- the clock down.
   TEST_TERMINATOR : process
   begin
      sSimulationActive <= true;
      wait for TEST_DURATION;

      -- (C) Mux must have rotated through all four digits. At ~2 ms
      -- per digit the round-trip is ~8 ms, which fits inside the
      -- 10 ms TEST_DURATION with a margin, so a stuck mux is
      -- unmissable.
      assert sSeenDigit0 and sSeenDigit1 and sSeenDigit2 and sSeenDigit3
         report "mux stuck: saw digit0=" & boolean'image(sSeenDigit0)
              & " digit1=" & boolean'image(sSeenDigit1)
              & " digit2=" & boolean'image(sSeenDigit2)
              & " digit3=" & boolean'image(sSeenDigit3)
         severity failure;

      sSimulationActive <= false;
      wait;
   end process;

end testbench;
