-- tb_top_level_uda1380.vhd
--
-- Integration testbench for top_level_uda1380. Generics are tightened
-- so the boot sequence finishes inside sim budget:
--
--   INIT_DELAY_CYCLES = 4         -- collapse the 100 ms power-up wait
--   TONE_HALF_CYCLES  = 4         -- audible tone period irrelevant in sim
--   I2C_BUS_FREQ      = 5_000_000 -- 5 MHz "I2C" so a 3-byte register
--                                    write costs ~6 us instead of ~600 us
--
-- No I2C slave is modelled — the bus pull-ups idle SDA high, so the
-- Digi-Key i2c_master sees every ACK as a NACK and raises ack_error.
-- The init FSM does not gate progress on ack_error, so the boot
-- sequence still completes; what we assert is the structural side:
--
--   * I2C SCL toggled at all (the master is talking).
--   * I2S MCLK / BCK / LRCLK toggled at all (the i2s_master is alive).
--   * init_done eventually rises.
--
-- Byte-level correctness lives in tb_uda1380_init_fsm; this one is
-- the smoke test that the wires are connected.

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity tb_top_level_uda1380 is
end entity;

architecture testbench of tb_top_level_uda1380 is
  constant CLK_PERIOD : time := 20 ns;        -- 50 MHz

  signal iClk               : std_logic := '0';
  signal iNoReset           : std_logic := '0';        -- active-low; '0' = reset
  signal i2cIOScl           : std_logic := 'H';
  signal i2cIOSda           : std_logic := 'H';
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
      i2cIOScl           => i2cIOScl,
      i2cIOSda           => i2cIOSda,
      oTxMasterClock     => oTxMasterClock,
      oTxWordSelectClock => oTxWordSelectClock,
      oTxBitClock        => oTxBitClock,
      oTxSerialData      => oTxSerialData,
      oInitDone          => oInitDone
    );

  iClk <= not iClk after CLK_PERIOD/2 when sim_active;

  -- The two open-drain lines need pull-ups to high for the bus to
  -- idle correctly. 'H' is std_logic's weak-high; the master's 'Z'
  -- resolves with it to 'H', and any '0' the master drives wins.
  i2cIOScl <= 'H';
  i2cIOSda <= 'H';

  -- Edge counters.
  scl_edge_count : process (i2cIOScl)
  begin
    if i2cIOScl'event then
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
    iNoReset <= '0';                            -- assert reset (active-low)
    wait for 10 * CLK_PERIOD;
    iNoReset <= '1';                            -- release reset

    -- Wait for the FSM to finish all 15 register writes. At 5 MHz I2C,
    -- one 3-byte register write takes ~10 us, so 15 of them ~150 us
    -- plus per-register setup/teardown. 1 ms is generous.
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
