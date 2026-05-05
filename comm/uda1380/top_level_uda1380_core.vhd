-- top_level_uda1380_core.vhd
--
-- Same wiring as top_level_uda1380.vhd, but the I2C bus is split into
-- separate output-enable / input pairs (sda_oe, sda_i, scl_oe, scl_i)
-- instead of `inout`. This is the diagram-renderable variant — used
-- by the netlist diagram step, while the simulation top
-- (top_level_uda1380.vhd) wraps this core and resolves the inout pin
-- against the external pull-up.
--
-- Ports / structure are otherwise identical to top_level_uda1380.

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.uda1380_control_definitions.all;

entity top_level_uda1380_core is
  generic (
    SYS_CLK_FREQ      : integer := 50_000_000;
    I2C_BUS_FREQ      : integer := 100_000;
    INIT_DELAY_CYCLES : integer := 5_000_000;
    TONE_HALF_CYCLES  : integer := 96
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
    oTxMasterClock     : out std_logic;
    oTxWordSelectClock : out std_logic;
    oTxBitClock        : out std_logic;
    oTxSerialData      : out std_logic;
    oInitDone          : out std_logic
  );
end entity top_level_uda1380_core;

architecture rtl of top_level_uda1380_core is
  signal reset_h : std_logic;

  signal i2c_ena     : std_logic;
  signal i2c_addr    : std_logic_vector(6 downto 0);
  signal i2c_rw      : std_logic;
  signal i2c_data_wr : std_logic_vector(7 downto 0);
  signal i2c_busy    : std_logic;
  signal i2c_ack_err : std_logic;
  signal i2c_data_rd : std_logic_vector(7 downto 0);

  signal sample_24 : std_logic_vector(23 downto 0);
  signal lrclk_int : std_logic;
begin

  reset_h <= not iNoReset;

  init_fsm : entity work.uda1380_init_fsm
    generic map (INIT_DELAY_CYCLES => INIT_DELAY_CYCLES)
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

  i2c_master_inst : entity work.i2c_master_for_diagram
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
      sda_oe    => oI2cSdaOe,
      sda_i     => iI2cSdaIn,
      scl_oe    => oI2cSclOe,
      scl_i     => iI2cSclIn
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
