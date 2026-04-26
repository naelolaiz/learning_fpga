library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

-- 4-digit hex display of a random number generated on-chip by neoTRNG.
--
-- A slow gating divider (DIVIDER_MAX cycles) pulses neoTRNG's enable
-- input high for ENABLE_HIGH cycles every period; new random bytes are
-- shifted into numberToDisplay on each rising edge of valid_o while
-- the gate is open. Between pulses the displayed value is stable.
--
-- The 50 MHz clock also drives a 4-digit anode mux at ~2 ms/digit,
-- decoded inline as a hex 0..F to seven-segment table.
--
-- Generics:
--   IS_SIM       false on hardware (real ring-oscillator entropy);
--                true in simulation, where neoTRNG falls back to its
--                built-in LFSR so the testbench is deterministic.
--   DIVIDER_MAX  Period of the gating divider in clock cycles.
--                Defaulted for hardware (140 ms cycle); the testbench
--                overrides to ~1 ms so multiple update cycles fit in
--                a short sim window.
--   ENABLE_HIGH  How many cycles per period the gate is open. Must
--                be < DIVIDER_MAX. Long enough that neoTRNG emits at
--                least the two valid bytes needed to refresh the
--                16-bit shift register.
--
-- inputButtons(0) is wired as an active-low freeze: while held, new
-- bytes from neoTRNG are ignored and the displayed value sticks.
-- Buttons 1..3 are pinned in the .qsf for future use.
entity test is
   generic (
      IS_SIM      : boolean := false;
      DIVIDER_MAX : integer := 7_000_000;  -- 7E6  / 50E6 = 140 ms cycle on hardware
      ENABLE_HIGH : integer := 1000        -- 20 us gate open per cycle on hardware
   );
   port (
      clock         : in  std_logic;
      inputButtons  : in  std_logic_vector(3 downto 0);
      sevenSegments : out std_logic_vector(6 downto 0);
      cableSelect   : out std_logic_vector(3 downto 0);
      leds          : out std_logic_vector(3 downto 0));
end test;

architecture behavior of test is
   constant MUX_MAX : integer := 100_000;  -- 100E3 / 50E6 = 2 ms per digit

   -- Widths that comfortably hold the maxima above. For DIVIDER_MAX we
   -- allow up to 32 bits - generic-driven, so a synth pass with a
   -- larger value still fits.
   signal counterForMux        : unsigned(17 downto 0) := (others => '0'); -- holds MUX_MAX
   signal counterForGenerator  : unsigned(31 downto 0) := (others => '0'); -- holds DIVIDER_MAX

   signal enabledDigit         : unsigned(1 downto 0) := (others => '0');
   signal numberToDisplay      : std_logic_vector(15 downto 0) := (others => '0');
   signal currentDigitValue    : std_logic_vector(3 downto 0)  := (others => '0');

   signal sClockForRandom      : std_logic := '0';
   signal sRndData             : std_ulogic_vector(7 downto 0) := (others => '0');
   signal sRndValid            : std_ulogic := '0';
   signal sRndValidPrev        : std_ulogic := '0';

   component neoTRNG is
      generic (
         NUM_CELLS     : natural;
         NUM_INV_START : natural;
         NUM_INV_INC   : natural;
         NUM_INV_DELAY : natural;
         POST_PROC_EN  : boolean;
         IS_SIM        : boolean
      );
      port (
         clk_i    : in  std_ulogic;
         enable_i : in  std_ulogic;
         data_o   : out std_ulogic_vector(7 downto 0);
         valid_o  : out std_ulogic
      );
   end component;
begin

   -- Gating divider: enable_i is high for ENABLE_HIGH cycles, low for
   -- (DIVIDER_MAX - ENABLE_HIGH). On hardware that's ~20 us on / ~140 ms off,
   -- giving the entropy cells time to settle and producing visible-scale
   -- updates on the display.
   gate : process(clock)
   begin
      if rising_edge(clock) then
         if counterForGenerator = to_unsigned(DIVIDER_MAX - 1, counterForGenerator'length) then
            counterForGenerator <= (others => '0');
         else
            counterForGenerator <= counterForGenerator + 1;
         end if;

         if counterForGenerator < to_unsigned(ENABLE_HIGH, counterForGenerator'length) then
            sClockForRandom <= '1';
         else
            sClockForRandom <= '0';
         end if;
      end if;
   end process;

   leds(0)          <= sClockForRandom;
   leds(3 downto 1) <= (others => '0');

   neoTRNG_inst : neoTRNG
      generic map (
         NUM_CELLS     => 3,
         NUM_INV_START => 5,
         NUM_INV_INC   => 2,
         NUM_INV_DELAY => 2,
         POST_PROC_EN  => true,
         IS_SIM        => IS_SIM)
      port map (
         clk_i    => clock,
         enable_i => sClockForRandom,
         data_o   => sRndData,
         valid_o  => sRndValid);

   -- Synchronous edge detector on sRndValid: shift in a fresh byte
   -- whenever neoTRNG signals valid data, except while the freeze
   -- button (inputButtons(0)) is held low.
   shift_in : process(clock)
   begin
      if rising_edge(clock) then
         sRndValidPrev <= sRndValid;
         if sRndValid = '1' and sRndValidPrev = '0' and inputButtons(0) = '1' then
            numberToDisplay <= std_logic_vector(sRndData) & numberToDisplay(15 downto 8);
         end if;
      end if;
   end process;

   -- Mux tick.
   mux_tick : process(clock)
   begin
      if rising_edge(clock) then
         if counterForMux = to_unsigned(MUX_MAX - 1, counterForMux'length) then
            counterForMux <= (others => '0');
            enabledDigit  <= enabledDigit + 1;
         else
            counterForMux <= counterForMux + 1;
         end if;
      end if;
   end process;

   -- Anode mux: 2:4 active-low decoder.
   with enabledDigit select cableSelect <=
      "1110" when "00",
      "1101" when "01",
      "1011" when "10",
      "0111" when others;

   -- Pick the nibble for the currently-active digit.
   nibble_select : process(enabledDigit, numberToDisplay)
   begin
      case enabledDigit is
         when "00"   => currentDigitValue <= numberToDisplay( 3 downto  0);
         when "01"   => currentDigitValue <= numberToDisplay( 7 downto  4);
         when "10"   => currentDigitValue <= numberToDisplay(11 downto  8);
         when others => currentDigitValue <= numberToDisplay(15 downto 12);
      end case;
   end process;

   -- Hex 0..F to 7-segment (active-low cathodes, common-anode).
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
