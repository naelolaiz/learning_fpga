-- immgen_rv32.vhd
--
-- RV32I immediate generator. Combinational. Takes the raw 32-bit
-- instruction word plus a 3-bit `fmt` selector and emits the
-- sign-extended 32-bit immediate that goes into the ALU's B port (or
-- the PC adder, for branches and jumps).
--
-- The five RISC-V immediate formats scatter the immediate's bits
-- across the instruction word in different ways — each format was
-- designed so that the SAME wire on the chip always carries the same
-- bit position of the immediate, no matter which format is being
-- decoded. (That keeps the immediate-generator's mux structure
-- regular instead of fan-out-heavy.) The format selector is
-- internal to this project; the decoder maps RISC-V opcodes to
-- these codes, and this entity maps codes to immediate bits.
--
-- Format codes:
--   000  I-type   loads, ADDI/ANDI/.../JALR     12-bit signed
--   001  S-type   stores                        12-bit signed (split)
--   010  B-type   branches                      13-bit signed (split, LSB=0)
--   011  U-type   LUI, AUIPC                    20-bit, shifted left 12
--   100  J-type   JAL                           21-bit signed (split, LSB=0)
--   else         output 0
--
-- Bit-extraction tables (from the RISC-V Unprivileged ISA spec, fig.
-- 2.4 — names like `imm[N:M]` refer to the immediate's bit positions):
--
--   I:  imm[31:11] = sgnext(instr[31])
--       imm[10:0]  = instr[30:20]                (concatenated below as
--                    instr[31:20] for compactness)
--
--   S:  imm[31:11] = sgnext(instr[31])
--       imm[10:5]  = instr[30:25]                (instr[31:25] in code)
--       imm[4:0]   = instr[11:7]
--
--   B:  imm[31:12] = sgnext(instr[31])
--       imm[11]    = instr[7]
--       imm[10:5]  = instr[30:25]
--       imm[4:1]   = instr[11:8]
--       imm[0]     = 0                           (branches are 2-byte aligned)
--
--   U:  imm[31:12] = instr[31:12]
--       imm[11:0]  = 0                           (no sign-extension; the
--                                                 20-bit field is already
--                                                 placed at the upper end)
--
--   J:  imm[31:20] = sgnext(instr[31])
--       imm[19:12] = instr[19:12]
--       imm[11]    = instr[20]
--       imm[10:1]  = instr[30:21]
--       imm[0]     = 0                           (JAL targets are 2-byte
--                                                 aligned)
--
-- All concatenations below are written as 32-bit slices in one
-- expression so the bit-count audits at a glance: 19 + 1 + 1 + 6 + 4
-- + 1 = 32 for B, 11 + 1 + 8 + 1 + 10 + 1 = 32 for J, etc.

library ieee;
use ieee.std_logic_1164.all;

entity immgen_rv32 is
  port (
    instr : in  std_logic_vector(31 downto 0);
    fmt   : in  std_logic_vector(2  downto 0);
    imm   : out std_logic_vector(31 downto 0)
  );
end entity immgen_rv32;

architecture rtl of immgen_rv32 is
  constant FMT_I : std_logic_vector(2 downto 0) := "000";
  constant FMT_S : std_logic_vector(2 downto 0) := "001";
  constant FMT_B : std_logic_vector(2 downto 0) := "010";
  constant FMT_U : std_logic_vector(2 downto 0) := "011";
  constant FMT_J : std_logic_vector(2 downto 0) := "100";

  signal sign : std_logic;
begin
  sign <= instr(31);

  process (instr, fmt, sign)
  begin
    case fmt is
      when FMT_I =>
        imm <= (31 downto 12 => sign) & instr(31 downto 20);

      when FMT_S =>
        imm <= (31 downto 12 => sign) & instr(31 downto 25) & instr(11 downto 7);

      when FMT_B =>
        imm <= (31 downto 13 => sign)
             & instr(31)
             & instr(7)
             & instr(30 downto 25)
             & instr(11 downto 8)
             & '0';

      when FMT_U =>
        imm <= instr(31 downto 12) & x"000";

      when FMT_J =>
        imm <= (31 downto 21 => sign)
             & instr(31)
             & instr(19 downto 12)
             & instr(20)
             & instr(30 downto 21)
             & '0';

      when others =>
        imm <= (others => '0');
    end case;
  end process;

end architecture rtl;
