-- top_level_uda1380_core.vhd
--
-- Everything needed to make the Waveshare UDA1380 board produce sound
-- from the dev-board's 50 MHz clock alone:
--
--   * uda1380_init_fsm — drives the boot register-write sequence
--     using the constants in uda1380_control_definitions.
--   * i2c_master (comm/i2c_master) — puts those bytes on the bus.
--   * i2s_master — generates MCLK / LRCLK / BCK and serialises the
--     24-bit two-channel sample stream MSB-first (same source as
--     i2s_test_1).
--   * tone_gen — minimal half-scale square-wave audio source so
--     the codec actually has something to play once initialised.
--
-- The I2C bus leaves this entity as separate drive-low enables and
-- read-backs (scl_oe / scl_i, sda_oe / sda_i) instead of `inout`
-- pins. That keeps the whole hierarchy free of tristates, so it
-- simulates with plain '0' / '1' levels and netlistsvg can render
-- it. top_level_uda1380.vhd wraps this core and adds the two
-- open-drain pins for the board.
--
-- Reset polarity: iNoReset is active-low; it is inverted internally
-- to active-high for every sub-block.
--
-- The Rx (ADC capture) path is intentionally not wired here. To
-- record from the codec the ADC clock outputs would mirror the Tx
-- clocks and a serial-data input (DOUT pin) would feed an i2s_slave
-- block.

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.uda1380_control_definitions.all;

entity top_level_uda1380_core is
  generic (
    SYS_CLK_FREQ      : integer := 50_000_000;
    I2C_BUS_FREQ      : integer := 100_000;
    INIT_DELAY_CYCLES : integer := 5_000_000;        -- 100 ms power-up wait
    TONE_HALF_CYCLES  : integer := 96                -- ~500 Hz at 96 kHz Fs
  );
  port (
    iClk               : in  std_logic;
    iNoReset           : in  std_logic;             -- active-low
    -- Open-drain split (drive *_oe='1' to pull line low; *_i is
    -- the line state read back).
    oI2cSclOe          : out std_logic;
    iI2cSclIn          : in  std_logic;
    oI2cSdaOe          : out std_logic;
    iI2cSdaIn          : in  std_logic;
    oTxMasterClock     : out std_logic;             -- to UDA1380 SYSCLK
    oTxWordSelectClock : out std_logic;             -- to UDA1380 WSI / LRCK
    oTxBitClock        : out std_logic;             -- to UDA1380 BCK0
    oTxSerialData      : out std_logic;             -- to UDA1380 DATAI
    oInitDone          : out std_logic              -- status for LED / scope
  );
end entity top_level_uda1380_core;

architecture rtl of top_level_uda1380_core is
  signal reset_h : std_logic;

  signal cmd_valid : std_logic;
  signal cmd_start : std_logic;
  signal cmd_stop  : std_logic;
  signal cmd_wdata : std_logic_vector(7 downto 0);
  signal cmd_ready : std_logic;
  signal i2c_busy  : std_logic;

  signal sample_24 : std_logic_vector(23 downto 0);
  signal lrclk_int : std_logic;
begin

  reset_h <= not iNoReset;

  init_fsm : entity work.uda1380_init_fsm
    generic map (INIT_DELAY_CYCLES => INIT_DELAY_CYCLES)
    port map (
      clk       => iClk,
      reset     => reset_h,
      cmd_valid => cmd_valid,
      cmd_start => cmd_start,
      cmd_stop  => cmd_stop,
      cmd_wdata => cmd_wdata,
      cmd_ready => cmd_ready,
      i2c_busy  => i2c_busy,
      init_done => oInitDone
    );

  -- The master counts in quarters of an SCL period. The boot sequence
  -- only writes, and it does not look at the acknowledge bits, so the
  -- read flags are tied off and the response is left unconnected.
  i2c_master_inst : entity work.i2c_master
    generic map (
      CLKS_PER_QUARTER => SYS_CLK_FREQ / (4 * I2C_BUS_FREQ)
    )
    port map (
      clk       => iClk,
      rst       => reset_h,
      cmd_valid => cmd_valid,
      cmd_start => cmd_start,
      cmd_stop  => cmd_stop,
      cmd_read  => '0',
      cmd_nack  => '0',
      cmd_wdata => cmd_wdata,
      cmd_ready => cmd_ready,
      rsp_valid => open,
      rsp_rdata => open,
      rsp_nack  => open,
      busy      => i2c_busy,
      scl_oe    => oI2cSclOe,
      scl_i     => iI2cSclIn,
      sda_oe    => oI2cSdaOe,
      sda_i     => iI2cSdaIn
    );

  i2s_master_inst : entity work.i2s_master
    generic map (CLK_FREQ => SYS_CLK_FREQ)
    port map (
      reset  => reset_h,
      clk    => iClk,
      mclk   => oTxMasterClock,
      lrclk  => lrclk_int,
      sclk   => oTxBitClock,
      sdata  => oTxSerialData,
      data_l => sample_24,
      data_r => sample_24
    );

  oTxWordSelectClock <= lrclk_int;

  tone : entity work.tone_gen
    generic map (TOGGLE_HALF_CYCLES => TONE_HALF_CYCLES)
    port map (
      clk    => lrclk_int,
      reset  => reset_h,
      sample => sample_24
    );

end architecture rtl;
