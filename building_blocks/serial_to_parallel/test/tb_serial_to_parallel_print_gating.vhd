library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

-- Serial2Parallel: print-gating case.
--
-- Confirms two properties of the snapshot register:
--   (A) outData stays at its initial value while inPrint = '0',
--       even though new bits are being shifted in (i.e. the
--       internal shift state is changing but outData is gated).
--   (B) After a single inPrint pulse, outData latches the *current*
--       parallel state, and a second wave of shifting (with
--       inPrint = '0') does not perturb that snapshot.
--
-- Pattern A = 0xB4, Pattern B = 0x53. Both are 8 bits and have
-- distinct nibbles in every position so an "off-by-one shift"
-- regression would still surface.

entity tb_serial_to_parallel_print_gating is
end tb_serial_to_parallel_print_gating;

architecture testbench of tb_serial_to_parallel_print_gating is
  constant N : integer := 8;
  constant PATTERN_A : std_logic_vector(N-1 downto 0) := "10110100";  -- 0xB4
  constant PATTERN_B : std_logic_vector(N-1 downto 0) := "01010011";  -- 0x53

  signal sClock : std_logic := '0';
  signal sData  : std_logic := '0';
  signal sPrint : std_logic := '0';
  signal sOut   : std_logic_vector(N-1 downto 0);
  signal sSimulationActive : boolean := true;

  procedure shift_in(signal clk    : in  std_logic;
                     signal datBus : out std_logic;
                     constant pat  : in  std_logic_vector(N-1 downto 0)) is
  begin
    for i in N-1 downto 0 loop
      wait until falling_edge(clk);
      datBus <= pat(i);
    end loop;
  end procedure;
begin

  DUT : entity work.Serial2Parallel
    generic map (NUMBER_OF_BITS => N)
    port map (inClock => sClock,
              inData  => sData,
              inPrint => sPrint,
              outData => sOut);

  sClock <= not sClock after 10 ns when sSimulationActive;

  STIMULUS : process
    variable snapshotA : std_logic_vector(N-1 downto 0);
  begin
    -- (A) Shift in PATTERN_A with print=0. outData must stay at 0
    -- the whole time.
    sPrint <= '0';
    shift_in(sClock, sData, PATTERN_A);

    wait until rising_edge(sClock);
    assert sOut = std_logic_vector(to_unsigned(0, N))
       report "outData changed while inPrint=0; snapshot register is leaking"
       severity failure;

    -- (B) Pulse print for one rising edge. This snapshots PATTERN_A.
    wait until falling_edge(sClock);
    sPrint <= '1';
    wait until rising_edge(sClock);
    wait until falling_edge(sClock);
    sPrint <= '0';

    -- One more rising edge so the snapshot is observable.
    wait until rising_edge(sClock);
    assert sOut = PATTERN_A
       report "snapshot mismatch after first print pulse"
       severity failure;
    snapshotA := sOut;

    -- Now shift in a *different* pattern with print=0. outData must
    -- stay at the previous snapshot (snapshotA), even though the
    -- internal shift state changes.
    shift_in(sClock, sData, PATTERN_B);

    wait until rising_edge(sClock);
    assert sOut = snapshotA
       report "snapshot drifted while inPrint=0 during second wave"
       severity failure;

    -- One more print pulse should now capture PATTERN_B.
    wait until falling_edge(sClock);
    sPrint <= '1';
    wait until rising_edge(sClock);
    wait until falling_edge(sClock);
    sPrint <= '0';
    wait until rising_edge(sClock);

    assert sOut = PATTERN_B
       report "second snapshot did not capture PATTERN_B"
       severity failure;

    sSimulationActive <= false;
    wait;
  end process;

end testbench;
