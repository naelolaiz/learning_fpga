-- tb_uda1380_init_fsm.vhd
--
-- Unit testbench for uda1380_init_fsm. A stub stands in for
-- i2c_master's command interface (cmd_ready / i2c_busy), so the FSM
-- walks its boot table at sim speed with no real bus traffic.
-- Asserts, for every byte the stub accepts:
--
--   * the first byte of each group of four carries cmd_start and is
--     DEVICE_ADDR & '0' (a write);
--   * the last byte of the group carries cmd_stop;
--   * the two bytes in between carry neither.
--
-- and at the end that the byte count is INIT_TABLE_LEN * 4
-- (address, register, data high, data low) and that init_done only
-- rises once the bus is idle again.
--
-- The register and data values are checked on the bus by the
-- integration testbench; this one validates the FSM's framing.

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.uda1380_control_definitions.all;

entity tb_uda1380_init_fsm is
end entity;

architecture testbench of tb_uda1380_init_fsm is
  constant CLK_PERIOD       : time    := 20 ns;        -- 50 MHz
  constant INIT_DELAY_CYCLES_TB : integer := 4;        -- collapse the power-up wait
  constant BYTE_TIME        : time    := 10 * CLK_PERIOD;  -- stub's "byte on the wire"

  -- Has to match the entry count in uda1380_init_fsm's INIT_TABLE.
  -- Kept as a separate constant so adding a register write in the
  -- FSM forces a deliberate update here.
  constant EXPECTED_TABLE_LEN : integer := 15;
  constant EXPECTED_BYTES     : integer := EXPECTED_TABLE_LEN * 4;

  signal clk         : std_logic := '0';
  signal reset       : std_logic := '1';

  signal cmd_valid   : std_logic;
  signal cmd_start   : std_logic;
  signal cmd_stop    : std_logic;
  signal cmd_wdata   : std_logic_vector(7 downto 0);
  signal cmd_ready   : std_logic := '0';
  signal i2c_busy    : std_logic := '0';
  signal init_done   : std_logic;

  signal sim_active  : boolean := true;

  -- Bytes accepted by the stub so far.
  signal bytes_observed : integer := 0;
begin

  dut : entity work.uda1380_init_fsm
    generic map (INIT_DELAY_CYCLES => INIT_DELAY_CYCLES_TB)
    port map (
      clk       => clk,
      reset     => reset,
      cmd_valid => cmd_valid,
      cmd_start => cmd_start,
      cmd_stop  => cmd_stop,
      cmd_wdata => cmd_wdata,
      cmd_ready => cmd_ready,
      i2c_busy  => i2c_busy,
      init_done => init_done
    );

  clk <= not clk after CLK_PERIOD/2 when sim_active;

  -- Stub i2c_master: ready for a command, accept it on the clock edge
  -- where cmd_valid is high, stay busy for a "byte time", and after a
  -- byte flagged cmd_stop stay busy a little longer for the STOP
  -- before reporting the bus idle.
  --
  -- Real master timing is much slower; the stub uses a few hundred
  -- nanoseconds so the whole boot sequence completes in microseconds.
  i2c_stub : process
    variable count     : integer := 0;
    variable stop_seen : boolean := false;
  begin
    cmd_ready <= '1';
    wait until rising_edge(clk) and cmd_valid = '1';

    if count mod 4 = 0 then
      assert cmd_start = '1'
        report "first byte of a register write must carry cmd_start"
        severity error;
      assert cmd_wdata = DEVICE_ADDR & '0'
        report "first byte must be DEVICE_ADDR with the write bit"
        severity error;
    else
      assert cmd_start = '0'
        report "cmd_start on a byte that is not the address"
        severity error;
    end if;
    if count mod 4 = 3 then
      assert cmd_stop = '1'
        report "last byte of a register write must carry cmd_stop"
        severity error;
    else
      assert cmd_stop = '0'
        report "cmd_stop before the last byte of a register write"
        severity error;
    end if;

    stop_seen := (cmd_stop = '1');
    count     := count + 1;
    bytes_observed <= count;

    cmd_ready <= '0';
    i2c_busy  <= '1';
    wait for BYTE_TIME;
    if stop_seen then
      wait for BYTE_TIME;           -- the STOP condition
      i2c_busy <= '0';
    end if;
  end process;

  -- init_done must not rise while the last transaction is on the bus.
  done_check : process (init_done)
  begin
    if rising_edge(init_done) then
      assert i2c_busy = '0'
        report "init_done rose while the bus was still busy"
        severity error;
    end if;
  end process;

  -- Stimulus + final assertion.
  driver : process
  begin
    reset <= '1';
    wait for 10 * CLK_PERIOD;
    reset <= '0';

    -- Wait for init_done with a generous timeout. 15 registers ×
    -- 5 byte times of 200 ns ≈ 15 us. 200 us margin.
    wait until init_done = '1' for 200 us;

    assert init_done = '1'
      report "init_done never asserted"
      severity error;

    assert bytes_observed = EXPECTED_BYTES
      report "byte count mismatch: got " & integer'image(bytes_observed) &
             " expected " & integer'image(EXPECTED_BYTES)
      severity error;

    report "uda1380_init_fsm simulation done!" severity note;
    sim_active <= false;
    wait;
  end process;

end architecture testbench;
