-- tb_top_level_uda1380.vhd
--
-- Integration testbench. Drives top_level_uda1380_core (the split
-- scl_oe / scl_i, sda_oe / sda_i variant) with a behavioural I2C
-- slave standing in for the codec, so the boot sequence is checked
-- where it matters — on the bus:
--
--   * every byte the codec receives matches EXPECTED, in order
--     (register, data high, data low for each of the 15 writes);
--   * each write is its own transaction: 15 STARTs and 15 STOPs;
--   * oInitDone rises, and MCLK / BCK / LRCLK are running.
--
-- The slave only acknowledges DEVICE_ADDR, so a wrong address byte
-- shows up as bytes that never arrive. The same EXPECTED stream is
-- used by the Verilog testbench, which ties the VHDL record constants
-- and the Verilog hex table to each other.
--
-- The bus is modelled with strong '0' / '1' levels (no 'H'), so it
-- renders cleanly in the waveform. The inout top (top_level_uda1380)
-- is still in SRC_FILES so it gets analysed; the runtime hierarchy is
-- the core.
--
-- Generics are tightened so the boot sequence finishes inside sim
-- budget (INIT_DELAY_CYCLES=4, TONE_HALF_CYCLES=4,
-- I2C_BUS_FREQ=5_000_000).

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.uda1380_control_definitions.all;

entity tb_top_level_uda1380 is
end entity;

architecture testbench of tb_top_level_uda1380 is
  constant CLK_PERIOD : time := 20 ns;        -- 50 MHz

  type byte_array is array (natural range <>) of std_logic_vector(7 downto 0);
  -- What the codec must receive: {register, data high, data low} per
  -- write, in boot order.
  constant EXPECTED : byte_array := (
    x"7F", x"00", x"00",    -- L3 reset
    x"02", x"A5", x"DF",    -- power: enable all
    x"00", x"0F", x"39",    -- evalclk: WSPLL, all clocks on
    x"01", x"00", x"00",    -- I2S: bus, digital mixer, BCK0 slave
    x"03", x"00", x"00",    -- analog mixer input gain
    x"04", x"02", x"02",    -- headamp: short-circuit protection on
    x"10", x"00", x"00",    -- master volume: full
    x"11", x"00", x"00",    -- mixer volume: full both channels
    x"12", x"55", x"15",    -- mode/treble/bass: flat
    x"13", x"00", x"00",    -- mute/de-emph: disable
    x"14", x"00", x"00",    -- mixer SDO: off
    x"20", x"00", x"00",    -- ADC decimator volume: max
    x"21", x"00", x"00",    -- PGA: no mute, full gain
    x"22", x"0F", x"02",    -- ADC: select line-in + mic, max gain
    x"23", x"00", x"00"     -- AGC: settings
  );
  constant EXPECTED_WRITES : integer := EXPECTED'length / 3;

  signal iClk     : std_logic := '0';
  signal iNoReset : std_logic := '0';        -- active-low; '0' = reset

  -- Open-drain bus: a device drives *_oe='1' to pull a line low, and
  -- a line nobody pulls is high. Strong levels only.
  signal scl_oe       : std_logic;
  signal sda_oe       : std_logic;
  signal codec_scl_oe : std_logic;
  signal codec_sda_oe : std_logic;
  signal scl          : std_logic := '1';
  signal sda          : std_logic := '1';

  signal oTxMasterClock     : std_logic;
  signal oTxWordSelectClock : std_logic;
  signal oTxBitClock        : std_logic;
  signal oTxSerialData      : std_logic;
  signal oInitDone          : std_logic;

  -- Taps from the codec stand-in.
  signal starts   : integer;
  signal stops    : integer;
  signal rx_count : integer;
  signal rx_data  : std_logic_vector(7 downto 0);

  signal sim_active : boolean := true;

  signal mclk_edges : integer := 0;
  signal bclk_edges : integer := 0;
  signal lrclk_edges: integer := 0;
