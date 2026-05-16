-- riscv_pipelined.vhd
--
-- Classic 5-stage RV32I pipeline (IF/ID/EX/MEM/WB), composed from the
-- same Phase A building blocks the single-cycle CPU uses
-- (decoder_rv32, immgen_rv32, alu_rv32, regfile_rv32, ram_sync) plus
-- the two pipeline-specific sub-entities forwarding_unit and
-- hazard_detector.
--
-- Pipeline organisation
-- ---------------------
--   IF  : PC drives IMEM → instr
--   ID  : decoder + immgen + regfile read
--   EX  : ALU + branch comparator + forwarding muxes
--   MEM : DMEM access (sync write, async read)
--   WB  : regfile write
--
--   Pipeline registers (one per stage boundary): IF/ID, ID/EX, EX/MEM,
--   MEM/WB. Each is a VHDL record updated by a single sync process per
--   stage; the "next-state" combinational logic is computed alongside.
--
-- Hazard handling (the only difference from a textbook pipeline)
-- --------------------------------------------------------------
-- The forwarding_unit and hazard_detector sub-entities (see their
-- READMEs for the per-block reasoning) drive three pipeline-level
-- responses:
--
--   * stall  — load-use RAW. Freeze PC + IF/ID; insert NOP into
--              ID/EX. One-cycle bubble; forwarding resolves the RAW
--              on the next cycle.
--   * flush  — taken branch. Force IF/ID and ID/EX to NOP on next
--              clock. Two-instruction penalty per taken branch (the
--              cost of resolving branches in EX rather than ID).
--   * fwd_a/fwd_b — combinational ALU-operand muxes that pull values
--              from EX/MEM or MEM/WB when a producer is mid-flight.
--
-- Same external port shape as cpu/riscv_singlecycle so program-level
-- tests can target either CPU with the same hex file and the same
-- testbench scaffolding.
--
-- Memories
-- --------
-- Same IMEM/DMEM model as the single-cycle CPU: internal, async-read
-- IMEM initialised from a hex file, internal sync-write/async-read
-- DMEM. The pipelined version still works with async-read memories
-- (IF and MEM are different stages, so reads and writes don't fight),
-- but a real BRAM build would convert IMEM to sync-read which adds
-- one more cycle of fetch latency — orthogonal to pipelining itself,
-- a separate refactor.
--
-- Debug bus
-- ---------
-- Reports the WB-stage commit (post-pipeline, the instruction that
-- *retired* this cycle) rather than the IF-stage fetch (which is in
-- flight and hasn't necessarily survived hazards). This is the
-- meaningful "what happened?" trace for a pipelined CPU.

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.textio.all;

entity riscv_pipelined is
  generic (
    IMEM_ADDR_W : integer := 10;          -- 2**10 = 1024 instr ≈ 4 KB
    DMEM_ADDR_W : integer := 10;          -- 2**10 = 1024 words ≈ 4 KB
    IMEM_INIT   : string  := "";          -- hex file for IMEM
    -- Sim-only: when true, `report` a per-cycle trace of PC + the
    -- instruction word at each of the four pipeline stages. A TB
    -- enables it via `generic map (DEBUG_TRACE => true, ...)`;
    -- ignored by synthesis.
    DEBUG_TRACE : boolean := false
  );
  port (
    clk : in std_logic;
    rst : in std_logic;                   -- synchronous, active high

    -- Debug bus — WB-stage commit. Safe to leave dangling.
    dbg_pc        : out std_logic_vector(31 downto 0);
    dbg_instr     : out std_logic_vector(31 downto 0);
    dbg_reg_we    : out std_logic;
    dbg_reg_waddr : out std_logic_vector(4  downto 0);
    dbg_reg_wdata : out std_logic_vector(31 downto 0)
  );
end entity riscv_pipelined;

architecture rtl of riscv_pipelined is

  -- ------------------------------------------------------------------
  -- IMEM — combinational ROM, init from hex file (same idiom as the
  -- single-cycle CPU; see cpu/riscv_singlecycle/riscv_singlecycle.vhd
  -- for the `constant` vs `signal` rationale).
  -- ------------------------------------------------------------------
  constant IMEM_DEPTH : integer := 2**IMEM_ADDR_W;
  type imem_t is array (0 to IMEM_DEPTH-1) of std_logic_vector(31 downto 0);

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

  constant imem : imem_t := init_imem(IMEM_INIT);

  -- ------------------------------------------------------------------
  -- DMEM — sync write, async read (same idiom as the single-cycle CPU)
  -- ------------------------------------------------------------------
  constant DMEM_DEPTH : integer := 2**DMEM_ADDR_W;
  type dmem_t is array (0 to DMEM_DEPTH-1) of std_logic_vector(31 downto 0);
  signal dmem : dmem_t := (others => (others => '0'));

  -- ------------------------------------------------------------------
  -- Pipeline register record types — one per stage boundary. Using
  -- records keeps the per-register update process readable (one
  -- assignment per boundary) and makes the NOP-insertion idiom
  -- (`X <= X_NOP`) a single line instead of 15.
  -- ------------------------------------------------------------------
  type if_id_t is record
    pc        : std_logic_vector(31 downto 0);
    pc_plus_4 : std_logic_vector(31 downto 0);
    instr     : std_logic_vector(31 downto 0);
  end record;

  type id_ex_t is record
    pc         : std_logic_vector(31 downto 0);
    pc_plus_4  : std_logic_vector(31 downto 0);
    instr      : std_logic_vector(31 downto 0);     -- debug only
    rs1_val    : std_logic_vector(31 downto 0);
    rs2_val    : std_logic_vector(31 downto 0);
    imm        : std_logic_vector(31 downto 0);
    rs1_idx    : std_logic_vector(4 downto 0);
    rs2_idx    : std_logic_vector(4 downto 0);
    rd         : std_logic_vector(4 downto 0);
    alu_op     : std_logic_vector(3 downto 0);
    funct3     : std_logic_vector(2 downto 0);
    alu_src_a  : std_logic;
    alu_src_b  : std_logic;
    reg_write  : std_logic;
    mem_read   : std_logic;
    mem_write  : std_logic;
    wb_src     : std_logic_vector(1 downto 0);
    is_branch  : std_logic;
    is_jal     : std_logic;
    is_jalr    : std_logic;
  end record;

  type ex_mem_t is record
    pc_plus_4  : std_logic_vector(31 downto 0);
    instr      : std_logic_vector(31 downto 0);     -- debug only
    alu_result : std_logic_vector(31 downto 0);
    store_data : std_logic_vector(31 downto 0);
    rd         : std_logic_vector(4 downto 0);
    reg_write  : std_logic;
    mem_read   : std_logic;
    mem_write  : std_logic;
    wb_src     : std_logic_vector(1 downto 0);
  end record;

  type mem_wb_t is record
    pc_plus_4  : std_logic_vector(31 downto 0);
    instr      : std_logic_vector(31 downto 0);     -- debug only
    alu_result : std_logic_vector(31 downto 0);
    mem_data   : std_logic_vector(31 downto 0);
    rd         : std_logic_vector(4 downto 0);
    reg_write  : std_logic;
    wb_src     : std_logic_vector(1 downto 0);
  end record;

  -- NOP-shaped constants for stall/flush/reset. A NOP at the IF/ID
  -- boundary is just `addi x0,x0,0` with PC=0; at later stages it's
  -- "do nothing" — reg_write/mem_read/mem_write/is_branch/etc. all
  -- low, rd=x0 so even if a stray reg_write slipped through it'd hit
  -- the regfile's x0 sink.
  constant IF_ID_NOP  : if_id_t := (
    pc => (others => '0'), pc_plus_4 => (others => '0'),
    instr => NOP_INSTR
  );
  constant ID_EX_NOP  : id_ex_t := (
    pc => (others => '0'), pc_plus_4 => (others => '0'),
    instr => NOP_INSTR,
    rs1_val => (others => '0'), rs2_val => (others => '0'),
    imm => (others => '0'),
    rs1_idx => (others => '0'), rs2_idx => (others => '0'),
    rd      => (others => '0'),
    alu_op  => (others => '0'), funct3 => (others => '0'),
    alu_src_a => '0', alu_src_b => '0',
    reg_write => '0', mem_read => '0', mem_write => '0',
    wb_src => "00",
    is_branch => '0', is_jal => '0', is_jalr => '0'
  );
  constant EX_MEM_NOP : ex_mem_t := (
    pc_plus_4 => (others => '0'),
    instr => NOP_INSTR,
    alu_result => (others => '0'), store_data => (others => '0'),
    rd => (others => '0'),
    reg_write => '0', mem_read => '0', mem_write => '0',
    wb_src => "00"
  );
  constant MEM_WB_NOP : mem_wb_t := (
    pc_plus_4 => (others => '0'),
    instr => NOP_INSTR,
    alu_result => (others => '0'), mem_data => (others => '0'),
    rd => (others => '0'),
    reg_write => '0', wb_src => "00"
  );

  -- ------------------------------------------------------------------
  -- Pipeline registers + next-state wires
  -- ------------------------------------------------------------------
  signal if_id,  if_id_n  : if_id_t  := IF_ID_NOP;
  signal id_ex,  id_ex_n  : id_ex_t  := ID_EX_NOP;
  signal ex_mem, ex_mem_n : ex_mem_t := EX_MEM_NOP;
  signal mem_wb, mem_wb_n : mem_wb_t := MEM_WB_NOP;

  -- ------------------------------------------------------------------
  -- IF stage
  -- ------------------------------------------------------------------
  signal pc          : std_logic_vector(31 downto 0) := (others => '0');
  signal pc_next     : std_logic_vector(31 downto 0);
  signal pc_plus_4   : std_logic_vector(31 downto 0);
  signal if_instr    : std_logic_vector(31 downto 0);

  -- ------------------------------------------------------------------
  -- ID stage (consumes IF/ID register)
  -- ------------------------------------------------------------------
  signal id_d_rs1, id_d_rs2, id_d_rd : std_logic_vector(4 downto 0);
  signal id_d_imm_fmt                : std_logic_vector(2 downto 0);
  signal id_d_alu_op                 : std_logic_vector(3 downto 0);
  signal id_d_alu_src_a              : std_logic;
  signal id_d_alu_src_b              : std_logic;
  signal id_d_mem_read               : std_logic;
  signal id_d_mem_write              : std_logic;
  signal id_d_reg_write              : std_logic;
  signal id_d_wb_src                 : std_logic_vector(1 downto 0);
  signal id_d_is_branch              : std_logic;
  signal id_d_is_jal                 : std_logic;
  signal id_d_is_jalr                : std_logic;
  signal id_d_illegal                : std_logic;
  signal id_rs1_data, id_rs2_data    : std_logic_vector(31 downto 0);
  signal id_imm                      : std_logic_vector(31 downto 0);

  -- ------------------------------------------------------------------
  -- EX stage (consumes ID/EX register)
  -- ------------------------------------------------------------------
  signal fwd_a, fwd_b : std_logic_vector(1 downto 0);
  signal ex_a_forwarded, ex_b_forwarded : std_logic_vector(31 downto 0);
  signal ex_alu_a, ex_alu_b             : std_logic_vector(31 downto 0);
  signal ex_alu_result                  : std_logic_vector(31 downto 0);
  signal ex_alu_zero                    : std_logic;
  signal ex_branch_cmp, ex_branch_taken : std_logic;
  signal ex_take_branch, ex_take_jump   : std_logic;
  signal ex_branch_target               : std_logic_vector(31 downto 0);
  signal ex_jalr_target                 : std_logic_vector(31 downto 0);

  -- ------------------------------------------------------------------
  -- MEM stage (consumes EX/MEM register)
  -- ------------------------------------------------------------------
  signal mem_dmem_rdata : std_logic_vector(31 downto 0);

  -- ------------------------------------------------------------------
  -- WB stage (consumes MEM/WB register)
  -- ------------------------------------------------------------------
  signal wb_data : std_logic_vector(31 downto 0);

  -- ------------------------------------------------------------------
  -- Hazard responses
  -- ------------------------------------------------------------------
  signal stall : std_logic;
  signal flush : std_logic;

begin

  -- ==================================================================
  -- IF — Instruction Fetch
  -- ==================================================================

  -- PC register: synchronous, frozen by `stall`, redirected by a
  -- taken branch / jump resolved in EX.
  process (clk) is
  begin
    if rising_edge(clk) then
      if rst = '1' then
        pc <= (others => '0');
      elsif stall = '0' then
        pc <= pc_next;
      end if;
    end if;
  end process;

  pc_plus_4 <= std_logic_vector(unsigned(pc) + 4);

  -- Combinational fetch.
  if_instr <= imem(to_integer(unsigned(pc(IMEM_ADDR_W+1 downto 2))));

  -- Next PC: branch/jump target if EX resolved one, else PC+4.
  pc_next <= ex_jalr_target                  when id_ex.is_jalr = '1' and ex_take_jump = '1'
        else ex_branch_target                when (ex_take_branch = '1' or ex_take_jump = '1')
        else pc_plus_4;

  -- IF/ID next-state: flush on taken branch, freeze on stall.
  if_id_n <= IF_ID_NOP                       when flush = '1'
        else if_id                           when stall = '1'
        else (pc => pc, pc_plus_4 => pc_plus_4, instr => if_instr);

  -- ==================================================================
  -- ID — Decode + register-file read + immediate generator
  -- ==================================================================
  decoder : entity work.decoder_rv32
    port map (
      instr     => if_id.instr,
      rs1       => id_d_rs1, rs2 => id_d_rs2, rd => id_d_rd,
      imm_fmt   => id_d_imm_fmt,
      alu_op    => id_d_alu_op,
      alu_src_a => id_d_alu_src_a,
      alu_src_b => id_d_alu_src_b,
      mem_read  => id_d_mem_read,
      mem_write => id_d_mem_write,
      reg_write => id_d_reg_write,
      wb_src    => id_d_wb_src,
      is_branch => id_d_is_branch,
      is_jal    => id_d_is_jal,
      is_jalr   => id_d_is_jalr,
      illegal   => id_d_illegal
    );

  immgen : entity work.immgen_rv32
    port map (
      instr => if_id.instr,
      fmt   => id_d_imm_fmt,
      imm   => id_imm
    );

  -- Regfile read is combinational; write port driven by WB stage.
  regfile : entity work.regfile_rv32
    port map (
      clk    => clk,
      we     => mem_wb.reg_write,
      waddr  => mem_wb.rd,
      wdata  => wb_data,
      raddr1 => id_d_rs1, rdata1 => id_rs1_data,
      raddr2 => id_d_rs2, rdata2 => id_rs2_data
    );

  -- ID/EX next-state. Three cases:
  --   1) flush: drop the in-flight ID instruction → NOP into ID/EX.
  --   2) stall: same — the consumer in ID is being held; EX must
  --      receive a NOP this cycle so the load currently in EX can
  --      complete cleanly and forwarding picks up the RAW next cycle.
  --   3) normal: latch the decoded values.
  id_ex_n <=
      ID_EX_NOP when (flush = '1' or stall = '1')
      else (
        pc         => if_id.pc,
        pc_plus_4  => if_id.pc_plus_4,
        instr      => if_id.instr,
        rs1_val    => id_rs1_data,
        rs2_val    => id_rs2_data,
        imm        => id_imm,
        rs1_idx    => id_d_rs1,
        rs2_idx    => id_d_rs2,
        rd         => id_d_rd,
        alu_op     => id_d_alu_op,
        funct3     => if_id.instr(14 downto 12),
        alu_src_a  => id_d_alu_src_a,
        alu_src_b  => id_d_alu_src_b,
        reg_write  => id_d_reg_write,
        mem_read   => id_d_mem_read,
        mem_write  => id_d_mem_write,
        wb_src     => id_d_wb_src,
        is_branch  => id_d_is_branch,
        is_jal     => id_d_is_jal,
        is_jalr    => id_d_is_jalr
      );

  -- ==================================================================
  -- EX — ALU + branch resolution + forwarding
  -- ==================================================================
  fu : entity work.forwarding_unit
    port map (
      ex_rs1 => id_ex.rs1_idx, ex_rs2 => id_ex.rs2_idx,
      mem_rd => ex_mem.rd,     mem_we => ex_mem.reg_write,
      wb_rd  => mem_wb.rd,     wb_we  => mem_wb.reg_write,
      fwd_a  => fwd_a,         fwd_b  => fwd_b
    );

  -- Forwarding muxes. The MEM-stage forward source is the ALU result
  -- still in EX/MEM (not yet written back); the WB-stage source is
  -- wb_data (the same value the regfile is about to latch).
  ex_a_forwarded <= ex_mem.alu_result when fwd_a = "10"
               else wb_data           when fwd_a = "01"
               else id_ex.rs1_val;

  ex_b_forwarded <= ex_mem.alu_result when fwd_b = "10"
               else wb_data           when fwd_b = "01"
               else id_ex.rs2_val;

  -- ALU operand selects (PC vs rs1 for alu_src_a, imm vs rs2 for
  -- alu_src_b) — same logic as the single-cycle CPU, just acting on
  -- the forwarded operands.
  ex_alu_a <= id_ex.pc       when id_ex.alu_src_a = '1' else ex_a_forwarded;
  ex_alu_b <= id_ex.imm      when id_ex.alu_src_b = '1' else ex_b_forwarded;

  alu : entity work.alu_rv32
    port map (
      a => ex_alu_a, b => ex_alu_b, op => id_ex.alu_op,
      result => ex_alu_result, zero => ex_alu_zero
    );

  -- Branch comparator — operates on the FORWARDED rs1/rs2, not on
  -- the raw ALU result (the ALU is busy computing the branch
  -- target). Same 6-way table as the single-cycle CPU.
  process (id_ex.funct3, ex_a_forwarded, ex_b_forwarded) is
  begin
    case id_ex.funct3 is
      when "000"  => ex_branch_cmp <= '1' when ex_a_forwarded = ex_b_forwarded else '0';
      when "001"  => ex_branch_cmp <= '1' when ex_a_forwarded /= ex_b_forwarded else '0';
      when "100"  =>
        ex_branch_cmp <= '1' when signed(ex_a_forwarded) <  signed(ex_b_forwarded) else '0';
      when "101"  =>
        ex_branch_cmp <= '1' when signed(ex_a_forwarded) >= signed(ex_b_forwarded) else '0';
      when "110"  =>
        ex_branch_cmp <= '1' when unsigned(ex_a_forwarded) <  unsigned(ex_b_forwarded) else '0';
      when "111"  =>
        ex_branch_cmp <= '1' when unsigned(ex_a_forwarded) >= unsigned(ex_b_forwarded) else '0';
      when others => ex_branch_cmp <= '0';
    end case;
  end process;

  ex_branch_taken <= id_ex.is_branch and ex_branch_cmp;
  ex_take_branch  <= ex_branch_taken;
  ex_take_jump    <= id_ex.is_jal or id_ex.is_jalr;

  -- Branch / JAL target = PC + imm. JALR target = (rs1 + imm) with
  -- bit 0 cleared (RISC-V spec).
  ex_branch_target <= std_logic_vector(unsigned(id_ex.pc) + unsigned(id_ex.imm));
  ex_jalr_target   <= ex_alu_result(31 downto 1) & '0';

  -- EX/MEM next-state. Stores need the forwarded rs2 value so a
  -- back-to-back "add x10, .. ; sw x10, ..(x11)" sequence stores
  -- the right value.
  ex_mem_n <= (
    pc_plus_4  => id_ex.pc_plus_4,
    instr      => id_ex.instr,
    alu_result => ex_alu_result,
    store_data => ex_b_forwarded,
    rd         => id_ex.rd,
    reg_write  => id_ex.reg_write,
    mem_read   => id_ex.mem_read,
    mem_write  => id_ex.mem_write,
    wb_src     => id_ex.wb_src
  );

  -- ==================================================================
  -- MEM — data memory (sync write, async read)
  -- ==================================================================
  process (clk) is
  begin
    if rising_edge(clk) then
      if ex_mem.mem_write = '1' then
        dmem(to_integer(unsigned(ex_mem.alu_result(DMEM_ADDR_W+1 downto 2))))
          <= ex_mem.store_data;
      end if;
    end if;
  end process;

  mem_dmem_rdata <= dmem(to_integer(unsigned(ex_mem.alu_result(DMEM_ADDR_W+1 downto 2))));

  -- MEM/WB next-state.
  mem_wb_n <= (
    pc_plus_4  => ex_mem.pc_plus_4,
    instr      => ex_mem.instr,
    alu_result => ex_mem.alu_result,
    mem_data   => mem_dmem_rdata,
    rd         => ex_mem.rd,
    reg_write  => ex_mem.reg_write,
    wb_src     => ex_mem.wb_src
  );

  -- ==================================================================
  -- WB — writeback mux (regfile write port driven from MEM/WB)
  -- ==================================================================
  with mem_wb.wb_src select
    wb_data <= mem_wb.alu_result when "00",
               mem_wb.mem_data   when "01",
               mem_wb.pc_plus_4  when "10",
               mem_wb.alu_result when others;

  -- ==================================================================
  -- Hazard detection (drives stall / flush above)
  -- ==================================================================
  hd : entity work.hazard_detector
    port map (
      id_rs1       => id_d_rs1,
      id_rs2       => id_d_rs2,
      ex_rd        => id_ex.rd,
      ex_mem_read  => id_ex.mem_read,
      branch_taken => (ex_take_branch or ex_take_jump),
      stall        => stall,
      flush        => flush
    );

  -- ==================================================================
  -- Pipeline-register update — single sync process per boundary.
  -- ==================================================================
  process (clk) is
  begin
    if rising_edge(clk) then
      if rst = '1' then
        if_id  <= IF_ID_NOP;
        id_ex  <= ID_EX_NOP;
        ex_mem <= EX_MEM_NOP;
        mem_wb <= MEM_WB_NOP;
      else
        if_id  <= if_id_n;
        id_ex  <= id_ex_n;
        ex_mem <= ex_mem_n;
        mem_wb <= mem_wb_n;
      end if;
    end if;
  end process;

  -- ==================================================================
  -- Debug bus — observe RETIRED instructions (post-WB), not in-flight
  -- ones. A reader watching dbg_* sees exactly the side-effects the
  -- program has committed so far, no matter how many bubbles or
  -- flushes happened.
  -- ==================================================================
  dbg_pc        <= std_logic_vector(unsigned(mem_wb.pc_plus_4) - 4);
  dbg_instr     <= mem_wb.instr;
  dbg_reg_we    <= mem_wb.reg_write;
  dbg_reg_waddr <= mem_wb.rd;
  dbg_reg_wdata <= wb_data;

  -- ==================================================================
  -- Optional per-cycle trace (sim-only, gated by DEBUG_TRACE generic).
  -- Multi-line per cycle: PC + the four pipeline-stage instructions,
  -- hazard outcomes, forwarding selects, WB commit, MEM access.
  -- Same fields as the Verilog twin so the two flows produce
  -- comparable traces.
  -- ==================================================================
  -- Plain textio (write(output,...)) instead of `report ... severity
  -- note` so the trace lands on stdout without GHDL's noisy
  -- "<file>:<line>:<col>:@<time>:(report note):" prefix on every line.
  -- Output matches the Verilog twin's $display lines byte-for-byte,
  -- which is what the CI workflow extracts into the run summary.
  --
  -- Wrapped in `if DEBUG_TRACE generate` so the textio call (which is
  -- *not* synthesisable) is elaborated *out* when DEBUG_TRACE=false —
  -- the synthesis-bound instantiations (SoC top, `make diagram`) thus
  -- never see it. Mirrors the `\`ifndef YOSYS` guard around the
  -- equivalent `$display` block in riscv_pipelined.v.
  trace_gen : if DEBUG_TRACE generate
  trace_p : process (clk) is
    variable cyc : integer := 0;
    variable l   : line;
  begin
    if rising_edge(clk) and rst = '0' then
      write(l, string'("[riscv_pipelined] c"));
      write(l, cyc);
      write(l, string'("  pc=")); hwrite(l, pc);
      writeline(output, l);

      write(l, string'("    stages : IF/ID="));  hwrite(l, if_id.instr);
      write(l, string'("  ID/EX="));             hwrite(l, id_ex.instr);
      write(l, string'("  EX/MEM="));            hwrite(l, ex_mem.instr);
      write(l, string'("  MEM/WB="));            hwrite(l, mem_wb.instr);
      writeline(output, l);

      write(l, string'("    hazard : stall="));    write(l, stall);
      write(l, string'(" flush="));                write(l, flush);
      write(l, string'(" take_branch="));          write(l, ex_take_branch);
      write(l, string'(" take_jump="));            write(l, ex_take_jump);
      write(l, string'(" fwd_a="));                write(l, fwd_a);
      write(l, string'(" fwd_b="));                write(l, fwd_b);
      writeline(output, l);

      write(l, string'("    WB     : we="));       write(l, mem_wb.reg_write);
      write(l, string'(" rd=x"));                  write(l, to_integer(unsigned(mem_wb.rd)));
      write(l, string'(" wdata="));                hwrite(l, wb_data);
      writeline(output, l);

      write(l, string'("    MEM    : rd="));       write(l, ex_mem.mem_read);
      write(l, string'(" wr="));                   write(l, ex_mem.mem_write);
      write(l, string'(" addr="));                 hwrite(l, ex_mem.alu_result);
      writeline(output, l);

      cyc := cyc + 1;
    end if;
  end process;
  end generate trace_gen;

end architecture rtl;
