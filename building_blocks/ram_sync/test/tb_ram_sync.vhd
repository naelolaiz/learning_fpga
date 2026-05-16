-- tb_ram_sync.vhd
--
-- Walks a small (4-bit wide, 16-deep) RAM through a write-then-read
-- pattern: writes addr -> ~addr at every location, then reads each
-- back. Shrinking WIDTH/DEPTH well below the synthesis defaults keeps
-- the FST waveform readable while still exercising the same datapath
-- as a 32x1024 instance.
--
-- Also covers a same-cycle write+read on the same address — the
-- expected behaviour is that `rdata` holds the OLD value because
-- read-before-write is what the BRAM-friendly pattern produces.

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity tb_ram_sync is
end entity tb_ram_sync;

architecture testbench of tb_ram_sync is
  constant WIDTH      : integer := 4;
  constant DEPTH      : integer := 16;
  constant ADDR_W     : integer := 4;
  constant CLK_PERIOD : time    := 20 ns;

  signal sClk   : std_logic := '0';
  signal sWe    : std_logic := '0';
  signal sAddr  : std_logic_vector(ADDR_W-1 downto 0) := (others => '0');
  signal sWdata : std_logic_vector(WIDTH-1  downto 0) := (others => '0');
  signal sRdata : std_logic_vector(WIDTH-1  downto 0);
  signal sSimulationActive : boolean := true;
begin

  dut : entity work.ram_sync
    generic map (WIDTH => WIDTH, ADDR_W => ADDR_W)
    port map (clk => sClk, we => sWe, addr => sAddr,
              wdata => sWdata, rdata => sRdata);

  sClk <= not sClk after CLK_PERIOD/2 when sSimulationActive;

  driver : process
    -- Loop counter declared as a process variable with explicit
    -- initial value, so the FST trace has a defined value before
    -- the loop starts (a `for i in 0 to N loop` shows the variable
    -- as 'X' / red band before the first iteration, even though
    -- functionally it's loop-scoped).
    variable i            : integer := 0;
    variable expected_old : std_logic_vector(WIDTH-1 downto 0);
  begin
    -- Write phase: addr i gets value (15 - i).
    wait until falling_edge(sClk);
    i := 0;
    while i < DEPTH loop
      sWe    <= '1';
      sAddr  <= std_logic_vector(to_unsigned(i, ADDR_W));
      sWdata <= std_logic_vector(to_unsigned(DEPTH-1-i, WIDTH));
      wait until falling_edge(sClk);
      i := i + 1;
    end loop;
    sWe <= '0';

    -- Read phase: one cycle of latency, then check.
    i := 0;
    while i < DEPTH loop
      sAddr <= std_logic_vector(to_unsigned(i, ADDR_W));
      wait until falling_edge(sClk);
      assert sRdata = std_logic_vector(to_unsigned(DEPTH-1-i, WIDTH))
        report "Read mismatch at addr "
             & integer'image(i)
             & ": got " & integer'image(to_integer(unsigned(sRdata)))
             & ", expected " & integer'image(DEPTH-1-i)
        severity error;
      i := i + 1;
    end loop;

    -- Read-before-write check: write a new value at addr 5 while
    -- reading addr 5 in the same cycle. rdata must carry the OLD
    -- value (which is DEPTH-1-5 = 10).
    expected_old := std_logic_vector(to_unsigned(DEPTH-1-5, WIDTH));
    sAddr  <= std_logic_vector(to_unsigned(5, ADDR_W));
    sWe    <= '1';
    sWdata <= x"3";
    wait until falling_edge(sClk);
    sWe <= '0';
    assert sRdata = expected_old
      report "Read-before-write: rdata should be old value 10 ("
           & integer'image(to_integer(unsigned(expected_old)))
           & "), got " & integer'image(to_integer(unsigned(sRdata)))
      severity error;

    -- Now read addr 5 again; the new value (3) should be visible.
    sAddr <= std_logic_vector(to_unsigned(5, ADDR_W));
    wait until falling_edge(sClk);
    assert sRdata = x"3"
      report "After write, addr 5 should read 3, got "
           & integer'image(to_integer(unsigned(sRdata)))
      severity error;

    report "ram_sync simulation done!" severity note;
    sSimulationActive <= false;
    wait;
  end process;

end architecture testbench;
