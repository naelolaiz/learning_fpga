-- tb_decoder_rv32.vhd
--
-- Walks every supported RV32I instruction class through the decoder
-- and asserts the full control-vector matches a hand-computed golden
-- value. The vectors are real instruction encodings (the same ones
-- the assembler would emit), so a regression points at exactly which
-- opcode + funct combination the decoder mishandles.
--
-- Outputs are bundled in a record so each assertion compares one
-- whole vector at once instead of asserting field-by-field. The
-- assertion message dumps both records on mismatch, so the failing
-- field jumps out at a glance.

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity tb_decoder_rv32 is
end entity tb_decoder_rv32;

architecture testbench of tb_decoder_rv32 is
  type decoded_t is record
    rs1, rs2, rd : std_logic_vector(4 downto 0);
    imm_fmt      : std_logic_vector(2 downto 0);
    alu_op       : std_logic_vector(3 downto 0);
    alu_src_a    : std_logic;
    alu_src_b    : std_logic;
    mem_read     : std_logic;
    mem_write    : std_logic;
    reg_write    : std_logic;
    wb_src       : std_logic_vector(1 downto 0);
    is_branch    : std_logic;
    is_jal       : std_logic;
    is_jalr      : std_logic;
    illegal      : std_logic;
  end record;

  -- Format / ALU-op constants matching decoder_rv32.vhd.
  constant FMT_I    : std_logic_vector(2 downto 0) := "000";
  constant FMT_S    : std_logic_vector(2 downto 0) := "001";
  constant FMT_B    : std_logic_vector(2 downto 0) := "010";
  constant FMT_U    : std_logic_vector(2 downto 0) := "011";
  constant FMT_J    : std_logic_vector(2 downto 0) := "100";
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

  signal sInstr  : std_logic_vector(31 downto 0) := (others => '0');
  signal actual  : decoded_t;

  -- Build an "expected" record from the easily-varying fields. Defaults
  -- match the decoder's own defaults (no-op).
  function exp_default return decoded_t is
  begin
    return ("00000", "00000", "00000",
            FMT_I, ALU_ADD,
            '0', '0',     -- alu_src_a, alu_src_b
            '0', '0',     -- mem_read, mem_write
            '0',          -- reg_write
            "00",         -- wb_src
            '0', '0', '0',-- is_branch, is_jal, is_jalr
            '0');         -- illegal
  end function;

  function to_bits(d : decoded_t) return string is
  begin
    return "rs1="    & to_string(d.rs1)
         & " rs2="   & to_string(d.rs2)
         & " rd="    & to_string(d.rd)
         & " fmt="   & to_string(d.imm_fmt)
         & " alu="   & to_string(d.alu_op)
         & " saA="   & std_logic'image(d.alu_src_a)
         & " saB="   & std_logic'image(d.alu_src_b)
         & " mr="    & std_logic'image(d.mem_read)
         & " mw="    & std_logic'image(d.mem_write)
         & " rw="    & std_logic'image(d.reg_write)
         & " wb="    & to_string(d.wb_src)
         & " br="    & std_logic'image(d.is_branch)
         & " jal="   & std_logic'image(d.is_jal)
         & " jalr="  & std_logic'image(d.is_jalr)
         & " ill="   & std_logic'image(d.illegal);
  end function;

  procedure check_decode (
    signal   instr_s : out std_logic_vector(31 downto 0);
    constant instr_v : in  std_logic_vector(31 downto 0);
    constant exp     : in  decoded_t;
    constant tag     : in  string
  ) is
  begin
    instr_s <= instr_v;
    wait for 1 ns;
    assert actual = exp
      report tag & ": instr=" & to_hstring(instr_v) & LF
           & "  expected: " & to_bits(exp) & LF
           & "  actual:   " & to_bits(actual)
      severity error;
  end procedure;
