-- top_level_uda1380.vhd
--
-- Board top: top_level_uda1380_core plus the two open-drain I2C pins.
--
-- The core exposes each I2C line as a drive-low enable and a
-- read-back. A real pin is one wire, so here each pair becomes an
-- `inout`: drive '0' when the enable is high, otherwise let go ('Z')
-- and let the bus pull-up resistor raise the line. The pin itself is
-- the read-back.
--
-- All of the logic lives in the core; see that file for the blocks
-- and the reset polarity.

library ieee;
use ieee.std_logic_1164.all;

entity top_level_uda1380 is
  generic (
    SYS_CLK_FREQ      : integer := 50_000_000;
    I2C_BUS_FREQ      : integer := 100_000;          -- standard-mode I2C
    INIT_DELAY_CYCLES : integer := 5_000_000;        -- 100 ms power-up wait
    TONE_HALF_CYCLES  : integer := 96                -- ~500 Hz at 96 kHz Fs
  );
  port (
    iClk               : in    std_logic;
    iNoReset           : in    std_logic;             -- active-low
    i2cIOScl           : inout std_logic;
    i2cIOSda           : inout std_logic;
    oTxMasterClock     : out   std_logic;             -- to UDA1380 SYSCLK
    oTxWordSelectClock : out   std_logic;             -- to UDA1380 WSI / LRCK
    oTxBitClock        : out   std_logic;             -- to UDA1380 BCK0
    oTxSerialData      : out   std_logic;             -- to UDA1380 DATAI
    oInitDone          : out   std_logic              -- status for LED / scope
  );
end entity top_level_uda1380;

architecture rtl of top_level_uda1380 is
  signal scl_oe : std_logic;
  signal sda_oe : std_logic;
  signal scl_in : std_logic;
  signal sda_in : std_logic;
begin

  core : entity work.top_level_uda1380_core
    generic map (
      SYS_CLK_FREQ      => SYS_CLK_FREQ,
      I2C_BUS_FREQ      => I2C_BUS_FREQ,
      INIT_DELAY_CYCLES => INIT_DELAY_CYCLES,
      TONE_HALF_CYCLES  => TONE_HALF_CYCLES
    )
    port map (
      iClk               => iClk,
      iNoReset           => iNoReset,
      oI2cSclOe          => scl_oe,
      iI2cSclIn          => scl_in,
      oI2cSdaOe          => sda_oe,
      iI2cSdaIn          => sda_in,
      oTxMasterClock     => oTxMasterClock,
      oTxWordSelectClock => oTxWordSelectClock,
      oTxBitClock        => oTxBitClock,
      oTxSerialData      => oTxSerialData,
      oInitDone          => oInitDone
    );

  i2cIOScl <= '0' when scl_oe = '1' else 'Z';
  i2cIOSda <= '0' when sda_oe = '1' else 'Z';

  -- to_X01 turns the weak 'H' a simulated pull-up produces into '1';
  -- in hardware it is just a wire.
  scl_in <= to_X01(i2cIOScl);
  sda_in <= to_X01(i2cIOSda);

end architecture rtl;
