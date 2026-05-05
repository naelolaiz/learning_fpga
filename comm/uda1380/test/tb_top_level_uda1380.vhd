-- tb_top_level_uda1380.vhd
--
-- Integration testbench. Drives top_level_uda1380_core directly (the
-- (scl_oe, scl_i, sda_oe, sda_i) variant) instead of the inout
-- wrapper, so the bus appears in the FST as plain strong '1' / '0'
-- — there is no 'H' (weak high) anywhere, which is what waveview
-- renders as a red band when an open-drain bus idles. The inout
-- top (top_level_uda1380) is still in SRC_FILES so it gets
-- elaboration-checked; only the runtime hierarchy is via the core.
--
-- Generics are tightened so the boot sequence finishes inside sim
-- budget (INIT_DELAY_CYCLES=4, TONE_HALF_CYCLES=4,
-- I2C_BUS_FREQ=5_000_000). No I2C slave is modelled — the
-- "pull-ups" idle the lines high, the master sees every ACK as a
-- NACK and raises ack_error, but the FSM doesn't gate on
-- ack_error so the boot still completes.

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity tb_top_level_uda1380 is
end entity;

architecture testbench of tb_top_level_uda1380 is
  constant CLK_PERIOD : time := 20 ns;        -- 50 MHz

  signal iClk     : std_logic := '0';
  signal iNoReset : std_logic := '0';        -- active-low; '0' = reset

  -- Open-drain split: drive *_oe='1' to assert low; *_i is the
  -- line state. The TB models the pull-up as strong '1' when
  -- *_oe='0', strong '0' when *_oe='1' — both render green.
  signal scl_oe : std_logic;
  signal sda_oe : std_logic;
  signal scl_i  : std_logic;
  signal sda_i  : std_logic;

  signal oTxMasterClock     : std_logic;
  signal oTxWordSelectClock : std_logic;
  signal oTxBitClock        : std_logic;
  signal oTxSerialData      : std_logic;
  signal oInitDone          : std_logic;

  signal sim_active : boolean := true;

  signal scl_edges  : integer := 0;
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
      iI2cSclIn          => scl_i,
      oI2cSdaOe          => sda_oe,
      iI2cSdaIn          => sda_i,
      oTxMasterClock     => oTxMasterClock,
      oTxWordSelectClock => oTxWordSelectClock,
      oTxBitClock        => oTxBitClock,
      oTxSerialData      => oTxSerialData,
      oInitDone          => oInitDone
    );

  iClk <= not iClk after CLK_PERIOD/2 when sim_active;

  -- Pull-up model: strong '1' when nobody is asserting low, strong
  -- '0' when the master pulls the line low. Both are clean
  -- forcing-strength values, so waveview renders them green.
  scl_i <= '0' when scl_oe = '1' else '1';
  sda_i <= '0' when sda_oe = '1' else '1';

  -- Edge counters.
  scl_edge_count : process (scl_i)
  begin
    if scl_i'event then
      scl_edges <= scl_edges + 1;
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

    assert scl_edges > 100
      report "I2C SCL barely moved: " & integer'image(scl_edges) & " transitions"
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
