-- tb_uart_rx.vhd
--
-- Bit-bangs three known UART frames into uart_rx and asserts each
-- captured byte matches what was sent. Also covers the framing-error
-- path: a frame whose stop bit is low must NOT pulse rx_valid.
--
-- A small CLKS_PER_BIT keeps the simulation in microseconds. To
-- send a frame we hold each bit on the rx line for exactly
-- CLKS_PER_BIT clock periods (start = '0', then 8 data bits LSB
-- first, then stop = '1'). Between frames the line idles high.

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity tb_uart_rx is
end entity tb_uart_rx;

architecture testbench of tb_uart_rx is
  constant CLKS_PER_BIT : integer := 8;
  constant CLK_PERIOD   : time    := 20 ns;            -- 50 MHz
  constant BIT_TIME     : time    := CLKS_PER_BIT * CLK_PERIOD;

  signal sClk      : std_logic := '0';
  signal sRx       : std_logic := '1';                 -- idle high
  signal sRxData   : std_logic_vector(7 downto 0);
  signal sRxValid  : std_logic;

  signal sSimulationActive : boolean                       := true;
  signal sLastCaptured     : std_logic_vector(7 downto 0)  := (others => '0');
  signal sValidPulseCount  : integer                       := 0;

  -- Drive a complete 8N1 frame onto `line`. Optional stop_bit_val
  -- lets the caller force a framing error by driving stop low.
  procedure send_byte (
    signal   line    : out std_logic;
    constant b       : in  std_logic_vector(7 downto 0);
    constant stop_bv : in  std_logic := '1'
  ) is
    -- Explicit-init variable so the FST trace doesn't show 'X' for
    -- the loop counter before the loop body runs.
    variable i : integer := 0;
  begin
    -- Start bit
    line <= '0';
    wait for BIT_TIME;
    -- 8 data bits, LSB first
    i := 0;
    while i < 8 loop
      line <= b(i);
      wait for BIT_TIME;
      i := i + 1;
    end loop;
    -- Stop bit (or framing-error filler)
    line <= stop_bv;
    wait for BIT_TIME;
    -- Return the line to idle
    line <= '1';
  end procedure;
begin

  dut : entity work.uart_rx
    generic map (CLKS_PER_BIT => CLKS_PER_BIT)
    port map (clk => sClk, rx => sRx,
              rx_data => sRxData, rx_valid => sRxValid);

  sClk <= not sClk after CLK_PERIOD/2 when sSimulationActive;

  -- Watcher: latches the captured byte every time rx_valid pulses,
  -- and counts the pulses so the framing-error test can confirm
  -- no spurious valid was emitted.
  watcher : process (sClk)
  begin
    if rising_edge(sClk) then
      if sRxValid = '1' then
        sLastCaptured    <= sRxData;
        sValidPulseCount <= sValidPulseCount + 1;
      end if;
    end if;
  end process;

  driver : process
    variable expected_pulse_count : integer := 0;
  begin
    -- Give the synchroniser a few clocks to settle on idle-high.
    wait for 4*CLK_PERIOD;
    assert sRx = '1'      report "rx must idle high"     severity error;
    assert sRxValid = '0' report "rx_valid must idle low" severity error;

    -- Send 0xA5 (alternating bit pattern)
    send_byte(sRx, x"A5");
    -- Allow the FSM to clock the stop sample + drop back to idle
    wait for 2*BIT_TIME;
    expected_pulse_count := expected_pulse_count + 1;
    assert sValidPulseCount = expected_pulse_count
      report "0xA5: rx_valid did not pulse" severity error;
    assert sLastCaptured = x"A5"
      report "0xA5: captured byte mismatch: got " & to_hstring(sLastCaptured)
      severity error;

    -- Send 0x00 (all-zero data bits — exercises the 1->0 transitions
    -- and proves the FSM doesn't treat the all-zero data window as
    -- a stretched start bit).
    send_byte(sRx, x"00");
    wait for 2*BIT_TIME;
    expected_pulse_count := expected_pulse_count + 1;
    assert sValidPulseCount = expected_pulse_count
      report "0x00: rx_valid did not pulse" severity error;
    assert sLastCaptured = x"00"
      report "0x00: captured byte mismatch: got " & to_hstring(sLastCaptured)
      severity error;

    -- Send 0xFF (all-one data bits)
    send_byte(sRx, x"FF");
    wait for 2*BIT_TIME;
    expected_pulse_count := expected_pulse_count + 1;
    assert sValidPulseCount = expected_pulse_count
      report "0xFF: rx_valid did not pulse" severity error;
    assert sLastCaptured = x"FF"
      report "0xFF: captured byte mismatch: got " & to_hstring(sLastCaptured)
      severity error;

    -- Framing error: drive a frame whose stop bit is LOW. The FSM
    -- should silently drop the byte (no rx_valid pulse). The pulse
    -- count must stay where it is.
    send_byte(sRx, x"5A", stop_bv => '0');
    wait for 2*BIT_TIME;
    assert sValidPulseCount = expected_pulse_count
      report "Framing-error byte should NOT have pulsed rx_valid (count went up)"
      severity error;

    report "uart_rx simulation done!" severity note;
    sSimulationActive <= false;
    wait;
  end process;

end architecture testbench;
