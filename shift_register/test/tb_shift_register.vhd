-- tb_shift_register.vhd
--
-- Loads A5 into the register, then shifts in 1, 0, 1 and asserts the
-- final parallel/serial outputs. Stimulus is driven on the falling
-- edge of the clock so each rising edge captures a stable input.

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity tb_shift_register is
end entity tb_shift_register;

architecture testbench of tb_shift_register is
  constant WIDTH      : integer := 8;
  constant CLK_PERIOD : time    := 20 ns;
  signal sClk     : std_logic := '0';
  signal sLoad    : std_logic := '0';
  signal sLoadD   : std_logic_vector(WIDTH-1 downto 0) := x"A5";
  signal sIn      : std_logic := '0';
  signal sPOut    : std_logic_vector(WIDTH-1 downto 0);
  signal sSOut    : std_logic;
  signal sActive  : boolean := true;
begin

  dut : entity work.shift_register
    generic map (WIDTH => WIDTH)
    port map (clk => sClk, load => sLoad, load_data => sLoadD,
              serial_in => sIn, parallel_out => sPOut, serial_out => sSOut);

  sClk <= not sClk after CLK_PERIOD/2 when sActive;

  driver : process
  begin
    -- Synchronise to a falling edge before driving anything.
    wait until falling_edge(sClk);

    -- Pulse load high for exactly one cycle.
    sLoad <= '1';
    wait until falling_edge(sClk);
    sLoad <= '0';
    -- The rising edge just before this falling edge captured A5.
    assert sPOut = x"A5"
      report "Loaded value mismatch: " & integer'image(to_integer(unsigned(sPOut)))
      severity error;

    -- start    = 10100101 (A5)
    -- <<1, in=1: 01001011 (4B), serial_out = 1
    -- <<1, in=0: 10010110 (96), serial_out = 0
    -- <<1, in=1: 00101101 (2D), serial_out = 1
    sIn <= '1';
    wait until falling_edge(sClk);
    sIn <= '0';
    wait until falling_edge(sClk);
    sIn <= '1';
    wait until falling_edge(sClk);

    assert sPOut = x"2D"
      report "After three shifts, parallel mismatch: got "
           & integer'image(to_integer(unsigned(sPOut)))
      severity error;
    assert sSOut = '0'
      report "After three shifts, serial_out should be 0"
      severity error;

    report "shift_register simulation done!" severity note;
    sActive <= false;
    wait;
  end process;

end architecture testbench;
