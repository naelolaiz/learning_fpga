LIBRARY ieee;

USE ieee.std_logic_1164.ALL;
use ieee.numeric_std.ALL;

entity counter is
   port (
         clock : in std_logic;
         sevenSegments : out std_logic_vector(6 downto 0);
         cableSelect : out std_logic_vector(3 downto 0));
end counter;

architecture behavior of counter is
   constant NUMBER_OF_DIGITS : integer := 4;
   constant BITS_PER_NIBBLE  : integer := 4;
   constant COUNTER_MAX      : integer := 3_125_000;  -- ticks every 3.125E6 / 50E6 = 62.5 ms
   constant MUX_MAX          : integer := 100_000;    -- ticks every 100E3 / 50E6 = 2 ms

   -- Explicit-width unsigned instead of `integer range 0 to N`. GHDL's
   -- plugin for yosys often widens integer subtypes to the host-integer
   -- width (32 bits) regardless of range, so the counters below were
   -- synthesising as 32-bit registers + 32-bit comparators. Matches the
   -- Verilog mirror's [22:0] / [17:0] / [1:0] declarations.
   signal counterForCounter : unsigned(22 downto 0) := (others => '0');
   signal counterForMux     : unsigned(17 downto 0) := (others => '0');
   signal numberToDisplay   : std_logic_vector(NUMBER_OF_DIGITS*BITS_PER_NIBBLE - 1 downto 0) := (others => '0');
   signal enabledDigit      : unsigned(1 downto 0) := (others => '0');
   signal currentDigitValue : std_logic_vector(BITS_PER_NIBBLE-1 downto 0) := (others => '0');

begin
   tick: process(clock)
   begin
      if rising_edge(clock) then

         if counterForMux = to_unsigned(MUX_MAX - 1, counterForMux'length) then
            counterForMux <= (others => '0');
            if enabledDigit = to_unsigned(NUMBER_OF_DIGITS - 1, enabledDigit'length) then
               enabledDigit <= (others => '0');
            else
               enabledDigit <= enabledDigit + 1;
            end if;
         else
            counterForMux <= counterForMux + 1;
         end if;

         if counterForCounter = to_unsigned(COUNTER_MAX - 1, counterForCounter'length) then
            counterForCounter <= (others => '0');
            numberToDisplay   <= std_logic_vector(unsigned(numberToDisplay) + 1);
         else
            counterForCounter <= counterForCounter + 1;
         end if;
      end if;
   end process;

   -- Anode mux: a direct with-select synthesises as a 2:4 decoder,
   -- without the intermediate one-hot + NOT pair the previous
   -- `tempNibble` construction produced.
   with enabledDigit select cableSelect <=
      "1110" when "00",
      "1101" when "01",
      "1011" when "10",
      "0111" when others;

   -- Pick the nibble for the currently-active digit. `case` on
   -- enabledDigit synthesises as a parallel 4:1 mux; the previous
   -- dynamic-slice expression was equivalent but read less cleanly.
   nibble_select : process (enabledDigit, numberToDisplay)
   begin
      case enabledDigit is
         when "00"   => currentDigitValue <= numberToDisplay( 3 downto  0);
         when "01"   => currentDigitValue <= numberToDisplay( 7 downto  4);
         when "10"   => currentDigitValue <= numberToDisplay(11 downto  8);
         when others => currentDigitValue <= numberToDisplay(15 downto 12);
      end case;
   end process;

   -- 7-segment decode: with-select synthesises as a parallel 16:1
   -- mux tree. The previous when-else cascade produced a chain of
   -- 2:1 muxes — functionally identical but a taller netlist.
   with currentDigitValue select sevenSegments <=
      "1000000" when "0000",
      "1111001" when "0001",
      "0100100" when "0010",
      "0110000" when "0011",
      "0011001" when "0100",
      "0010010" when "0101",
      "0000010" when "0110",
      "1111000" when "0111",
      "0000000" when "1000",
      "0010000" when "1001",
      "0001000" when "1010",
      "0000011" when "1011",
      "1000110" when "1100",
      "0100001" when "1101",
      "0000110" when "1110",
      "0001110" when others;
end behavior;
