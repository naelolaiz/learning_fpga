library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

-- Serial2Parallel: basic shift-then-snapshot case.
--
-- Shifts in a known 8-bit pattern (MSB-first), pulses inPrint, and
-- asserts that the latched outData matches the expected value.
--
-- A shift_register variant of this lives at building_blocks/shift_register;
-- this TB verifies that the wrapper still presents the same shift
-- semantic to the outside (LSB receives serial_in on each clock).

entity tb_serial_to_parallel_basic is
end tb_serial_to_parallel_basic;

architecture testbench of tb_serial_to_parallel_basic is
  constant N : integer := 8;
  constant PATTERN : std_logic_vector(N-1 downto 0) := "10110100";  -- 0xB4

  signal sClock : std_logic := '0';
  signal sData  : std_logic := '0';
  signal sPrint : std_logic := '0';
  signal sOut   : std_logic_vector(N-1 downto 0);
  signal sSimulationActive : boolean := true;

begin

  DUT : entity work.Serial2Parallel
    generic map (NUMBER_OF_BITS => N)
    port map (inClock => sClock,
              inData  => sData,
              inPrint => sPrint,
              outData => sOut);

  sClock <= not sClock after 10 ns when sSimulationActive;

  STIMULUS : process
  begin
    -- Drive bits MSB-first; one bit per clock period. Drive on falling
    -- edges so the rising edge captures a stable input.
    for i in N-1 downto 0 loop
      wait until falling_edge(sClock);
      sData  <= PATTERN(i);
      sPrint <= '0';
    end loop;

    -- One more falling edge with inData stable, then pulse print high
    -- for one rising edge — that snapshot should latch the full pattern.
    wait until falling_edge(sClock);
    sPrint <= '1';
    wait until rising_edge(sClock);
    wait until falling_edge(sClock);
    sPrint <= '0';

    -- One more clock for the snapshot to land on the bus.
    wait until rising_edge(sClock);

    assert sOut = PATTERN
       report "outData mismatch: got " & integer'image(to_integer(unsigned(sOut)))
            & ", expected " & integer'image(to_integer(unsigned(PATTERN)))
       severity failure;

    sSimulationActive <= false;
    wait;
  end process;

end testbench;
