-- tb_forwarding_unit.vhd
--
-- Exhaustive priority / guard checks for the forwarding unit.
-- The DUT is pure combinational, so the test pattern is just a
-- sequence of input vectors with the expected fwd_a/fwd_b values
-- spelled out alongside each one — no clock involved.

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity tb_forwarding_unit is
end entity tb_forwarding_unit;

architecture testbench of tb_forwarding_unit is

  signal sEx_rs1, sEx_rs2 : std_logic_vector(4 downto 0) := (others => '0');
  signal sMem_rd, sWb_rd  : std_logic_vector(4 downto 0) := (others => '0');
  signal sMem_we, sWb_we  : std_logic := '0';
  signal sFwd_a, sFwd_b   : std_logic_vector(1 downto 0);

  procedure check (
    constant tag    : in string;
    constant got_a  : in std_logic_vector(1 downto 0);
    constant exp_a  : in std_logic_vector(1 downto 0);
    constant got_b  : in std_logic_vector(1 downto 0);
    constant exp_b  : in std_logic_vector(1 downto 0)) is
  begin
    assert got_a = exp_a
      report tag & ": fwd_a expected " & to_string(exp_a)
             & " got " & to_string(got_a)
      severity error;
    assert got_b = exp_b
      report tag & ": fwd_b expected " & to_string(exp_b)
             & " got " & to_string(got_b)
      severity error;
  end procedure;

begin

  dut : entity work.forwarding_unit
    port map (ex_rs1 => sEx_rs1, ex_rs2 => sEx_rs2,
              mem_rd => sMem_rd, mem_we => sMem_we,
              wb_rd  => sWb_rd,  wb_we  => sWb_we,
              fwd_a  => sFwd_a,  fwd_b  => sFwd_b);

  driver : process
  begin
    -- Case 1: no hazard at all — both fwds should be "00".
    sEx_rs1 <= "00101"; sEx_rs2 <= "00110";
    sMem_rd <= "01010"; sMem_we <= '1';
    sWb_rd  <= "01011"; sWb_we  <= '1';
    wait for 1 ns;
    check("no-hazard", sFwd_a, "00", sFwd_b, "00");

    -- Case 2: MEM forwards to A.
    sEx_rs1 <= "00111"; sEx_rs2 <= "01000";
    sMem_rd <= "00111"; sMem_we <= '1';
    sWb_rd  <= "11111"; sWb_we  <= '1';
    wait for 1 ns;
    check("mem-to-a", sFwd_a, "10", sFwd_b, "00");

    -- Case 3: WB forwards to B (no MEM match).
    sEx_rs1 <= "01100"; sEx_rs2 <= "01101";
    sMem_rd <= "11110"; sMem_we <= '1';
    sWb_rd  <= "01101"; sWb_we  <= '1';
    wait for 1 ns;
    check("wb-to-b", sFwd_a, "00", sFwd_b, "01");

    -- Case 4: BOTH stages target the same register — MEM wins.
    sEx_rs1 <= "01001"; sEx_rs2 <= "00000";
    sMem_rd <= "01001"; sMem_we <= '1';
    sWb_rd  <= "01001"; sWb_we  <= '1';
    wait for 1 ns;
    check("mem-wins-over-wb", sFwd_a, "10", sFwd_b, "00");

    -- Case 5: x0 must not forward, ever — writes to x0 are dropped
    -- at the regfile, so the EX-side reader sees zero (from regfile),
    -- NOT garbage from a later instruction.
    sEx_rs1 <= "00000"; sEx_rs2 <= "00000";
    sMem_rd <= "00000"; sMem_we <= '1';
    sWb_rd  <= "00000"; sWb_we  <= '1';
    wait for 1 ns;
    check("x0-never-forwards", sFwd_a, "00", sFwd_b, "00");

    -- Case 6: we=0 disables forwarding even when rd matches.
    sEx_rs1 <= "01010"; sEx_rs2 <= "01011";
    sMem_rd <= "01010"; sMem_we <= '0';
    sWb_rd  <= "01011"; sWb_we  <= '0';
    wait for 1 ns;
    check("we-low-blocks", sFwd_a, "00", sFwd_b, "00");

    -- Case 7: MEM forwards to A AND WB forwards to B independently.
    sEx_rs1 <= "00011"; sEx_rs2 <= "00100";
    sMem_rd <= "00011"; sMem_we <= '1';
    sWb_rd  <= "00100"; sWb_we  <= '1';
    wait for 1 ns;
    check("mem-a-wb-b", sFwd_a, "10", sFwd_b, "01");

    report "tb_forwarding_unit: all cases passed" severity note;
    wait;
  end process;

end architecture testbench;
