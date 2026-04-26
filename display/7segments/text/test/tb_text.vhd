library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

-- Short-window testbench for the 4-digit scrolling-text demo.
--
-- 10 ms run with inputButtons all-high (no scroll-pause) - long
-- enough to see the mux rotate through every digit at 2 ms/digit
-- (~8 ms full rotation), short enough to keep the VCD small for the
-- gallery PNG.
--
-- Asserts:
--   (A) cableSelect is always one-hot-inverted (exactly one '0').
--   (B) sevenSegments is never undefined ('-'/'X'/'U').
--   (C) By end-of-sim, every one of the four digits has been
--       selected at least once by the mux.

entity tb_text is
end tb_text;

architecture testbench of tb_text is
   constant TEST_DURATION : time := 10 ms;

   signal sClock50MHz       : std_logic := '0';
   signal sInputButtons     : std_logic_vector(3 downto 0) := (others => '1');
   signal sSevenSegments    : std_logic_vector(7 downto 0) := "11111111"; -- blank
   signal sCableSelect      : std_logic_vector(3 downto 0) := "1110";     -- digit 0
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

   function is_defined(v : std_logic_vector) return boolean is
   begin
      for i in v'range loop
         if v(i) /= '0' and v(i) /= '1' then
            return false;
         end if;
      end loop;
      return true;
   end function;
begin

   DUT : entity work.text(behavior)
      port map (
         clock         => sClock50MHz,
         inputButtons  => sInputButtons,
         sevenSegments => sSevenSegments,
         cableSelect   => sCableSelect);

   sClock50MHz <= not sClock50MHz after 10 ns when sSimulationActive;

   -- (A) cableSelect one-hot-inverted invariant.
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

   -- (B) sevenSegments must be a defined logic value (no 'X'/'U' on the bus).
   assert_B_defined : process
   begin
      wait for 200 ns;
      loop
         assert is_defined(sSevenSegments)
            report "sevenSegments contains an undefined bit"
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
