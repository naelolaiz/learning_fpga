-- tb_i2c_master.vhd
--
-- Puts i2c_master on a two-wire bus with a behavioural slave and
-- checks what actually travels over the wires:
--
--   1. A write of pointer + two data bytes is acknowledged byte by
--      byte and framed by exactly one START and one STOP.
--   2. Reading the two bytes back through a repeated START returns
--      them; the master acknowledges the first and NACKs the last.
--   3. A wrong address is reported as not acknowledged and the bus
--      is released with a STOP.
--   4. With the slave stretching the clock before every acknowledge
--      bit, a write and its read-back still succeed.
--
-- Two monitors run for the whole simulation: one checks that SCL never
-- runs faster than CLKS_PER_QUARTER allows, the other counts the SCL
-- low times that reach the stretch length. START and STOP are, by
-- definition, the only SDA edges while SCL is high, so the START /
-- STOP totals also prove that data never moved while SCL was high.

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity tb_i2c_master is
end entity tb_i2c_master;

architecture testbench of tb_i2c_master is
  constant CLKS_PER_QUARTER : integer := 4;
  constant CLK_PERIOD       : time    := 20 ns;       -- 50 MHz
  constant QUARTER          : time    := CLKS_PER_QUARTER * CLK_PERIOD;
  constant STRETCH_TIME     : time    := 6 * QUARTER;

  constant SLAVE_ADDR : std_logic_vector(6 downto 0) := "1010000";  -- 0x50
  constant OTHER_ADDR : std_logic_vector(6 downto 0) := "1010001";  -- nobody there

  signal sClk      : std_logic := '0';
  signal sRst      : std_logic := '1';

  signal sCmdValid : std_logic := '0';
  signal sCmdStart : std_logic := '0';
  signal sCmdStop  : std_logic := '0';
  signal sCmdRead  : std_logic := '0';
  signal sCmdNack  : std_logic := '0';
  signal sCmdWdata : std_logic_vector(7 downto 0) := (others => '0');
  signal sCmdReady : std_logic;
  signal sRspValid : std_logic;
  signal sRspRdata : std_logic_vector(7 downto 0);
  signal sRspNack  : std_logic;
  signal sBusy     : std_logic;

  -- The bus. Each device can only pull a line low; a line nobody
  -- pulls is high. Modelled with strong '0' / '1' so nothing shows as
  -- a weak or unknown level in the waveform.
  signal sMasterSclOe : std_logic;
  signal sMasterSdaOe : std_logic;
  signal sSlaveSclOe  : std_logic;
  signal sSlaveSdaOe  : std_logic;
  signal sScl         : std_logic := '1';
  signal sSda         : std_logic := '1';

  signal sStretch  : std_logic := '0';
  signal sStarts   : integer;
  signal sStops    : integer;
  signal sRxCount  : integer;
  signal sRxData   : std_logic_vector(7 downto 0);

  -- SCL low times at least STRETCH_TIME long.
  signal sStretchedLows : integer := 0;

  signal sSimulationActive : boolean := true;
