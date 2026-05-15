-- alu_rv32.vhd
--
-- 32-bit ALU covering every RV32I integer op the single-cycle and
-- pipelined CPUs need. Pure combinational; the select code on `op`
-- chooses one of ten operations and the result lands on `result` one
-- propagation delay later. The `zero` flag mirrors `result == 0` and
-- is what the branch unit uses for BEQ/BNE; for the signed/unsigned
-- compare branches (BLT/BGE/BLTU/BGEU) the decoder issues SLT/SLTU
-- and consults `result(0)` instead.
--
-- Op encoding (4-bit, internal — the decoder maps RISC-V funct3/funct7
-- bits to this):
--
--   0000  ADD     rd = a + b
--   0001  SUB     rd = a - b
--   0010  AND     rd = a and b
--   0011  OR      rd = a or  b
--   0100  XOR     rd = a xor b
--   0101  SLL     rd = a sll b(4:0)
--   0110  SRL     rd = a srl b(4:0)            -- logical (zero-fill)
--   0111  SRA     rd = a sra b(4:0)            -- arithmetic (sign-fill)
--   1000  SLT     rd = (signed(a)   < signed(b))   ? 1 : 0
--   1001  SLTU    rd = (unsigned(a) < unsigned(b)) ? 1 : 0
--
-- Anything outside that range latches result := 0; this keeps the
-- output deterministic if the decoder ever issues an `illegal` op
-- without independently squashing reg-write.
--
-- Avoiding `abs()`: per the project_toolchain_quirks note,
-- yosys+ghdl-plugin trips on integer `abs()`; we use shift_right on
-- signed/unsigned operands directly, which both GHDL and yosys
-- swallow without complaint.

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity alu_rv32 is
  port (
    a      : in  std_logic_vector(31 downto 0);
    b      : in  std_logic_vector(31 downto 0);
    op     : in  std_logic_vector(3  downto 0);
    result : out std_logic_vector(31 downto 0);
    zero   : out std_logic
  );
end entity alu_rv32;

architecture rtl of alu_rv32 is
  -- ALU op constants. Kept in the architecture so the decoder
  -- (separate file) and any other consumer reference these by name —
  -- not by raw 4-bit literals scattered across the codebase.
  constant ALU_ADD  : std_logic_vector(3 downto 0) := "0000";
  constant ALU_SUB  : std_logic_vector(3 downto 0) := "0001";
  constant ALU_AND  : std_logic_vector(3 downto 0) := "0010";
  constant ALU_OR   : std_logic_vector(3 downto 0) := "0011";
  constant ALU_XOR  : std_logic_vector(3 downto 0) := "0100";
  constant ALU_SLL  : std_logic_vector(3 downto 0) := "0101";
  constant ALU_SRL  : std_logic_vector(3 downto 0) := "0110";
  constant ALU_SRA  : std_logic_vector(3 downto 0) := "0111";
  constant ALU_SLT  : std_logic_vector(3 downto 0) := "1000";
  constant ALU_SLTU : std_logic_vector(3 downto 0) := "1001";

  signal sa     : signed(31 downto 0);
  signal sb     : signed(31 downto 0);
  signal ua     : unsigned(31 downto 0);
  signal ub     : unsigned(31 downto 0);
  signal shamt  : integer range 0 to 31;
  signal r_int  : std_logic_vector(31 downto 0);
begin

  sa    <= signed(a);
  sb    <= signed(b);
  ua    <= unsigned(a);
  ub    <= unsigned(b);
  shamt <= to_integer(unsigned(b(4 downto 0)));

  process (op, a, b, sa, sb, ua, ub, shamt)
  begin
    case op is
      when ALU_ADD  => r_int <= std_logic_vector(unsigned(a) + unsigned(b));
      when ALU_SUB  => r_int <= std_logic_vector(unsigned(a) - unsigned(b));
      when ALU_AND  => r_int <= a and b;
      when ALU_OR   => r_int <= a or  b;
      when ALU_XOR  => r_int <= a xor b;
      when ALU_SLL  => r_int <= std_logic_vector(shift_left (ua, shamt));
      when ALU_SRL  => r_int <= std_logic_vector(shift_right(ua, shamt));
      when ALU_SRA  => r_int <= std_logic_vector(shift_right(sa, shamt));
      when ALU_SLT  =>
        if sa < sb then r_int <= x"00000001"; else r_int <= x"00000000"; end if;
      when ALU_SLTU =>
        if ua < ub then r_int <= x"00000001"; else r_int <= x"00000000"; end if;
      when others   => r_int <= (others => '0');
    end case;
  end process;

  result <= r_int;
  zero   <= '1' when r_int = x"00000000" else '0';

end architecture rtl;
