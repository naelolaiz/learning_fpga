-- tb_uda1380_init_fsm.vhd
--
-- Unit testbench for uda1380_init_fsm. Stubs the i2c_master's busy
-- handshake so the FSM walks its boot table at sim speed (no real
-- I2C bus traffic generated). Asserts:
--
--   * Every byte transaction targets DEVICE_ADDR with rw=0 (writes).
--   * The total number of byte transactions matches
--     INIT_TABLE_LEN * 3 (= 3 bytes per register write: reg, hi, lo).
--   * init_done eventually goes high.
--
-- The byte values themselves (reg address + payload) are taken on
-- trust from uda1380_control_definitions; this TB validates the
-- FSM machinery, not the codec's register choices.

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

  -- Has to match the entry count in uda1380_init_fsm's INIT_TABLE.
  -- Kept as a separate constant so adding a register write in the
  -- FSM forces a deliberate update here.
  constant EXPECTED_TABLE_LEN : integer := 15;
  constant EXPECTED_BYTES     : integer := EXPECTED_TABLE_LEN * 3;

  signal clk         : std_logic := '0';
  signal reset       : std_logic := '1';

  signal i2c_ena     : std_logic;
  signal i2c_addr    : std_logic_vector(6 downto 0);
  signal i2c_rw      : std_logic;
  signal i2c_data_wr : std_logic_vector(7 downto 0);
  signal i2c_busy    : std_logic := '0';
  signal i2c_ack_err : std_logic := '0';
  signal init_done   : std_logic;

  signal sim_active  : boolean := true;

  -- Counts each 0->1 edge on busy as observed by the test stub
  -- (one per byte latched). Incremented inside the stub, sampled
  -- by the assertion process at end-of-sim.
  signal bytes_observed : integer := 0;
begin

  dut : entity work.uda1380_init_fsm
    generic map (INIT_DELAY_CYCLES => INIT_DELAY_CYCLES_TB)
    port map (
      clk         => clk,
      reset       => reset,
      i2c_ena     => i2c_ena,
      i2c_addr    => i2c_addr,
      i2c_rw      => i2c_rw,
      i2c_data_wr => i2c_data_wr,
      i2c_busy    => i2c_busy,
      i2c_ack_err => i2c_ack_err,
      init_done   => init_done
    );

  clk <= not clk after CLK_PERIOD/2 when sim_active;

  -- Stub i2c_master: when ena is high, pulse busy high once per
  -- "byte" (each pulse latches a new data_wr from the FSM). When
  -- the FSM drops ena, return to idle.
  --
  -- Real master timing is much slower; the stub uses tens-of-ns
  -- pulses so the whole boot sequence completes in microseconds.
  i2c_stub : process
  begin
    i2c_busy <= '0';
    loop
      wait until rising_edge(clk) and i2c_ena = '1';
      loop
        wait for 200 ns;            -- "byte transfer" time
        i2c_busy <= '1';
        bytes_observed <= bytes_observed + 1;

        -- Each byte must be addressed to DEVICE_ADDR as a write.
        assert i2c_addr = DEVICE_ADDR
          report "i2c_addr != DEVICE_ADDR during init"
          severity error;
        assert i2c_rw = '0'
          report "i2c_rw should be 0 (write) during init"
          severity error;

        wait for 100 ns;
        i2c_busy <= '0';
        wait for 50 ns;

        exit when i2c_ena = '0';     -- FSM finished this register
      end loop;
    end loop;
  end process;

  -- Stimulus + final assertion.
  driver : process
  begin
    reset <= '1';
    wait for 10 * CLK_PERIOD;
    reset <= '0';

    -- Wait for init_done with a generous timeout. 15 registers ×
    -- (3 × 350 ns + ~100 ns overhead) ≈ 17 us. 200 us margin.
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
