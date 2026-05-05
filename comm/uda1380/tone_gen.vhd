-- tone_gen.vhd
--
-- Minimal audio source: a symmetric square wave at half-scale,
-- toggled every TOGGLE_HALF_CYCLES rising edges of clk. Driven from
-- LRCLK (= Fs), the produced tone frequency is:
--
--   F_tone = Fs / (2 * TOGGLE_HALF_CYCLES)
--
-- so e.g. Fs=96 kHz with TOGGLE_HALF_CYCLES=96 yields a 500 Hz tone.
-- The output is a 24-bit signed value: +0x4000_00 / -0x4000_00,
-- about half full-scale to keep the demo audible without being
-- painful through headphones at default codec gain.

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity tone_gen is
  generic (
    TOGGLE_HALF_CYCLES : integer := 96
  );
  port (
    clk     : in  std_logic;
    reset   : in  std_logic;                       -- active-high
    sample  : out std_logic_vector(23 downto 0)
  );
end entity tone_gen;

architecture rtl of tone_gen is
  signal counter : integer range 0 to TOGGLE_HALF_CYCLES-1 := 0;
  signal level   : std_logic := '0';
  constant POSITIVE_LEVEL : std_logic_vector(23 downto 0) := x"400000";
  constant NEGATIVE_LEVEL : std_logic_vector(23 downto 0) := x"C00000";
begin

  process (clk, reset)
  begin
    if reset = '1' then
      counter <= 0;
      level   <= '0';
    elsif rising_edge(clk) then
      if counter = TOGGLE_HALF_CYCLES-1 then
        counter <= 0;
        level   <= not level;
      else
        counter <= counter + 1;
      end if;
    end if;
  end process;

  sample <= POSITIVE_LEVEL when level = '1' else NEGATIVE_LEVEL;

end architecture rtl;
