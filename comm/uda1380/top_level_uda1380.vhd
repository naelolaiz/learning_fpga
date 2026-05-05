-- top_level_uda1380.vhd
--
-- Wires together everything needed to make the Waveshare UDA1380
-- board produce sound from the dev-board's 50 MHz clock alone:
--
--   * uda1380_init_fsm — drives the boot register-write sequence
--     over I2C using the constants in uda1380_control_definitions.
--   * i2c_master — Digi-Key generic I2C master that the FSM talks
--     to (open-drain SCL/SDA, internal pull-ups expected on the
--     board).
--   * i2s_master — generates MCLK / LRCLK / BCK and serialises the
--     24-bit two-channel sample stream MSB-first (same source as
--     i2s_test_1).
--   * tone_gen — minimal half-scale square-wave audio source so
--     the codec actually has something to play once initialised.
--
-- Reset polarity: the entity's iNoReset is active-low (matches the
-- original port name); it is inverted internally to active-high
-- for every sub-block.
--
-- The Rx (ADC capture) path is intentionally not wired here. To
-- record from the codec the ADC clock outputs would mirror the Tx
-- clocks and a serial-data input (DOUT pin) would feed an i2s_slave
-- block — out of scope for this initial revival.

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.uda1380_control_definitions.all;

entity top_level_uda1380 is
  generic (
    SYS_CLK_FREQ      : integer := 50_000_000;
    I2C_BUS_FREQ      : integer := 100_000;          -- 100 kHz fast-mode-friendly
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
  signal reset_h : std_logic;                         -- active-high

  signal i2c_ena     : std_logic;
  signal i2c_addr    : std_logic_vector(6 downto 0);
  signal i2c_rw      : std_logic;
  signal i2c_data_wr : std_logic_vector(7 downto 0);
  signal i2c_busy    : std_logic;
  signal i2c_ack_err : std_logic;
  signal i2c_data_rd : std_logic_vector(7 downto 0);

  signal sample_24   : std_logic_vector(23 downto 0);
  signal lrclk_int   : std_logic;
begin

  reset_h <= not iNoReset;

  init_fsm : entity work.uda1380_init_fsm
    generic map (
      INIT_DELAY_CYCLES => INIT_DELAY_CYCLES
    )
    port map (
      clk         => iClk,
      reset       => reset_h,
      i2c_ena     => i2c_ena,
      i2c_addr    => i2c_addr,
      i2c_rw      => i2c_rw,
      i2c_data_wr => i2c_data_wr,
      i2c_busy    => i2c_busy,
      i2c_ack_err => i2c_ack_err,
      init_done   => oInitDone
    );

  -- Digi-Key i2c_master uses active-low reset on its own port.
  i2c_master_inst : entity work.i2c_master
    generic map (
      input_clk => SYS_CLK_FREQ,
      bus_clk   => I2C_BUS_FREQ
    )
    port map (
      clk       => iClk,
      reset_n   => iNoReset,
      ena       => i2c_ena,
      addr      => i2c_addr,
      rw        => i2c_rw,
      data_wr   => i2c_data_wr,
      busy      => i2c_busy,
      data_rd   => i2c_data_rd,
      ack_error => i2c_ack_err,
      sda       => i2cIOSda,
      scl       => i2cIOScl
    );

  i2s_master_inst : entity work.i2s_master
    generic map (
      CLK_FREQ => SYS_CLK_FREQ
    )
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
    generic map (
      TOGGLE_HALF_CYCLES => TONE_HALF_CYCLES
    )
    port map (
      clk    => lrclk_int,
      reset  => reset_h,
      sample => sample_24
    );

end architecture rtl;
