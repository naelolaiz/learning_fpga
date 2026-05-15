-- tb_regfile_rv32.vhd
--
-- Walks through the four behaviours that matter for the RV32I
-- register file:
--
--   1. After reset, every read port returns 0 (regs initialise to 0).
--   2. Writes propagate: write 0xDEADBEEF to x5, read it back next
--      cycle on both ports.
--   3. x0 is hardwired to zero: write something non-zero to x0, read
--      x0 the next cycle, observe 0.
--   4. WB->ID bypass: assert `we` writing 0xCAFE to x7 in the same
--      cycle a read port is addressing x7. The read port returns the
--      new wdata combinationally, not the stale stored value.

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity tb_regfile_rv32 is
end entity tb_regfile_rv32;

architecture testbench of tb_regfile_rv32 is
  constant CLK_PERIOD : time := 20 ns;

  signal sClk    : std_logic := '0';
  signal sWe     : std_logic := '0';
  signal sWaddr  : std_logic_vector(4  downto 0) := (others => '0');
  signal sWdata  : std_logic_vector(31 downto 0) := (others => '0');
  signal sRaddr1 : std_logic_vector(4  downto 0) := (others => '0');
  signal sRdata1 : std_logic_vector(31 downto 0);
  signal sRaddr2 : std_logic_vector(4  downto 0) := (others => '0');
  signal sRdata2 : std_logic_vector(31 downto 0);
  signal sSimulationActive : boolean := true;
begin

  dut : entity work.regfile_rv32
    port map (clk => sClk, we => sWe,
              waddr => sWaddr, wdata => sWdata,
              raddr1 => sRaddr1, rdata1 => sRdata1,
              raddr2 => sRaddr2, rdata2 => sRdata2);

  sClk <= not sClk after CLK_PERIOD/2 when sSimulationActive;

  driver : process
    -- Loop counter as a process variable with explicit init, so the
    -- FST trace shows a defined value before the loop body runs (a
    -- `for i in ...` implicit loop var renders as 'X' / red band
    -- before the first iteration in waveview).
    variable i : integer := 0;
  begin
    -- (1) Initial state: read every register, expect 0 everywhere.
    wait until falling_edge(sClk);
    i := 0;
    while i < 32 loop
      sRaddr1 <= std_logic_vector(to_unsigned(i, 5));
      sRaddr2 <= std_logic_vector(to_unsigned((i + 16) mod 32, 5));
      wait for 1 ns;       -- combinational settle
      assert sRdata1 = x"00000000"
        report "Initial read1 mismatch at x" & integer'image(i)
        severity error;
      assert sRdata2 = x"00000000"
        report "Initial read2 mismatch at x" & integer'image((i + 16) mod 32)
        severity error;
      i := i + 1;
    end loop;

    -- 32 iterations of `wait for 1 ns` left us mid-cycle. Re-align
    -- to a falling edge so the writes below are captured by a rising
    -- edge inside the next `wait until falling_edge` window.
    wait until falling_edge(sClk);

    -- (2) Write 0xDEADBEEF to x5; next cycle, read it back on both ports.
    sWe    <= '1';
    sWaddr <= "00101";       -- x5
    sWdata <= x"DEADBEEF";
    wait until falling_edge(sClk);
    sWe <= '0';
    sRaddr1 <= "00101";
    sRaddr2 <= "00101";
    wait for 1 ns;
    assert sRdata1 = x"DEADBEEF"
      report "Read1 after write to x5: got " & to_hstring(sRdata1)
      severity error;
    assert sRdata2 = x"DEADBEEF"
      report "Read2 after write to x5: got " & to_hstring(sRdata2)
      severity error;

    -- (3) Try to write to x0; it must stay 0.
    sWe    <= '1';
    sWaddr <= "00000";       -- x0
    sWdata <= x"FFFFFFFF";
    wait until falling_edge(sClk);
    sWe <= '0';
    sRaddr1 <= "00000";
    wait for 1 ns;
    assert sRdata1 = x"00000000"
      report "x0 must stay zero, got " & to_hstring(sRdata1)
      severity error;

    -- (4) Same-cycle write+read: with the falling-edge write design
    -- (and NO combinational bypass mux), reading the same register
    -- you're writing returns the OLD stored value within the same
    -- cycle. The new value lands at the falling edge. This is the
    -- behaviour the single-cycle CPU's combinational ALU needs —
    -- without it, an `addi t0, t0, 2` would close a combinational
    -- loop through the bypass mux.
    --
    -- Re-align to a falling edge so the timing below is unambiguous.
    wait until falling_edge(sClk);

    -- Pre-write: x7 is currently zero.
    sRaddr1 <= "00111";       -- x7
    wait for 1 ns;
    assert sRdata1 = x"00000000"
      report "Pre-write: x7 should still be zero, got " & to_hstring(sRdata1)
      severity error;

    -- Stage a write to x7, AND keep reading x7. Within this same
    -- cycle (before the next falling edge), the read MUST return the
    -- OLD value (no combinational bypass).
    sWe    <= '1';
    sWaddr <= "00111";        -- x7
    sWdata <= x"0000CAFE";
    sRaddr1 <= "00111";
    wait for 1 ns;
    assert sRdata1 = x"00000000"
      report "Same-cycle read should return OLD stored value (0), got "
           & to_hstring(sRdata1)
      severity error;

    -- Falling edge: write commits.
    wait until falling_edge(sClk);
    sWe <= '0';

    -- Post-commit: x7 now holds the new value.
    sRaddr1 <= "00111";
    wait for 1 ns;
    assert sRdata1 = x"0000CAFE"
      report "After write, x7 should hold 0000CAFE, got " & to_hstring(sRdata1)
      severity error;

    report "regfile_rv32 simulation done!" severity note;
    sSimulationActive <= false;
    wait;
  end process;

end architecture testbench;
