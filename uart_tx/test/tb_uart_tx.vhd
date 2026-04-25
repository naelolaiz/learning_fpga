-- tb_uart_tx.vhd
--
-- Drives a single byte through uart_tx and samples the output line at
-- the middle of each bit-time, then asserts the recovered byte equals
-- the byte that was sent. Uses a small CLKS_PER_BIT so the simulation
-- runs in microseconds.

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity tb_uart_tx is
end entity tb_uart_tx;

architecture testbench of tb_uart_tx is
  constant CLKS_PER_BIT : integer := 8;
  constant CLK_PERIOD   : time    := 20 ns;        -- 50 MHz
  constant BIT_TIME     : time    := CLKS_PER_BIT * CLK_PERIOD;

  signal sClk      : std_logic := '0';
  signal sTxStart  : std_logic := '0';
  signal sTxData   : std_logic_vector(7 downto 0) := x"A5";
  signal sTx       : std_logic;
  signal sTxBusy   : std_logic;
  signal sSimulationActive   : boolean := true;

  signal received  : std_logic_vector(7 downto 0);
begin

  dut : entity work.uart_tx
    generic map (CLKS_PER_BIT => CLKS_PER_BIT)
    port map (clk => sClk, tx_start => sTxStart, tx_data => sTxData,
              tx => sTx, tx_busy => sTxBusy);

  sClk <= not sClk after CLK_PERIOD/2 when sSimulationActive;

  driver : process
  begin
    wait for 4*CLK_PERIOD;
    assert sTx = '1' report "Idle line should be high" severity error;
    sTxStart <= '1';
    wait for CLK_PERIOD;
    sTxStart <= '0';

    -- After tx_start, the FSM needs one cycle to register S_START and
    -- another to drive tx low. Skip that, then half a bit time to
    -- land in the middle of the start bit.
    wait for CLK_PERIOD + BIT_TIME/2;
    assert sTx = '0' report "Start bit should be low" severity error;

    -- Sample the eight data bits at the middle of each bit-time.
    for i in 0 to 7 loop
      wait for BIT_TIME;
      received(i) <= sTx;
    end loop;
    wait for BIT_TIME;
    assert sTx = '1' report "Stop bit should be high" severity error;

    wait for BIT_TIME;
    assert received = sTxData
      report "Recovered byte mismatch" severity error;

    report "uart_tx simulation done!" severity note;
    sSimulationActive <= false;
    wait;
  end process;

end architecture testbench;
