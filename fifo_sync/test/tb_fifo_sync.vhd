-- tb_fifo_sync.vhd
--
-- Pushes DEPTH words in, asserts `full`, drains them, asserts the
-- ordering and `empty`. Concurrent read/write behaviour (the tricky
-- case where both enables are high on the same cycle and occupancy
-- must stay constant) is covered by the sibling
-- `tb_fifo_sync_overlapping.vhd`.

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity tb_fifo_sync is
end entity tb_fifo_sync;

architecture testbench of tb_fifo_sync is
  constant DATA_WIDTH : integer := 8;
  constant DEPTH      : integer := 8;
  constant CLK_PERIOD : time    := 20 ns;

  signal sClk    : std_logic := '0';
  signal sRst    : std_logic := '1';
  signal sWrEn   : std_logic := '0';
  signal sWrData : std_logic_vector(DATA_WIDTH-1 downto 0) := (others => '0');
  signal sRdEn   : std_logic := '0';
  signal sRdData : std_logic_vector(DATA_WIDTH-1 downto 0);
  signal sEmpty  : std_logic;
  signal sFull   : std_logic;
  signal sActive : boolean := true;
begin

  dut : entity work.fifo_sync
    generic map (DATA_WIDTH => DATA_WIDTH, DEPTH => DEPTH)
    port map (clk => sClk, rst => sRst,
              wr_en => sWrEn, wr_data => sWrData,
              rd_en => sRdEn, rd_data => sRdData,
              empty => sEmpty, full => sFull);

  sClk <= not sClk after CLK_PERIOD/2 when sActive;

  driver : process
  begin
    -- Reset window.
    wait for 2*CLK_PERIOD;
    sRst <= '0';
    wait for CLK_PERIOD;
    assert sEmpty = '1' report "Should be empty after reset" severity error;
    assert sFull  = '0' report "Should not be full after reset" severity error;

    -- Push DEPTH values 0..DEPTH-1.
    for i in 0 to DEPTH-1 loop
      sWrEn   <= '1';
      sWrData <= std_logic_vector(to_unsigned(i, DATA_WIDTH));
      wait for CLK_PERIOD;
    end loop;
    sWrEn <= '0';
    wait for CLK_PERIOD;
    assert sFull = '1' report "Should be full after DEPTH writes" severity error;

    -- Drain and verify FIFO order.
    for i in 0 to DEPTH-1 loop
      sRdEn <= '1';
      wait for CLK_PERIOD;
      assert sRdData = std_logic_vector(to_unsigned(i, DATA_WIDTH))
        report "Drained value mismatch at " & integer'image(i) severity error;
    end loop;
    sRdEn <= '0';
    wait for CLK_PERIOD;
    assert sEmpty = '1' report "Should be empty after draining" severity error;

    report "fifo_sync simulation done!" severity note;
    sActive <= false;
    wait;
  end process;

end architecture testbench;
