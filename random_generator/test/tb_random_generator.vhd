library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

-- Short-window testbench for the 4-digit random-hex display.
--
-- 10 ms run with inputButtons all-high (no freeze). 10 ms covers a
-- full mux rotation (2 ms per digit -> 8 ms for 0->1->2->3) with a
-- margin. The DUT's IS_SIM generic is set true so neoTRNG falls
-- back to its built-in LFSR (deterministic, simulator-friendly);
-- DIVIDER_MAX / ENABLE_HIGH are compressed so the ~140 ms hardware
-- refresh cycle becomes ~50 us in sim and a few refreshes fit in
-- the window.
--
-- Asserts:
--   (A) cableSelect is always one-hot-inverted (exactly one '0').
--   (B) sevenSegments is always one of the 16 valid hex encodings.
--   (C) By end-of-sim, every one of the four digits has been
--       selected at least once by the mux.

entity tb_random_generator is
end tb_random_generator;

architecture testbench of tb_random_generator is
   constant TEST_DURATION : time := 10 ms;

   -- Compress the hardware divider for sim. 2_500 cycles / 50 MHz =
   -- 50 us refresh; 200 cycles / 50 MHz = 4 us gate-open per refresh
   -- (the LFSR-mode neoTRNG produces a valid byte every few clocks,
   -- so 200 cycles is plenty to fill the 16-bit shift register).
   constant SIM_DIVIDER : integer := 2_500;
   constant SIM_GATE    : integer := 200;

   signal sClock50MHz       : std_logic := '0';
   signal sInputButtons     : std_logic_vector(3 downto 0) := (others => '1');
   signal sSevenSegments    : std_logic_vector(6 downto 0) := "1000000";  -- "0"
   signal sCableSelect      : std_logic_vector(3 downto 0) := "1110";
   signal sLeds             : std_logic_vector(3 downto 0);
   signal sSimulationActive : boolean := true;

   signal sSeenDigit0 : boolean := false;
   signal sSeenDigit1 : boolean := false;
   signal sSeenDigit2 : boolean := false;
   signal sSeenDigit3 : boolean := false;

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

   -- The 16 hex 0..F encodings emitted by the DUT's combinational decoder.
   function is_valid_7seg(v : std_logic_vector(6 downto 0)) return boolean is
   begin
      return v = "1000000" or v = "1111001" or v = "0100100" or v = "0110000"
          or v = "0011001" or v = "0010010" or v = "0000010" or v = "1111000"
          or v = "0000000" or v = "0010000" or v = "0001000" or v = "0000011"
          or v = "1000110" or v = "0100001" or v = "0000110" or v = "0001110";
   end function;
begin

   DUT : entity work.test(behavior)
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
            report "sevenSegments is not a valid hex encoding"
            severity failure;
         wait on sSevenSegments;
      end loop;
   end process;

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

   TEST_TERMINATOR : process
   begin
      sSimulationActive <= true;
      wait for TEST_DURATION;

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
