-- decoder_rv32.vhd
--
-- RV32I instruction decoder. Pure combinational. Takes the 32-bit
-- fetched instruction and produces every control signal the CPU
-- top-level needs to route the datapath:
--
--   Register file fields:
--     rs1, rs2, rd          — 5-bit register addresses
--
--   Immediate-generator selector:
--     imm_fmt               — 3-bit code (see immgen_rv32 header)
--
--   ALU control:
--     alu_op                — 4-bit op (matches alu_rv32 ALU_* constants)
--     alu_src_a             — 0 = rs1,  1 = PC          (for AUIPC)
--     alu_src_b             — 0 = rs2,  1 = imm
--
--   Memory:
--     mem_read, mem_write   — gates the data-memory port
--
--   Writeback:
--     reg_write             — gates the regfile's write port
--     wb_src                — 00 = ALU, 01 = MEM, 10 = PC+4, 11 = imm
--                              (the 11 code is LUI's passthrough: the
--                              top-level's writeback mux feeds the
--                              raw immediate to rd, skipping the ALU
--                              entirely. Avoids LUI needing rs1 to
--                              read x0 — the decoder stays a pure
--                              field-extractor for rs1/rs2/rd.)
--
--   Branch / jump:
--     is_branch             — BEQ/BNE/BLT/BGE/BLTU/BGEU
--     is_jal                — JAL
--     is_jalr               — JALR
--
--   Diagnostic:
--     illegal               — the opcode wasn't in our subset
--
-- The branch comparator gets its funct3 directly from the instruction
-- (`instr(14 downto 12)`), so the decoder doesn't republish it.
-- Likewise the branch target adder consumes the immediate produced by
-- immgen — no separate "branch_target" output here.
--
-- Two RV32I-specific ALU-op nuances embedded in this decoder:
--
--   * R-type ADD vs SUB: same funct3 (000), distinguished by
--     instr(30). Same story for SRL vs SRA at funct3 = 101.
--
--   * I-type ADDI never has the funct7 distinction — only SLLI/SRLI/SRAI
--     do (because the shift amount lives in instr[24:20] and instr[30]
--     selects logical vs arithmetic for the right-shift case). The
--     decoder honours this by ignoring instr(30) for non-shift I-type
--     instructions.
--
-- LUI uses the `wb_src = 11` (imm-passthrough) writeback source: the
-- top-level writeback mux selects the immediate as the value written
-- to rd, bypassing the ALU entirely. AUIPC instead drives the ALU's
-- A operand from the PC (`alu_src_a = 1`) and adds the immediate.

library ieee;
use ieee.std_logic_1164.all;

entity decoder_rv32 is
  port (
    instr     : in  std_logic_vector(31 downto 0);

    rs1       : out std_logic_vector(4 downto 0);
    rs2       : out std_logic_vector(4 downto 0);
    rd        : out std_logic_vector(4 downto 0);

    imm_fmt   : out std_logic_vector(2 downto 0);
    alu_op    : out std_logic_vector(3 downto 0);
    alu_src_a : out std_logic;
    alu_src_b : out std_logic;

    mem_read  : out std_logic;
    mem_write : out std_logic;
    reg_write : out std_logic;
    wb_src    : out std_logic_vector(1 downto 0);

    is_branch : out std_logic;
    is_jal    : out std_logic;
    is_jalr   : out std_logic;

    illegal   : out std_logic
  );
end entity decoder_rv32;

architecture rtl of decoder_rv32 is
  -- Major opcodes (instr[6:0]).
  constant OP_LUI    : std_logic_vector(6 downto 0) := "0110111";
  constant OP_AUIPC  : std_logic_vector(6 downto 0) := "0010111";
  constant OP_JAL    : std_logic_vector(6 downto 0) := "1101111";
  constant OP_JALR   : std_logic_vector(6 downto 0) := "1100111";
  constant OP_BRANCH : std_logic_vector(6 downto 0) := "1100011";
  constant OP_LOAD   : std_logic_vector(6 downto 0) := "0000011";
  constant OP_STORE  : std_logic_vector(6 downto 0) := "0100011";
  constant OP_ALU_I  : std_logic_vector(6 downto 0) := "0010011";
  constant OP_ALU_R  : std_logic_vector(6 downto 0) := "0110011";

  -- Immediate formats (must match immgen_rv32).
  constant FMT_I : std_logic_vector(2 downto 0) := "000";
  constant FMT_S : std_logic_vector(2 downto 0) := "001";
  constant FMT_B : std_logic_vector(2 downto 0) := "010";
  constant FMT_U : std_logic_vector(2 downto 0) := "011";
  constant FMT_J : std_logic_vector(2 downto 0) := "100";

  -- ALU op constants (must match alu_rv32).
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

  -- Convenience aliases.
  alias opcode : std_logic_vector(6 downto 0) is instr( 6 downto  0);
  alias funct3 : std_logic_vector(2 downto 0) is instr(14 downto 12);
  alias funct7_bit5 : std_logic is instr(30);     -- the only bit that matters
                                                  -- across R/I shift-vs-non
