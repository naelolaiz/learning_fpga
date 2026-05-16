-- tb_hazard_detector.vhd
--
-- Six combinational vectors covering load-use and branch-taken
-- responses, plus the cross-product (load-use + branch at the same
-- time → both outputs assert, which is the pipeline's natural
-- "flush wins" case: the load-use stall is harmless when the
-- younger instruction is about to be flushed anyway).

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity tb_hazard_detector is
end entity tb_hazard_detector;

architecture testbench of tb_hazard_detector is

  signal sId_rs1, sId_rs2 : std_logic_vector(4 downto 0) := (others => '0');
  signal sEx_rd           : std_logic_vector(4 downto 0) := (others => '0');
  signal sEx_mem_read     : std_logic := '0';
  signal sBranch_taken    : std_logic := '0';
  signal sStall, sFlush   : std_logic;

  procedure check (
    constant tag       : in string;
    constant got_s     : in std_logic;
    constant exp_s     : in std_logic;
    constant got_f     : in std_logic;
    constant exp_f     : in std_logic) is
  begin
    assert got_s = exp_s
      report tag & ": stall expected '" & std_logic'image(exp_s)
             & "' got '" & std_logic'image(got_s) & "'"
      severity error;
    assert got_f = exp_f
      report tag & ": flush expected '" & std_logic'image(exp_f)
             & "' got '" & std_logic'image(got_f) & "'"
      severity error;
  end procedure;

begin

  dut : entity work.hazard_detector
    port map (id_rs1       => sId_rs1,
              id_rs2       => sId_rs2,
              ex_rd        => sEx_rd,
              ex_mem_read  => sEx_mem_read,
              branch_taken => sBranch_taken,
              stall        => sStall,
              flush        => sFlush);

  driver : process
  begin
    -- Case 1: no hazard at all.
    sId_rs1 <= "00101"; sId_rs2 <= "00110";
    sEx_rd  <= "01010"; sEx_mem_read <= '1'; sBranch_taken <= '0';
    wait for 1 ns;
    check("no-hazard", sStall, '0', sFlush, '0');

    -- Case 2: load-use on rs1 — stall.
    sId_rs1 <= "00111"; sId_rs2 <= "01000";
    sEx_rd  <= "00111"; sEx_mem_read <= '1'; sBranch_taken <= '0';
    wait for 1 ns;
    check("load-use-rs1", sStall, '1', sFlush, '0');

    -- Case 3: load-use on rs2 — stall.
    sId_rs1 <= "01100"; sId_rs2 <= "01101";
    sEx_rd  <= "01101"; sEx_mem_read <= '1'; sBranch_taken <= '0';
    wait for 1 ns;
    check("load-use-rs2", sStall, '1', sFlush, '0');

    -- Case 4: ex_rd matches but ex_mem_read=0 (an ALU op, not a load)
    -- — forwarding will cover it; no stall needed.
    sId_rs1 <= "10000"; sId_rs2 <= "10001";
    sEx_rd  <= "10000"; sEx_mem_read <= '0'; sBranch_taken <= '0';
    wait for 1 ns;
    check("alu-rd-match-noload", sStall, '0', sFlush, '0');

    -- Case 5: load that writes x0 — must NOT stall (the value is
    -- discarded by the regfile anyway; the ID-side x0 read is zero
    -- regardless).
    sId_rs1 <= "00000"; sId_rs2 <= "00000";
    sEx_rd  <= "00000"; sEx_mem_read <= '1'; sBranch_taken <= '0';
    wait for 1 ns;
    check("load-into-x0", sStall, '0', sFlush, '0');

    -- Case 6: taken branch — flush.
    sId_rs1 <= "00000"; sId_rs2 <= "00000";
    sEx_rd  <= "00000"; sEx_mem_read <= '0'; sBranch_taken <= '1';
    wait for 1 ns;
    check("branch-taken", sStall, '0', sFlush, '1');

    -- Case 7: load-use AND taken branch in the same cycle —
    -- both fire (the pipeline handles this by flushing the
    -- younger insn that would have stalled).
    sId_rs1 <= "00111"; sId_rs2 <= "01000";
    sEx_rd  <= "00111"; sEx_mem_read <= '1'; sBranch_taken <= '1';
    wait for 1 ns;
    check("load-use-and-branch", sStall, '1', sFlush, '1');

    report "tb_hazard_detector: all cases passed" severity note;
    wait;
  end process;

end architecture testbench;
