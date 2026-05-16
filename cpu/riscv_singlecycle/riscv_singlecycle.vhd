-- riscv_singlecycle.vhd
--
-- Single-cycle RV32I CPU — the textbook flat-datapath organisation
-- from Patterson & Hennessy, composed structurally from the RV32
-- building blocks (alu_rv32, regfile_rv32, immgen_rv32, decoder_rv32,
-- ram_sync). One instruction completes every clock; no FSM, no
-- pipeline registers.
--
-- Datapath outline:
--
--   IF :  PC drives IMEM             ─── imem_rdata = instr at PC
--   ID :  decoder + immgen + regfile read on instr's rs1/rs2 fields
--   EX :  ALU(alu_a, alu_b)
--           alu_a = alu_src_a ? PC : rs1
--           alu_b = alu_src_b ? imm : rs2
--         branch_taken = branch_cmp(funct3, rs1, rs2)
--   MEM:  if mem_read  : dmem[alu_result] -> dmem_rdata
--         if mem_write : dmem[alu_result] <= rs2
--   WB :  rd <= one of {alu_result, dmem_rdata, PC+4, imm}, gated
--                 by reg_write
--
--   next_PC = JALR        ? (alu_result with bit 0 cleared)
--           : (JAL or taken-branch) ? (PC + imm)
--           : PC + 4
--
-- Memories
-- --------
-- IMEM is internal, combinational read, initialised at elaboration
-- from a hex file via the IMEM_INIT generic. This is what makes the
-- design *truly* single-cycle: a synchronous-read BRAM for IMEM would
-- delay the fetch by one cycle and turn the design into something
-- closer to a 2-stage pipeline. With a small tutorial program (≤ a
-- few hundred instructions) the combinational ROM costs negligible
-- area.
--
-- DMEM is also internal — sync write, async read — so loads land in
-- the same cycle as the address compute. For real BRAM-friendly
-- behaviour the SoC top variant (cpu/riscv_soc/) replaces the internal DMEM with
-- an external memory bus.
--
-- Both memories are sized via ADDR_W generics; depth = 2**ADDR_W
-- words (each word is 32 bits). PC[1:0] is always zero
-- (instructions are word-aligned).
--
-- Debug bus
-- ---------
-- The dbg_* outputs make it easy for a testbench to watch PC, the
-- current instruction, and every regfile commit without having to
-- reach into the entity via hierarchical references. The CPU works
-- the same way whether they're connected or left dangling.

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.textio.all;

entity riscv_singlecycle is
  generic (
    IMEM_ADDR_W : integer := 10;          -- 2**10 = 1024 instr ≈ 4 KB
    DMEM_ADDR_W : integer := 10;          -- 2**10 = 1024 words ≈ 4 KB
    IMEM_INIT   : string  := "";          -- hex file for IMEM
    -- Sim-only: when true, `report` a per-cycle trace of PC + the
    -- fetched instruction. A TB enables it via
    -- `generic map (DEBUG_TRACE => true, ...)`; ignored by synthesis.
    DEBUG_TRACE : boolean := false
  );
  port (
    clk : in std_logic;
    rst : in std_logic;                   -- synchronous, active high

    -- Debug bus (purely observational; safe to leave dangling).
    dbg_pc        : out std_logic_vector(31 downto 0);
    dbg_instr     : out std_logic_vector(31 downto 0);
    dbg_reg_we    : out std_logic;
    dbg_reg_waddr : out std_logic_vector(4  downto 0);
    dbg_reg_wdata : out std_logic_vector(31 downto 0)
  );
end entity riscv_singlecycle;

