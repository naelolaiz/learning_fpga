library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

-- Scrolling text on a 4-digit common-anode 7-segment display.
--
-- Two clock-derived counters drive the display:
--   counterForMux       wraps every ~2 ms, advances enabledDigit
--   counterForScrolling wraps every ~160 ms, advances stringOffset
--
-- The active digit picks one character from stringToPrint at
-- (stringOffset + 3 - enabledDigit) so the leftmost physical digit
-- shows the earliest character - i.e. the text reads left to right
-- while the mux rotates 0->1->2->3.
--
-- inputButtons(0) is wired as an active-low scroll-pause: when
-- pressed, the scroll-tick freezes (counterForScrolling stops
-- accumulating), so the same characters stay on the display. The mux
-- keeps running so the digits stay lit.
--
-- sevenSegments is 8 bits: bits(6 downto 0) drive the seven cathodes,
-- bit 7 is the decimal point. The '.' character lights only the DP.
--
-- Generics:
--   SCROLL_MAX  Period of the scroll tick in clock cycles. Defaulted
--               for hardware (160 ms scroll period); the long testbench
--               overrides to a smaller value so freeze-vs-tick can be
--               exercised in a short sim window.
entity text is
   generic (
      SCROLL_MAX : integer := 8_000_000  -- 8E6 / 50E6 = 160 ms per scroll tick on hardware
   );
   port (
      clock         : in  std_logic;
      inputButtons  : in  std_logic_vector(3 downto 0);
      sevenSegments : out std_logic_vector(7 downto 0);
      cableSelect   : out std_logic_vector(3 downto 0));
end text;

architecture behavior of text is
   constant stringToPrint : string := "_-+-_- Hello FPGA Wworld _-+-==- ";

   constant MUX_MAX : integer := 100_000;  -- 100E3 / 50E6 = 2 ms per digit

   -- Explicit-width unsigned instead of `integer range`. GHDL's plugin
   -- for yosys widens integer subtypes to host-int width regardless of
   -- range; matches the convention in 7segments/counter.
   signal counterForMux       : unsigned(17 downto 0) := (others => '0'); -- holds MUX_MAX
   signal counterForScrolling : unsigned(31 downto 0) := (others => '0'); -- holds any SCROLL_MAX in 32 bits
   signal enabledDigit        : unsigned(1 downto 0)  := (others => '0');
   signal stringOffset        : integer range 0 to stringToPrint'length - 1 := 0;
   signal charForDigit        : character := nul;
