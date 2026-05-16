-- hazard_detector.vhd
--
-- Combinational hazard controller for the 5-stage RV32I pipeline.
-- Handles the two structural problems forwarding alone can't fix:
--
--   * LOAD-USE (RAW where producer is a load): forwarding can't
--     deliver because the loaded value isn't available until the
--     end of MEM, but the consumer is already in EX. Solution:
--     one-cycle bubble — stall PC + IF/ID, insert NOP into ID/EX,
--     then forwarding handles the rest on the next cycle.
--
--   * CONTROL HAZARD on a taken branch: branches resolve in EX, by
--     which point two younger instructions have already been
--     fetched into IF and ID. Solution: flush both with NOPs on
--     the cycle after the branch resolves.
--
-- Outputs are active-high enables/flushes. The pipeline file
-- consumes them as: stall_pc/stall_if_id freeze the corresponding
-- register; bubble_id_ex/flush_if_id/flush_id_ex force the next
-- value of the corresponding register to NOP (zeros + we=0).

library ieee;
use ieee.std_logic_1164.all;

entity hazard_detector is
  port (
    -- ID-stage instruction's source registers (the consumer).
    id_rs1       : in  std_logic_vector(4 downto 0);
    id_rs2       : in  std_logic_vector(4 downto 0);
    -- EX-stage instruction info (the producer, if a load).
    ex_rd        : in  std_logic_vector(4 downto 0);
    ex_mem_read  : in  std_logic;
    -- Branch resolution from EX.
    branch_taken : in  std_logic;
    -- Stall PC + IF/ID, bubble ID/EX (load-use response).
    stall        : out std_logic;
    -- Flush IF/ID + ID/EX (taken-branch response).
    flush        : out std_logic
  );
end entity hazard_detector;

architecture rtl of hazard_detector is
  signal load_use : std_logic;
begin

  -- Load-use: stall if the instruction currently in EX is a load
  -- AND its destination matches either source register of the
  -- instruction currently in ID. x0 reads always resolve to zero
  -- regardless of forwarding, so x0 source matches don't need a
  -- stall.
  load_use <= '1' when (ex_mem_read = '1' and ex_rd /= "00000" and
                        (ex_rd = id_rs1 or ex_rd = id_rs2)) else '0';

  stall <= load_use;
  flush <= branch_taken;

end architecture rtl;
