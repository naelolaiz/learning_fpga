-- forwarding_unit.vhd
--
-- Combinational forwarding unit for the 5-stage RV32I pipeline.
-- Watches what's about to commit in MEM and WB, decides whether the
-- value the ALU is about to consume in EX should come straight from
-- the regfile or be intercepted from a later stage's pending result.
--
-- Forwarding sources, in priority order (MEM wins over WB if both
-- target the same register, because MEM is the more recent value):
--
--   "10"  forward from MEM stage (one instruction ahead of EX)
--   "01"  forward from WB  stage (two instructions ahead of EX)
--   "00"  no forwarding — use the regfile's read port value
--
-- The x0-hardwired-zero invariant must be preserved: writes to x0
-- are dropped at the regfile and must NOT forward as if they
-- happened, otherwise a reader of x0 sees garbage from a later
-- instruction. The `_rd /= "00000"` guards are what enforce that.

library ieee;
use ieee.std_logic_1164.all;

entity forwarding_unit is
  port (
    -- Source registers read by the instruction currently in EX.
    ex_rs1   : in  std_logic_vector(4 downto 0);
    ex_rs2   : in  std_logic_vector(4 downto 0);
    -- MEM-stage write-back info (one instruction ahead of EX).
    mem_rd   : in  std_logic_vector(4 downto 0);
    mem_we   : in  std_logic;
    -- WB-stage write-back info (two instructions ahead of EX).
    wb_rd    : in  std_logic_vector(4 downto 0);
    wb_we    : in  std_logic;
    -- Mux selects for the ALU's two operands.
    fwd_a    : out std_logic_vector(1 downto 0);
    fwd_b    : out std_logic_vector(1 downto 0)
  );
end entity forwarding_unit;

architecture rtl of forwarding_unit is
begin

  fwd_a <= "10" when (mem_we = '1' and mem_rd /= "00000" and mem_rd = ex_rs1) else
           "01" when (wb_we  = '1' and wb_rd  /= "00000" and wb_rd  = ex_rs1) else
           "00";

  fwd_b <= "10" when (mem_we = '1' and mem_rd /= "00000" and mem_rd = ex_rs2) else
           "01" when (wb_we  = '1' and wb_rd  /= "00000" and wb_rd  = ex_rs2) else
           "00";

end architecture rtl;