begin

  dut : entity work.i2c_master
    generic map (CLKS_PER_QUARTER => CLKS_PER_QUARTER)
    port map (
      clk       => sClk,
      rst       => sRst,
      cmd_valid => sCmdValid,
      cmd_start => sCmdStart,
      cmd_stop  => sCmdStop,
      cmd_read  => sCmdRead,
      cmd_nack  => sCmdNack,
      cmd_wdata => sCmdWdata,
      cmd_ready => sCmdReady,
      rsp_valid => sRspValid,
      rsp_rdata => sRspRdata,
      rsp_nack  => sRspNack,
      busy      => sBusy,
      scl_oe    => sMasterSclOe,
      scl_i     => sScl,
      sda_oe    => sMasterSdaOe,
      sda_i     => sSda
    );

  slave : entity work.i2c_slave_model
    generic map (ADDR => SLAVE_ADDR, STRETCH_TIME => STRETCH_TIME)
    port map (
      scl      => sScl,
      sda      => sSda,
      stretch  => sStretch,
      scl_oe   => sSlaveSclOe,
      sda_oe   => sSlaveSdaOe,
      starts   => sStarts,
      stops    => sStops,
      rx_count => sRxCount,
      rx_data  => sRxData
    );

  -- Wired-AND with a pull-up.
  sScl <= '0' when sMasterSclOe = '1' or sSlaveSclOe = '1' else '1';
  sSda <= '0' when sMasterSdaOe = '1' or sSlaveSdaOe = '1' else '1';

  sClk <= not sClk after CLK_PERIOD/2 when sSimulationActive;

  -- SCL may be slower than nominal (the synchroniser, clock
  -- stretching, the gaps between bytes) but never faster: each high
  -- and each low lasts at least two quarters.
  scl_monitor : process (sScl)
    variable last_edge : time := 0 ns;
  begin
    if sScl'event then
      assert now - last_edge >= 2 * QUARTER
        report "SCL level shorter than half a period" severity error;
      if sScl = '1' and now - last_edge >= STRETCH_TIME then
        sStretchedLows <= sStretchedLows + 1;
      end if;
      last_edge := now;
    end if;
  end process;

  driver : process
    -- One byte slot: hand over the command, then wait for its response.
    procedure xfer (start, stop, read, nack : in std_logic;
                    wdata                   : in std_logic_vector(7 downto 0)) is
    begin
      sCmdStart <= start;
      sCmdStop  <= stop;
      sCmdRead  <= read;
      sCmdNack  <= nack;
      sCmdWdata <= wdata;
      sCmdValid <= '1';
      wait until rising_edge(sClk) and sCmdReady = '1';
      sCmdValid <= '0';
      wait until rising_edge(sClk) and sRspValid = '1';
    end procedure;
  begin
    wait for 4 * CLK_PERIOD;
    sRst <= '0';
    wait for 2 * CLK_PERIOD;
    assert sScl = '1' and sSda = '1'
      report "Bus should idle high" severity error;
    assert sBusy = '0' report "Master should idle not busy" severity error;

    -- 1. Write 0xA5, 0x3C starting at pointer 0x10.
    xfer('1', '0', '0', '0', SLAVE_ADDR & '0');
    assert sRspNack = '0' report "Write address not acknowledged" severity error;
    xfer('0', '0', '0', '0', x"10");
    assert sRspNack = '0' report "Pointer byte not acknowledged" severity error;
    xfer('0', '0', '0', '0', x"A5");
    assert sRspNack = '0' report "First data byte not acknowledged" severity error;
    assert sRspRdata = x"A5" report "Write did not read back its own byte" severity error;
    xfer('0', '1', '0', '0', x"3C");
    assert sRspNack = '0' report "Second data byte not acknowledged" severity error;
    wait until sBusy = '0';
    assert sStarts = 1 and sStops = 1
      report "Write should be framed by one START and one STOP" severity error;
    assert sRxCount = 3 and sRxData = x"3C"
      report "Slave did not receive the three bytes" severity error;
    assert sScl = '1' and sSda = '1'
      report "Bus should be released after STOP" severity error;

    -- 2. Read them back: set the pointer, repeated START, two reads.
    xfer('1', '0', '0', '0', SLAVE_ADDR & '0');
    xfer('0', '0', '0', '0', x"10");
    xfer('1', '0', '0', '0', SLAVE_ADDR & '1');
    assert sRspNack = '0' report "Read address not acknowledged" severity error;
    xfer('0', '0', '1', '0', x"00");
    assert sRspRdata = x"A5" report "First byte read back wrong" severity error;
    assert sRspNack = '0' report "Master should acknowledge the first read" severity error;
    xfer('0', '1', '1', '1', x"00");
    assert sRspRdata = x"3C" report "Second byte read back wrong" severity error;
    assert sRspNack = '1' report "Master should NACK the last read" severity error;
    wait until sBusy = '0';
    assert sStarts = 3 and sStops = 2
      report "Read should add a START, a repeated START and one STOP" severity error;

    -- 3. Nobody answers at OTHER_ADDR.
    xfer('1', '1', '0', '0', OTHER_ADDR & '0');
    assert sRspNack = '1' report "Missing slave should read as NACK" severity error;
    wait until sBusy = '0';
    assert sStarts = 4 and sStops = 3
      report "Unanswered address should still be framed" severity error;
    assert sRxCount = 4
      report "Slave must ignore a transfer addressed elsewhere" severity error;
    assert sStretchedLows = 0
      report "No SCL low should reach the stretch length yet" severity error;

    -- 4. The same write and read-back while the slave stretches SCL.
    sStretch <= '1';
    xfer('1', '0', '0', '0', SLAVE_ADDR & '0');
    xfer('0', '0', '0', '0', x"20");
    xfer('0', '1', '0', '0', x"5A");
    assert sRspNack = '0' report "Stretched write not acknowledged" severity error;
    wait until sBusy = '0';
    assert sStretchedLows = 3
      report "Expected one stretched SCL low per byte of the write" severity error;

    xfer('1', '0', '0', '0', SLAVE_ADDR & '0');
    xfer('0', '0', '0', '0', x"20");
    xfer('1', '0', '0', '0', SLAVE_ADDR & '1');
    xfer('0', '1', '1', '1', x"00");
    assert sRspRdata = x"5A" report "Stretched read returned the wrong byte" severity error;
    wait until sBusy = '0';
    assert sStretchedLows = 7
      report "Expected one stretched SCL low per byte of the read-back" severity error;
    assert sStarts = 7 and sStops = 5
      report "Unexpected START / STOP totals" severity error;

    report "i2c_master simulation done!" severity note;
    sSimulationActive <= false;
    wait;
  end process;

end architecture testbench;