begin

  rs1 <= instr(19 downto 15);
  rs2 <= instr(24 downto 20);
  rd  <= instr(11 downto  7);

  -- Pure-combinational decode. Default everything to a no-op shape
  -- and let each opcode override only what differs.
  process (instr, opcode, funct3, funct7_bit5)
  begin
    -- Defaults: a "no-op" instruction that doesn't write any state.
    imm_fmt   <= FMT_I;
    alu_op    <= ALU_ADD;
    alu_src_a <= '0';            -- rs1
    alu_src_b <= '0';            -- rs2
    mem_read  <= '0';
    mem_write <= '0';
    reg_write <= '0';
    wb_src    <= "00";           -- ALU
    is_branch <= '0';
    is_jal    <= '0';
    is_jalr   <= '0';
    illegal   <= '0';

    case opcode is

      when OP_LUI =>
        -- result = imm. The top-level's writeback mux uses
        -- wb_src = "11" to route the immediate straight to rd,
        -- bypassing the ALU. rs1/rs2 fields are still emitted as
        -- raw instr bits (they're part of the U-immediate's
        -- encoding), but the regfile read isn't consumed by the
        -- ALU because wb_src steers around it.
        imm_fmt   <= FMT_U;
        reg_write <= '1';
        wb_src    <= "11";        -- imm passthrough

      when OP_AUIPC =>
        imm_fmt   <= FMT_U;
        alu_src_a <= '1';         -- PC
        alu_src_b <= '1';         -- imm
        alu_op    <= ALU_ADD;
        reg_write <= '1';
        wb_src    <= "00";        -- ALU result (= PC + imm)

      when OP_JAL =>
        imm_fmt   <= FMT_J;
        reg_write <= '1';
        wb_src    <= "10";        -- PC + 4
        is_jal    <= '1';

      when OP_JALR =>
        -- Target = (rs1 + I-imm) & ~1. The top-level masks bit 0;
        -- the ALU just computes rs1 + imm.
        imm_fmt   <= FMT_I;
        alu_src_a <= '0';         -- rs1
        alu_src_b <= '1';         -- imm
        alu_op    <= ALU_ADD;
        reg_write <= '1';
        wb_src    <= "10";        -- PC + 4
        is_jalr   <= '1';

      when OP_BRANCH =>
        -- Branch target compute is a separate adder (PC + B-imm) in
        -- the top-level. The branch comparator reads funct3 directly
        -- from the instruction. No regfile write, no memory traffic.
        imm_fmt   <= FMT_B;
        is_branch <= '1';

      when OP_LOAD =>
        -- For our subset only LW (funct3 = 010) is implemented; other
        -- load funct3 codes are flagged illegal so a future LB/LH
        -- implementation can be slotted in by relaxing this check.
        imm_fmt   <= FMT_I;
        alu_src_b <= '1';         -- imm (address compute = rs1 + imm)
        alu_op    <= ALU_ADD;
        mem_read  <= '1';
        reg_write <= '1';
        wb_src    <= "01";        -- MEM
        if funct3 /= "010" then
          illegal <= '1';
        end if;

      when OP_STORE =>
        -- Only SW (funct3 = 010) implemented.
        imm_fmt   <= FMT_S;
        alu_src_b <= '1';         -- imm (address compute = rs1 + imm)
        alu_op    <= ALU_ADD;
        mem_write <= '1';
        if funct3 /= "010" then
          illegal <= '1';
        end if;

      when OP_ALU_I =>
        -- ADDI/SLTI/SLTIU/XORI/ORI/ANDI/SLLI/SRLI/SRAI.
        imm_fmt   <= FMT_I;
        alu_src_b <= '1';         -- imm
        reg_write <= '1';
        case funct3 is
          when "000" => alu_op <= ALU_ADD;             -- ADDI
          when "001" => alu_op <= ALU_SLL;             -- SLLI
          when "010" => alu_op <= ALU_SLT;             -- SLTI
          when "011" => alu_op <= ALU_SLTU;            -- SLTIU
          when "100" => alu_op <= ALU_XOR;             -- XORI
          when "101" =>                                -- SRLI / SRAI
            if funct7_bit5 = '1' then
              alu_op <= ALU_SRA;
            else
              alu_op <= ALU_SRL;
            end if;
          when "110" => alu_op <= ALU_OR;              -- ORI
          when "111" => alu_op <= ALU_AND;             -- ANDI
          when others => illegal <= '1';
        end case;

      when OP_ALU_R =>
        -- ADD/SUB/SLL/SLT/SLTU/XOR/SRL/SRA/OR/AND. Both operands from
        -- the regfile; no immediate involved.
        alu_src_b <= '0';         -- rs2
        reg_write <= '1';
        case funct3 is
          when "000" =>                                -- ADD / SUB
            if funct7_bit5 = '1' then
              alu_op <= ALU_SUB;
            else
              alu_op <= ALU_ADD;
            end if;
          when "001" => alu_op <= ALU_SLL;             -- SLL
          when "010" => alu_op <= ALU_SLT;             -- SLT
          when "011" => alu_op <= ALU_SLTU;            -- SLTU
          when "100" => alu_op <= ALU_XOR;             -- XOR
          when "101" =>                                -- SRL / SRA
            if funct7_bit5 = '1' then
              alu_op <= ALU_SRA;
            else
              alu_op <= ALU_SRL;
            end if;
          when "110" => alu_op <= ALU_OR;              -- OR
          when "111" => alu_op <= ALU_AND;             -- AND
          when others => illegal <= '1';
        end case;

      when others =>
        illegal <= '1';
    end case;
  end process;

end architecture rtl;