begin

  dut : entity work.decoder_rv32
    port map (
      instr     => sInstr,
      rs1       => actual.rs1,
      rs2       => actual.rs2,
      rd        => actual.rd,
      imm_fmt   => actual.imm_fmt,
      alu_op    => actual.alu_op,
      alu_src_a => actual.alu_src_a,
      alu_src_b => actual.alu_src_b,
      mem_read  => actual.mem_read,
      mem_write => actual.mem_write,
      reg_write => actual.reg_write,
      wb_src    => actual.wb_src,
      is_branch => actual.is_branch,
      is_jal    => actual.is_jal,
      is_jalr   => actual.is_jalr,
      illegal   => actual.illegal
    );

  driver : process
    variable e : decoded_t;
  begin
    -- ============================================================
    -- R-type ALU ops (opcode 0110011)
    -- ============================================================

    -- ADD x3, x1, x2  (funct3=000, funct7=0)
    e := exp_default;
    e.rs1 := "00001"; e.rs2 := "00010"; e.rd := "00011";
    e.alu_op := ALU_ADD; e.reg_write := '1';
    check_decode(sInstr, x"002081B3", e, "ADD x3,x1,x2");

    -- SUB x3, x1, x2  (funct3=000, funct7=0100000)
    e := exp_default;
    e.rs1 := "00001"; e.rs2 := "00010"; e.rd := "00011";
    e.alu_op := ALU_SUB; e.reg_write := '1';
    check_decode(sInstr, x"402081B3", e, "SUB x3,x1,x2");

    -- AND x3, x1, x2  (funct3=111)
    e := exp_default;
    e.rs1 := "00001"; e.rs2 := "00010"; e.rd := "00011";
    e.alu_op := ALU_AND; e.reg_write := '1';
    check_decode(sInstr, x"0020F1B3", e, "AND x3,x1,x2");

    -- SRA x3, x1, x2  (funct3=101, funct7=0100000)
    e := exp_default;
    e.rs1 := "00001"; e.rs2 := "00010"; e.rd := "00011";
    e.alu_op := ALU_SRA; e.reg_write := '1';
    check_decode(sInstr, x"4020D1B3", e, "SRA x3,x1,x2");

    -- SRL x3, x1, x2  (funct3=101, funct7=0)
    e := exp_default;
    e.rs1 := "00001"; e.rs2 := "00010"; e.rd := "00011";
    e.alu_op := ALU_SRL; e.reg_write := '1';
    check_decode(sInstr, x"0020D1B3", e, "SRL x3,x1,x2");

    -- SLT x3, x1, x2  (funct3=010)
    e := exp_default;
    e.rs1 := "00001"; e.rs2 := "00010"; e.rd := "00011";
    e.alu_op := ALU_SLT; e.reg_write := '1';
    check_decode(sInstr, x"0020A1B3", e, "SLT x3,x1,x2");

    -- ============================================================
    -- I-type ALU ops (opcode 0010011)
    -- ============================================================

    -- ADDI x3, x1, 100  (funct3=000)
    -- Note: instr[24:20] = 4 here — those bits are part of the
    -- I-immediate, not a real rs2, but the decoder just extracts the
    -- raw fields. The CPU top-level ignores rs2 when alu_src_b=1.
    e := exp_default;
    e.rs1 := "00001"; e.rs2 := "00100"; e.rd := "00011";
    e.alu_op := ALU_ADD; e.alu_src_b := '1'; e.reg_write := '1';
    check_decode(sInstr, x"06408193", e, "ADDI x3,x1,100");

    -- SRAI x3, x1, 5  (funct3=101, funct7=0100000)
    e := exp_default;
    e.rs1 := "00001"; e.rd := "00011"; e.rs2 := "00101";  -- shamt lives in instr[24:20]
    e.alu_op := ALU_SRA; e.alu_src_b := '1'; e.reg_write := '1';
    check_decode(sInstr, x"4050D193", e, "SRAI x3,x1,5");

    -- SRLI x3, x1, 5  (funct3=101, funct7=0)
    e := exp_default;
    e.rs1 := "00001"; e.rd := "00011"; e.rs2 := "00101";
    e.alu_op := ALU_SRL; e.alu_src_b := '1'; e.reg_write := '1';
    check_decode(sInstr, x"0050D193", e, "SRLI x3,x1,5");

    -- ============================================================
    -- LOAD (opcode 0000011) — only LW (funct3=010) supported
    -- ============================================================

    -- LW x3, 0(x1)
    e := exp_default;
    e.rs1 := "00001"; e.rd := "00011";
    e.alu_op := ALU_ADD; e.alu_src_b := '1';
    e.mem_read := '1'; e.reg_write := '1'; e.wb_src := "01";
    check_decode(sInstr, x"0000A183", e, "LW x3,0(x1)");

    -- LB x3, 0(x1)  (funct3=000) — illegal in our subset
    e := exp_default;
    e.rs1 := "00001"; e.rd := "00011";
    e.alu_op := ALU_ADD; e.alu_src_b := '1';
    e.mem_read := '1'; e.reg_write := '1'; e.wb_src := "01";
    e.illegal := '1';
    check_decode(sInstr, x"00008183", e, "LB x3,0(x1) (illegal)");

    -- ============================================================
    -- STORE (opcode 0100011) — only SW supported
    -- ============================================================

    -- SW x2, 4(x1)
    -- instr[11:7] = 4 here (imm[4:0] of the S-type encoding), not a
    -- real rd — decoder still extracts it raw.
    e := exp_default;
    e.rs1 := "00001"; e.rs2 := "00010"; e.rd := "00100";
    e.imm_fmt := FMT_S;
    e.alu_op := ALU_ADD; e.alu_src_b := '1'; e.mem_write := '1';
    check_decode(sInstr, x"0020A223", e, "SW x2,4(x1)");

    -- SH x2, 4(x1)  (funct3=001) — illegal
    e := exp_default;
    e.rs1 := "00001"; e.rs2 := "00010"; e.rd := "00100";
    e.imm_fmt := FMT_S;
    e.alu_op := ALU_ADD; e.alu_src_b := '1'; e.mem_write := '1';
    e.illegal := '1';
    check_decode(sInstr, x"00209223", e, "SH x2,4(x1) (illegal)");

    -- ============================================================
    -- BRANCH (opcode 1100011) — every funct3 is valid
    -- ============================================================

    -- BEQ x1, x2, +12
    -- instr[11:7] = 12 here (imm[4:1] | imm[11] of the B-type
    -- encoding), not rd.
    e := exp_default;
    e.rs1 := "00001"; e.rs2 := "00010"; e.rd := "01100";
    e.imm_fmt := FMT_B; e.is_branch := '1';
    check_decode(sInstr, x"00208663", e, "BEQ x1,x2,+12");

    -- BLT x1, x2, +12  (funct3=100; decoder treats it the same way,
    -- the comparator differentiates)
    e := exp_default;
    e.rs1 := "00001"; e.rs2 := "00010"; e.rd := "01100";
    e.imm_fmt := FMT_B; e.is_branch := '1';
    check_decode(sInstr, x"0020C663", e, "BLT x1,x2,+12");

    -- ============================================================
    -- JAL / JALR
    -- ============================================================

    -- JAL x1, +8
    -- instr[24:20] = 8 here (part of the J-immediate's bit-scatter).
    e := exp_default;
    e.rs2 := "01000"; e.rd := "00001";
    e.imm_fmt := FMT_J;
    e.reg_write := '1'; e.wb_src := "10"; e.is_jal := '1';
    check_decode(sInstr, x"008000EF", e, "JAL x1,+8");

    -- JALR x1, x2, 4  (rs1=2, rd=1, imm=4)
    -- instr[24:20] = 4 here (imm[4:0] of the I-encoding).
    e := exp_default;
    e.rs1 := "00010"; e.rs2 := "00100"; e.rd := "00001";
    e.imm_fmt := FMT_I;
    e.alu_op := ALU_ADD; e.alu_src_b := '1';
    e.reg_write := '1'; e.wb_src := "10"; e.is_jalr := '1';
    check_decode(sInstr, x"004100E7", e, "JALR x1,x2,4");

    -- ============================================================
    -- LUI / AUIPC
    -- ============================================================

    -- LUI x4, 0x12345
    -- instr[19:15] = 8, instr[24:20] = 3 here (these bits are the
    -- middle of the U-immediate's encoding). The decoder extracts
    -- them raw; the writeback mux uses wb_src=11 to skip the ALU
    -- and feed the immediate straight to rd.
    e := exp_default;
    e.rs1 := "01000"; e.rs2 := "00011"; e.rd := "00100";
    e.imm_fmt := FMT_U;
    e.reg_write := '1'; e.wb_src := "11";    -- imm passthrough
    check_decode(sInstr, x"12345237", e, "LUI x4,0x12345");

    -- AUIPC x4, 0x12345
    -- Same raw rs1/rs2 extraction as LUI; difference is alu_src_a=1
    -- (PC) + alu_op=ADD with wb_src=00 (ALU result of PC + imm).
    e := exp_default;
    e.rs1 := "01000"; e.rs2 := "00011"; e.rd := "00100";
    e.imm_fmt := FMT_U;
    e.alu_op := ALU_ADD; e.alu_src_a := '1'; e.alu_src_b := '1';
    e.reg_write := '1'; e.wb_src := "00";
    check_decode(sInstr, x"12345217", e, "AUIPC x4,0x12345");

    -- ============================================================
    -- Truly unknown opcode — illegal
    -- ============================================================

    -- opcode 0001011 = custom-0; we don't support it.
    e := exp_default;
    e.illegal := '1';
    check_decode(sInstr, x"0000000B", e, "Unknown opcode");

    report "decoder_rv32 simulation done!" severity note;
    wait;
  end process;

end architecture testbench;