begin

   -- Mux + scroll counters. inputButtons(0) is active-low; held = scroll paused.
   -- inputButtons(1..3) are pinned in the .qsf for future use but read here
   -- only via the unused-signal warning suppression of leaving them dangling.
   tick : process(clock)
   begin
      if rising_edge(clock) then
         -- Mux tick (always running, regardless of pause).
         if counterForMux = to_unsigned(MUX_MAX - 1, counterForMux'length) then
            counterForMux <= (others => '0');
            enabledDigit  <= enabledDigit + 1;
         else
            counterForMux <= counterForMux + 1;
         end if;

         -- Scroll tick: paused while inputButtons(0) is held low.
         if inputButtons(0) = '1' then
            if counterForScrolling = to_unsigned(SCROLL_MAX - 1, counterForScrolling'length) then
               counterForScrolling <= (others => '0');
               if stringOffset = stringToPrint'length - 1 then
                  stringOffset <= 0;
               else
                  stringOffset <= stringOffset + 1;
               end if;
            else
               counterForScrolling <= counterForScrolling + 1;
            end if;
         end if;
      end if;
   end process;

   -- Anode mux: 2:4 active-low decoder. Direct with-select so yosys+ghdl
   -- emits a clean decoder instead of an intermediate one-hot+NOT.
   with enabledDigit select cableSelect <=
      "1110" when "00",
      "1101" when "01",
      "1011" when "10",
      "0111" when others;

   -- Pick the character to display on the currently-active digit. The
   -- mux rotates digit 0..3 left-to-right but text reads right-to-left
   -- across the *physical* layout; (3 - enabledDigit) reverses the
   -- selection so the leftmost digit shows the earliest character of
   -- the visible window. The +1 turns VHDL's 1-based string indexing
   -- into the 0-based offset arithmetic.
   char_select : process(enabledDigit, stringOffset)
      variable reversedDigit : integer;
      variable index         : integer;
   begin
      reversedDigit := 3 - to_integer(enabledDigit);
      index         := ((stringOffset + reversedDigit) mod stringToPrint'length) + 1;
      charForDigit  <= stringToPrint(index);
   end process;

   -- ASCII-to-7-segment decode. Bit 7 (MSB) is the decimal point;
   -- bits(6 downto 0) are the cathodes a..g (active-low, common-anode).
   ascii_to_7segment : process(charForDigit)
   begin
      case charForDigit is
         when '0'    => sevenSegments <= "11000000";
         when '1'    => sevenSegments <= "11111001";
         when '2'    => sevenSegments <= "10100100";
         when '3'    => sevenSegments <= "10110000";
         when '4'    => sevenSegments <= "10011001";
         when '5'    => sevenSegments <= "10010010";
         when '6'    => sevenSegments <= "10000010";
         when '7'    => sevenSegments <= "11111000";
         when '8'    => sevenSegments <= "10000000";
         when '9'    => sevenSegments <= "10010000";
         when '='    => sevenSegments <= "11110110";
         when '+'    => sevenSegments <= "11111110";
         when '-'    => sevenSegments <= "10111111";
         when '_'    => sevenSegments <= "11110111";
         when ' '    => sevenSegments <= "11111111";
         when '''    => sevenSegments <= "11111101";
         when ','    => sevenSegments <= "11111011";
         when '.'    => sevenSegments <= "01111111";
         when 'A'    => sevenSegments <= "10001000";
         when 'a'    => sevenSegments <= "00100000";
         when 'B'    => sevenSegments <= "10000011";
         when 'b'    => sevenSegments <= "10000011";
         when 'C'    => sevenSegments <= "11000110";
         when 'c'    => sevenSegments <= "10100111";
         when 'D'    => sevenSegments <= "10100001";
         when 'd'    => sevenSegments <= "10100001";
         when 'E'    => sevenSegments <= "10000110";
         when 'e'    => sevenSegments <= "10000100";
         when 'F'    => sevenSegments <= "10001110";
         when 'f'    => sevenSegments <= "10001110";
         when 'G'    => sevenSegments <= "10010000";
         when 'g'    => sevenSegments <= "10010000";
         when 'H'    => sevenSegments <= "10001001";
         when 'h'    => sevenSegments <= "10001011";
         when 'I'    => sevenSegments <= "11001111";
         when 'i'    => sevenSegments <= "11101111";
         when 'J'    => sevenSegments <= "11110001";
         when 'j'    => sevenSegments <= "11110001";
         when 'L'    => sevenSegments <= "11000111";
         when 'l'    => sevenSegments <= "11001111";
         when 'M'    => sevenSegments <= "11001100";  -- first half of a 2-digit M
         when 'm'    => sevenSegments <= "11011000";  -- second half
         when 'N'    => sevenSegments <= "10101011";
         when 'n'    => sevenSegments <= "10101011";
         when 'O'    => sevenSegments <= "11000000";
         when 'o'    => sevenSegments <= "10100011";
         when 'P'    => sevenSegments <= "10001100";
         when 'p'    => sevenSegments <= "10001100";
         when 'Q'    => sevenSegments <= "01000000";
         when 'q'    => sevenSegments <= "01000000";
         when 'R'    => sevenSegments <= "10101111";
         when 'r'    => sevenSegments <= "10101111";
         when 'S'    => sevenSegments <= "10010010";
         when 's'    => sevenSegments <= "10010010";
         when 'T'    => sevenSegments <= "10001111";
         when 't'    => sevenSegments <= "10001111";
         when 'U'    => sevenSegments <= "11000001";
         when 'u'    => sevenSegments <= "11100011";
         when 'W'    => sevenSegments <= "11000011";  -- first half of a 2-digit W
         when 'w'    => sevenSegments <= "11100001";  -- second half
         when 'X'    => sevenSegments <= "11110000";  -- first half of a 2-digit X
         when 'x'    => sevenSegments <= "11000110";  -- second half
         when 'Y'    => sevenSegments <= "10011011";  -- first half of a 2-digit y
         when 'y'    => sevenSegments <= "10101101";  -- second half
         when 'Z'    => sevenSegments <= "10100100";
         when 'z'    => sevenSegments <= "10100100";
         when others => sevenSegments <= "11111111";
      end case;
   end process;
end behavior;
