-- tb_immgen_rv32.vhd
--
-- Drives the immediate generator with hand-encoded RV32I instructions
-- and asserts the resulting immediate against the value the assembler
-- would have produced. Each scenario is a real instruction taken from
-- the RISC-V Unprivileged ISA spec — chosen to exercise both the
-- positive end and the most-negative end of every signed format,
-- plus an illegal-format fallthrough.
--
--   ADDI x1, x0, -1        I-type, all-ones sign extension
--   ADDI x1, x0, +0x7FF    I-type, largest positive 12-bit
--   ADDI x1, x0, -0x800    I-type, most negative 12-bit
--   SW   x5, 16(x3)        S-type, positive split immediate
--   SW   x5, -1(x3)        S-type, all-ones sign extension
--   BEQ  x1, x2, +12       B-type, positive (proves LSB=0 always)
--   BEQ  x1, x2, -4        B-type, negative
--   LUI  x4, 0x12345       U-type, no sign-extension
--   LUI  x4, 0xFFFFF       U-type, MSB set, still no sign-extension
--   JAL  x1, +8            J-type, positive
--   JAL  x1, -8            J-type, negative
--   fmt = 111 (illegal)    output is all zeros
--
-- The procedure `check` mirrors the parameter-mode fix from
-- tb_alu_rv32: `r` is `signal in` so the procedure doesn't add a
-- second driver to the DUT's output.

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity tb_immgen_rv32 is
end entity tb_immgen_rv32;

architecture testbench of tb_immgen_rv32 is
  signal sInstr : std_logic_vector(31 downto 0) := (others => '0');
  signal sFmt   : std_logic_vector(2  downto 0) := (others => '0');
  signal sImm   : std_logic_vector(31 downto 0);

  procedure check (
    signal instr_s : out std_logic_vector(31 downto 0);
    signal fmt_s   : out std_logic_vector(2  downto 0);
    signal imm_s   : in  std_logic_vector(31 downto 0);
    constant instr_v : in std_logic_vector(31 downto 0);
    constant fmt_v   : in std_logic_vector(2  downto 0);
    constant exp     : in std_logic_vector(31 downto 0);
    constant tag     : in string
  ) is
  begin
    instr_s <= instr_v;
    fmt_s   <= fmt_v;
    wait for 1 ns;
    assert imm_s = exp
      report tag & ": instr=" & to_hstring(instr_v)
           & " fmt=" & to_string(fmt_v)
           & " expected " & to_hstring(exp)
           & ", got " & to_hstring(imm_s)
      severity error;
  end procedure;
begin

  dut : entity work.immgen_rv32
    port map (instr => sInstr, fmt => sFmt, imm => sImm);

  driver : process
  begin
    -- I-type
    check(sInstr, sFmt, sImm, x"FFF00093", "000", x"FFFFFFFF", "ADDI x1,x0,-1");
    check(sInstr, sFmt, sImm, x"7FF00093", "000", x"000007FF", "ADDI x1,x0,+0x7FF");
    check(sInstr, sFmt, sImm, x"80000093", "000", x"FFFFF800", "ADDI x1,x0,-0x800");

    -- S-type
    check(sInstr, sFmt, sImm, x"0051A823", "001", x"00000010", "SW x5,16(x3)");
    check(sInstr, sFmt, sImm, x"FE51AFA3", "001", x"FFFFFFFF", "SW x5,-1(x3)");

    -- B-type (LSB always 0)
    check(sInstr, sFmt, sImm, x"00208663", "010", x"0000000C", "BEQ x1,x2,+12");
    check(sInstr, sFmt, sImm, x"FE208EE3", "010", x"FFFFFFFC", "BEQ x1,x2,-4");

    -- U-type (no sign extension; lower 12 bits zero)
    check(sInstr, sFmt, sImm, x"12345237", "011", x"12345000", "LUI x4,0x12345");
    check(sInstr, sFmt, sImm, x"FFFFF237", "011", x"FFFFF000", "LUI x4,0xFFFFF");

    -- J-type (LSB always 0)
    check(sInstr, sFmt, sImm, x"008000EF", "100", x"00000008", "JAL x1,+8");
    check(sInstr, sFmt, sImm, x"FF9FF0EF", "100", x"FFFFFFF8", "JAL x1,-8");

    -- Illegal fmt → all zeros, even with garbage instruction.
    check(sInstr, sFmt, sImm, x"DEADBEEF", "111", x"00000000", "Illegal fmt");

    report "immgen_rv32 simulation done!" severity note;
    wait;
  end process;

end architecture testbench;
