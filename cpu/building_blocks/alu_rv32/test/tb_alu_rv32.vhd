-- tb_alu_rv32.vhd
--
-- Walks each ALU op through a handful of vectors that exercise the
-- corner the op is most likely to get wrong:
--
--   ADD/SUB    boundary roll-over (FFFF_FFFF + 1, 0 - 1)
--   AND/OR/XOR random bit pattern
--   SLL/SRL    shift-by-0 and shift-by-31
--   SRA        sign-extension of a negative operand
--   SLT/SLTU   the sign-vs-magnitude split (-1 vs 1)
--   zero flag  asserted only when result is exactly zero
--
-- The harness keeps each scenario small so a failure points at the
-- exact op + operand combo via a `report` line in the assert.

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity tb_alu_rv32 is
end entity tb_alu_rv32;

architecture testbench of tb_alu_rv32 is
  signal sA, sB, sR : std_logic_vector(31 downto 0) := (others => '0');
  signal sOp        : std_logic_vector(3  downto 0) := (others => '0');
  signal sZero      : std_logic;

  -- Run a single op and assert the result/zero flag in one place.
  -- Wrapped as a procedure so each scenario reads as one line.
  --
  -- `r` is `signal in`: a `signal inout` parameter would add a second
  -- driver to sR whose unwritten default value ('U') resolves with
  -- the ALU's real driver and turns the captured result into 'X'
  -- bits. Read-only access via `in` avoids the driver entirely.
  procedure check (
    signal a, b    : out std_logic_vector(31 downto 0);
    signal op      : out std_logic_vector(3  downto 0);
    signal r       : in  std_logic_vector(31 downto 0);
    constant av    : in std_logic_vector(31 downto 0);
    constant bv    : in std_logic_vector(31 downto 0);
    constant opv   : in std_logic_vector(3  downto 0);
    constant exp   : in std_logic_vector(31 downto 0);
    constant tag   : in string
  ) is
  begin
    a  <= av;
    b  <= bv;
    op <= opv;
    wait for 1 ns;
    assert r = exp
      report tag & ": expected " & to_hstring(exp) & ", got " & to_hstring(r)
      severity error;
  end procedure;
begin

  dut : entity work.alu_rv32
    port map (a => sA, b => sB, op => sOp, result => sR, zero => sZero);

  driver : process
  begin
    -- ADD: 1 + 2 = 3, FFFF_FFFF + 1 = 0 (wraps).
    check(sA, sB, sOp, sR, x"00000001", x"00000002", "0000", x"00000003", "ADD basic");
    check(sA, sB, sOp, sR, x"FFFFFFFF", x"00000001", "0000", x"00000000", "ADD wrap");
    assert sZero = '1' report "zero flag should fire on ADD wrap to 0" severity error;

    -- SUB: 5 - 3 = 2, 0 - 1 = FFFF_FFFF.
    check(sA, sB, sOp, sR, x"00000005", x"00000003", "0001", x"00000002", "SUB basic");
    check(sA, sB, sOp, sR, x"00000000", x"00000001", "0001", x"FFFFFFFF", "SUB negative wrap");

    -- AND/OR/XOR.
    check(sA, sB, sOp, sR, x"AAAAAAAA", x"55555555", "0010", x"00000000", "AND alternating bits");
    check(sA, sB, sOp, sR, x"AAAAAAAA", x"55555555", "0011", x"FFFFFFFF", "OR alternating bits");
    check(sA, sB, sOp, sR, x"FFFFFFFF", x"0F0F0F0F", "0100", x"F0F0F0F0", "XOR pattern");

    -- SLL: shift by 0 (identity), shift by 31 (move bit0 to bit31).
    check(sA, sB, sOp, sR, x"DEADBEEF", x"00000000", "0101", x"DEADBEEF", "SLL by 0");
    check(sA, sB, sOp, sR, x"00000001", x"0000001F", "0101", x"80000000", "SLL by 31");

    -- SRL: shift by 31 of FFFF_FFFF -> 1 (logical, zero-fill).
    check(sA, sB, sOp, sR, x"FFFFFFFF", x"0000001F", "0110", x"00000001", "SRL by 31, logical");

    -- SRA: shift by 31 of FFFF_FFFF -> FFFF_FFFF (arithmetic, sign-fill).
    check(sA, sB, sOp, sR, x"FFFFFFFF", x"0000001F", "0111", x"FFFFFFFF", "SRA by 31, sign-fill");

    -- SRA: shift -8 (FFFF_FFF8) by 1 -> -4 (FFFF_FFFC), proves sign extension.
    check(sA, sB, sOp, sR, x"FFFFFFF8", x"00000001", "0111", x"FFFFFFFC", "SRA -8 by 1");

    -- SLT: signed compare.  -1 < 1 -> 1.   1 < -1 -> 0.
    check(sA, sB, sOp, sR, x"FFFFFFFF", x"00000001", "1000", x"00000001", "SLT -1 < 1");
    check(sA, sB, sOp, sR, x"00000001", x"FFFFFFFF", "1000", x"00000000", "SLT 1 < -1 (false)");

    -- SLTU: unsigned compare.  0xFFFF_FFFF as unsigned is huge, so 1 < that -> 1.
    check(sA, sB, sOp, sR, x"00000001", x"FFFFFFFF", "1001", x"00000001", "SLTU 1 < big");
    check(sA, sB, sOp, sR, x"FFFFFFFF", x"00000001", "1001", x"00000000", "SLTU big < 1 (false)");

    -- Illegal op -> result 0, zero flag asserted.
    check(sA, sB, sOp, sR, x"DEADBEEF", x"CAFEBABE", "1111", x"00000000", "Illegal op -> 0");
    assert sZero = '1' report "zero flag should fire on illegal-op zero result" severity error;

    report "alu_rv32 simulation done!" severity note;
    wait;
  end process;

end architecture testbench;