begin

  dut : entity work.top_level_uda1380_core
    generic map (
      SYS_CLK_FREQ      => 50_000_000,
      I2C_BUS_FREQ      => 5_000_000,
      INIT_DELAY_CYCLES => 4,
      TONE_HALF_CYCLES  => 4
    )
    port map (
      iClk               => iClk,
      iNoReset           => iNoReset,
      oI2cSclOe          => scl_oe,
      iI2cSclIn          => scl,
      oI2cSdaOe          => sda_oe,
      iI2cSdaIn          => sda,
      oTxMasterClock     => oTxMasterClock,
      oTxWordSelectClock => oTxWordSelectClock,
      oTxBitClock        => oTxBitClock,
      oTxSerialData      => oTxSerialData,
      oInitDone          => oInitDone
    );

  codec : entity work.i2c_slave_model
    generic map (ADDR => DEVICE_ADDR)
    port map (
      scl      => scl,
      sda      => sda,
      stretch  => '0',
      scl_oe   => codec_scl_oe,
      sda_oe   => codec_sda_oe,
      starts   => starts,
      stops    => stops,
      rx_count => rx_count,
      rx_data  => rx_data
    );

  iClk <= not iClk after CLK_PERIOD/2 when sim_active;

  -- Wired-AND with a pull-up.
  scl <= '0' when scl_oe = '1' or codec_scl_oe = '1' else '1';
  sda <= '0' when sda_oe = '1' or codec_sda_oe = '1' else '1';

  -- Compare each byte as the codec receives it.
  byte_check : process (rx_count)
  begin
    if rx_count > 0 then
      assert rx_count <= EXPECTED'length
        report "codec received more bytes than the boot sequence has"
        severity error;
      if rx_count <= EXPECTED'length then
        assert rx_data = EXPECTED(rx_count - 1)
          report "boot byte " & integer'image(rx_count - 1) &
                 " differs from the expected stream"
          severity error;
      end if;
    end if;
  end process;

  mclk_edge_count : process (oTxMasterClock)
  begin
    if rising_edge(oTxMasterClock) then
      mclk_edges <= mclk_edges + 1;
    end if;
  end process;

  bclk_edge_count : process (oTxBitClock)
  begin
    if rising_edge(oTxBitClock) then
      bclk_edges <= bclk_edges + 1;
    end if;
  end process;

  lrclk_edge_count : process (oTxWordSelectClock)
  begin
    if oTxWordSelectClock'event then
      lrclk_edges <= lrclk_edges + 1;
    end if;
  end process;

  driver : process
  begin
    iNoReset <= '0';
    wait for 10 * CLK_PERIOD;
    iNoReset <= '1';

    wait until oInitDone = '1' for 1 ms;

    assert oInitDone = '1'
      report "oInitDone never asserted"
      severity error;

    assert rx_count = EXPECTED'length
      report "codec received " & integer'image(rx_count) & " bytes, expected " &
             integer'image(EXPECTED'length)
      severity error;

    assert starts = EXPECTED_WRITES and stops = EXPECTED_WRITES
      report "expected one START and one STOP per register write, got " &
             integer'image(starts) & " / " & integer'image(stops)
      severity error;

    assert scl = '1' and sda = '1'
      report "bus not released after the boot sequence"
      severity error;

    assert mclk_edges > 1000
      report "MCLK barely moved: " & integer'image(mclk_edges) & " rising edges"
      severity error;

    assert bclk_edges > 100
      report "BCK barely moved: " & integer'image(bclk_edges) & " rising edges"
      severity error;

    assert lrclk_edges > 4
      report "LRCLK barely moved: " & integer'image(lrclk_edges) & " transitions"
      severity error;

    report "uda1380 integration simulation done!" severity note;
    sim_active <= false;
    wait;
  end process;

end architecture testbench;