architecture rtl of riscv_singlecycle is

  -- ------------------------------------------------------------------
  -- IMEM — combinational ROM, init from hex file
  -- ------------------------------------------------------------------
  constant IMEM_DEPTH : integer := 2**IMEM_ADDR_W;
  type imem_t is array (0 to IMEM_DEPTH-1) of std_logic_vector(31 downto 0);

  -- A NOP encoding (`addi x0, x0, 0` = 0x00000013) — used as the
  -- default fill so any unprogrammed slot fetches as a no-op rather
  -- than 'U'/'X' which would propagate into the decoder and
  -- crash the simulation.
  constant NOP_INSTR : std_logic_vector(31 downto 0) := x"00000013";

  impure function init_imem(filename : string) return imem_t is
    file     f      : text;
    variable l      : line;
    variable v      : std_logic_vector(31 downto 0);
    variable result : imem_t := (others => NOP_INSTR);
  begin
    if filename = "" then
      return result;
    end if;
    file_open(f, filename, read_mode);
    for i in 0 to IMEM_DEPTH-1 loop
      exit when endfile(f);
      readline(f, l);
      hread(l, v);
      result(i) := v;
    end loop;
    file_close(f);
    return result;
  end function;

  -- `constant` (not signal) because IMEM is genuinely read-only at
  -- runtime — its contents come from the .hex file at elaboration
  -- and never change. Using a signal would trip GHDL's
  -- `-Wnowrite` ("signal never assigned") since there's no process
  -- driver. The ROM_LUT BRAM-inference idiom uses `signal`
  -- deliberately to coax Quartus to a block RAM, but the
  -- single-cycle CPU's IMEM (a few hundred 32-bit words) fits in
  -- LEs comfortably on the Cyclone IV, so the constant form is
  -- the cleaner expression of intent.
  constant imem : imem_t := init_imem(IMEM_INIT);

  -- ------------------------------------------------------------------
  -- DMEM — sync write, async read
  -- ------------------------------------------------------------------
  constant DMEM_DEPTH : integer := 2**DMEM_ADDR_W;
  type dmem_t is array (0 to DMEM_DEPTH-1) of std_logic_vector(31 downto 0);
  signal dmem : dmem_t := (others => (others => '0'));

  -- ------------------------------------------------------------------
  -- Datapath signals
  -- ------------------------------------------------------------------
  signal pc           : std_logic_vector(31 downto 0) := (others => '0');
  signal pc_plus_4    : std_logic_vector(31 downto 0);
  signal pc_plus_imm  : std_logic_vector(31 downto 0);
  signal next_pc      : std_logic_vector(31 downto 0);
  signal instr        : std_logic_vector(31 downto 0);

  -- Decoder outputs
  signal d_rs1, d_rs2, d_rd : std_logic_vector(4 downto 0);
  signal d_imm_fmt          : std_logic_vector(2 downto 0);
  signal d_alu_op           : std_logic_vector(3 downto 0);
  signal d_alu_src_a        : std_logic;
  signal d_alu_src_b        : std_logic;
  signal d_mem_read         : std_logic;
  signal d_mem_write        : std_logic;
  signal d_reg_write        : std_logic;
  signal d_wb_src           : std_logic_vector(1 downto 0);
  signal d_is_branch        : std_logic;
  signal d_is_jal           : std_logic;
  signal d_is_jalr          : std_logic;
  signal d_illegal          : std_logic;

  -- Funct3 of the current instruction (the branch comparator reads
  -- it directly — the decoder doesn't republish it).
  alias instr_funct3 : std_logic_vector(2 downto 0) is instr(14 downto 12);

  -- Regfile / immediate
  signal rs1_data, rs2_data : std_logic_vector(31 downto 0);
  signal imm                : std_logic_vector(31 downto 0);

  -- ALU
  signal alu_a, alu_b       : std_logic_vector(31 downto 0);
  signal alu_result         : std_logic_vector(31 downto 0);
  signal alu_zero           : std_logic;

  -- Memory + writeback
  signal dmem_rdata         : std_logic_vector(31 downto 0);
  signal wb_data            : std_logic_vector(31 downto 0);

  -- Branch
  signal branch_taken       : std_logic;
  signal take_branch        : std_logic;
begin

  -- ------------------------------------------------------------------
  -- IF — program counter and instruction memory
  -- ------------------------------------------------------------------
  process (clk) is
  begin
    if rising_edge(clk) then
      if rst = '1' then
        pc <= (others => '0');
      else
        pc <= next_pc;
      end if;
    end if;
  end process;

  pc_plus_4 <= std_logic_vector(unsigned(pc) + 4);

  -- Combinational fetch — see the entity header for why IMEM is async.
  instr <= imem(to_integer(unsigned(pc(IMEM_ADDR_W+1 downto 2))));

  -- ------------------------------------------------------------------
  -- ID — decoder, immediate generator, register-file read
  -- ------------------------------------------------------------------
  decoder : entity work.decoder_rv32
    port map (
      instr     => instr,
      rs1       => d_rs1, rs2 => d_rs2, rd => d_rd,
      imm_fmt   => d_imm_fmt,
      alu_op    => d_alu_op,
      alu_src_a => d_alu_src_a,
      alu_src_b => d_alu_src_b,
      mem_read  => d_mem_read,
      mem_write => d_mem_write,
      reg_write => d_reg_write,
      wb_src    => d_wb_src,
      is_branch => d_is_branch,
      is_jal    => d_is_jal,
      is_jalr   => d_is_jalr,
      illegal   => d_illegal
    );

  immgen : entity work.immgen_rv32
    port map (
      instr => instr,
      fmt   => d_imm_fmt,
      imm   => imm
    );

  regfile : entity work.regfile_rv32
    port map (
      clk    => clk,
      we     => d_reg_write,
      waddr  => d_rd,
      wdata  => wb_data,
      raddr1 => d_rs1, rdata1 => rs1_data,
      raddr2 => d_rs2, rdata2 => rs2_data
    );

  -- ------------------------------------------------------------------
  -- EX — ALU and branch comparator
  -- ------------------------------------------------------------------
  alu_a <= pc       when d_alu_src_a = '1' else rs1_data;
  alu_b <= imm      when d_alu_src_b = '1' else rs2_data;

  alu : entity work.alu_rv32
    port map (
      a => alu_a, b => alu_b, op => d_alu_op,
      result => alu_result, zero => alu_zero
    );

  -- Branch comparator — separate from the ALU because for branches
  -- the ALU is busy computing the branch target (PC + imm), and even
  -- if it weren't, the six branch flavours need both signed and
  -- unsigned compares which the ALU only exposes via SLT/SLTU.
  -- Keeping a dedicated 6-way comparator here keeps the datapath
  -- diagram simple.
  process (instr_funct3, rs1_data, rs2_data) is
  begin
    case instr_funct3 is
      when "000"  => branch_taken <= '1' when rs1_data = rs2_data else '0';
      when "001"  => branch_taken <= '1' when rs1_data /= rs2_data else '0';
      when "100"  =>
        branch_taken <= '1' when signed(rs1_data) <  signed(rs2_data) else '0';
      when "101"  =>
        branch_taken <= '1' when signed(rs1_data) >= signed(rs2_data) else '0';
      when "110"  =>
        branch_taken <= '1' when unsigned(rs1_data) <  unsigned(rs2_data) else '0';
      when "111"  =>
        branch_taken <= '1' when unsigned(rs1_data) >= unsigned(rs2_data) else '0';
      when others => branch_taken <= '0';
    end case;
  end process;

  take_branch <= d_is_branch and branch_taken;

  -- Branch / JAL target adder (separate from the ALU so the ALU is
  -- free to compute things like the JALR target = rs1 + imm).
  pc_plus_imm <= std_logic_vector(unsigned(pc) + unsigned(imm));

  -- Next-PC selector. JALR uses ALU's rs1+imm result with bit 0
  -- masked off (RISC-V spec).
  next_pc <= (alu_result(31 downto 1) & '0') when d_is_jalr = '1'
        else pc_plus_imm                      when (d_is_jal = '1' or take_branch = '1')
        else pc_plus_4;

  -- ------------------------------------------------------------------
  -- MEM — data memory (sync write, async read, internal)
  -- ------------------------------------------------------------------
  process (clk) is
  begin
    if rising_edge(clk) then
      if d_mem_write = '1' then
        dmem(to_integer(unsigned(alu_result(DMEM_ADDR_W+1 downto 2)))) <= rs2_data;
      end if;
    end if;
  end process;

  dmem_rdata <= dmem(to_integer(unsigned(alu_result(DMEM_ADDR_W+1 downto 2))));

  -- ------------------------------------------------------------------
  -- WB — writeback mux (gated upstream by d_reg_write at the regfile)
  -- ------------------------------------------------------------------
  with d_wb_src select
    wb_data <= alu_result when "00",
               dmem_rdata when "01",
               pc_plus_4  when "10",
               imm        when "11",
               alu_result when others;

  -- ------------------------------------------------------------------
  -- Debug bus
  -- ------------------------------------------------------------------
  dbg_pc        <= pc;
  dbg_instr     <= instr;
  dbg_reg_we    <= d_reg_write;
  dbg_reg_waddr <= d_rd;
  dbg_reg_wdata <= wb_data;

  -- ------------------------------------------------------------------
  -- Optional per-cycle trace (sim-only, gated by DEBUG_TRACE generic).
  -- Same fields as the Verilog twin: PC + instruction, control flags,
  -- WB commit, MEM access.
  -- ------------------------------------------------------------------
  -- See riscv_pipelined.vhd's trace_p for the rationale: textio (not
  -- synthesisable) inside `if DEBUG_TRACE generate` (elaborated out
  -- when DEBUG_TRACE=false), so the synthesis flow never sees it.
  trace_gen : if DEBUG_TRACE generate
  trace_p : process (clk) is
    variable cyc : integer := 0;
    variable l   : line;
  begin
    if rising_edge(clk) and rst = '0' then
      write(l, string'("[riscv_singlecycle] c"));
      write(l, cyc);
      write(l, string'("  pc="));    hwrite(l, pc);
      write(l, string'("  instr=")); hwrite(l, instr);
      writeline(output, l);

      write(l, string'("    ctrl : take_branch=")); write(l, take_branch);
      write(l, string'(" is_jal="));                write(l, d_is_jal);
      write(l, string'(" is_jalr="));               write(l, d_is_jalr);
      writeline(output, l);

      write(l, string'("    WB   : we=")); write(l, d_reg_write);
      write(l, string'(" rd=x"));          write(l, to_integer(unsigned(d_rd)));
      write(l, string'(" wdata="));        hwrite(l, wb_data);
      writeline(output, l);

      write(l, string'("    MEM  : rd=")); write(l, d_mem_read);
      write(l, string'(" wr="));           write(l, d_mem_write);
      write(l, string'(" addr="));         hwrite(l, alu_result);
      write(l, string'(" rdata="));        hwrite(l, dmem_rdata);
      writeline(output, l);

      cyc := cyc + 1;
    end if;
  end process;
  end generate trace_gen;

end architecture rtl;
