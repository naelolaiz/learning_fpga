-- tb_top_level_uda1380_board.vhd
--
-- Runs the board top, top_level_uda1380, the way it is wired on the
-- board: SCL and SDA are single `inout` wires with a pull-up, shared
-- with the codec.
--
-- The other integration testbench (tb_top_level_uda1380) drives the
-- core through its split oe / read-back ports, which is where the
-- byte-by-byte check lives. This one covers what that leaves out — the
-- two open-drain pins the wrapper adds. A wrapper that drove a line
-- high instead of releasing it would fight the codec for the line; one
-- that read the pin back wrongly would stall the master waiting for
-- SCL to rise.
--
-- Each wire is one resolved std_logic signal with three drivers:
--
--   the pull-up     'H'  (weak high, always)
--   the FPGA pin    '0' or 'Z'
--   the codec pin   '0' or 'Z'
--
-- so the line reads 'H' when both let go and '0' when either pulls.
-- Asserts that the lines never show contention, that the boot
-- sequence completes, that the codec received all 45 bytes in 15
-- separately framed writes, and that both lines end up released.
--
-- No waveform is rendered for this testbench: a weak 'H' is not a
-- plain logic level and would be flagged in the picture.

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.uda1380_control_definitions.all;

entity tb_top_level_uda1380_board is
end entity;

architecture testbench of tb_top_level_uda1380_board is
  constant CLK_PERIOD      : time    := 20 ns;        -- 50 MHz
  constant EXPECTED_WRITES : integer := 15;
  constant EXPECTED_BYTES  : integer := EXPECTED_WRITES * 3;

  signal iClk     : std_logic := '0';
  signal iNoReset : std_logic := '0';        -- active-low; '0' = reset

  -- The two bus wires.
  signal scl : std_logic;
  signal sda : std_logic;

  -- The codec stand-in: open-drain outputs, and the levels its inputs
  -- see ('H' reads as '1').
  signal codec_scl_oe : std_logic;
  signal codec_sda_oe : std_logic;
  signal scl_level    : std_logic;
  signal sda_level    : std_logic;

  signal oTxMasterClock     : std_logic;
  signal oTxWordSelectClock : std_logic;
  signal oTxBitClock        : std_logic;
  signal oTxSerialData      : std_logic;
  signal oInitDone          : std_logic;

  signal starts   : integer;
  signal stops    : integer;
  signal rx_count : integer;
  signal rx_data  : std_logic_vector(7 downto 0);

  signal sim_active : boolean := true;
begin

  dut : entity work.top_level_uda1380
    generic map (
      SYS_CLK_FREQ      => 50_000_000,
      I2C_BUS_FREQ      => 5_000_000,
      INIT_DELAY_CYCLES => 4,
      TONE_HALF_CYCLES  => 4
    )
    port map (
      iClk               => iClk,
      iNoReset           => iNoReset,
      i2cIOScl           => scl,
      i2cIOSda           => sda,
      oTxMasterClock     => oTxMasterClock,
      oTxWordSelectClock => oTxWordSelectClock,
      oTxBitClock        => oTxBitClock,
      oTxSerialData      => oTxSerialData,
      oInitDone          => oInitDone
    );

  -- Pull-up resistors.
  scl <= 'H';
  sda <= 'H';

  -- The codec's open-drain pins.
  scl <= '0' when codec_scl_oe = '1' else 'Z';
  sda <= '0' when codec_sda_oe = '1' else 'Z';

  scl_level <= to_X01(scl);
  sda_level <= to_X01(sda);

  codec : entity work.i2c_slave_model
    generic map (ADDR => DEVICE_ADDR)
    port map (
      scl      => scl_level,
      sda      => sda_level,
      stretch  => '0',
      scl_oe   => codec_scl_oe,
      sda_oe   => codec_sda_oe,
      starts   => starts,
      stops    => stops,
      rx_count => rx_count,
      rx_data  => rx_data
    );

  iClk <= not iClk after CLK_PERIOD/2 when sim_active;

  -- Two devices fighting over a line (one driving '1', the other '0')
  -- resolve to 'X'. On an open-drain bus that must never happen.
  contention_check : process (scl, sda)
  begin
    assert scl /= 'X' and sda /= 'X'
      report "bus contention: a device is driving a line high"
      severity error;
  end process;

  driver : process
  begin
    iNoReset <= '0';
    wait for 10 * CLK_PERIOD;

    assert scl = 'H' and sda = 'H'
      report "bus should rest on the pull-ups while in reset"
      severity error;

    iNoReset <= '1';

    wait until oInitDone = '1' for 1 ms;

    assert oInitDone = '1'
      report "oInitDone never asserted"
      severity error;

    assert rx_count = EXPECTED_BYTES
      report "codec received " & integer'image(rx_count) & " bytes, expected " &
             integer'image(EXPECTED_BYTES)
      severity error;

    assert starts = EXPECTED_WRITES and stops = EXPECTED_WRITES
      report "expected one START and one STOP per register write, got " &
             integer'image(starts) & " / " & integer'image(stops)
      severity error;

    assert scl = 'H' and sda = 'H'
      report "bus not released after the boot sequence"
      severity error;

    report "uda1380 board-top simulation done!" severity note;
    sim_active <= false;
    wait;
  end process;

end architecture testbench;
