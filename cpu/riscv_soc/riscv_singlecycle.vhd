-- riscv_singlecycle.vhd  (cpu/riscv_soc/ variant)
--
-- Same single-cycle RV32I datapath as cpu/riscv_singlecycle/ — but
-- with the DMEM **exposed as an external port** so the SoC top can
-- multiplex it with memory-mapped peripherals. The IMEM stays
-- internal (programs are baked in at elaboration via IMEM_INIT,
-- like the standalone CPU).
--
-- The only structural difference from cpu/riscv_singlecycle/ is the
-- removal of the internal `dmem` array + write process, and the
-- addition of three external ports:
--
--   dmem_addr   : 32-bit byte address (the ALU result for LW/SW)
--   dmem_wdata  : 32-bit data to write (rs2 for SW)
--   dmem_we     : 1 when the current instruction is SW
--   dmem_re     : 1 when the current instruction is LW (informational —
--                 useful for peripherals that have side-effects on read)
--   dmem_rdata  : 32-bit data the SoC bus presents back to the CPU
--                 (combinational: must be valid in the same cycle the
--                 address goes out, like the original internal DMEM)
--
-- The combinational-read constraint comes from the single-cycle
-- design (everything fits in one clock); the SoC top satisfies it
-- by using a combinational-read DMEM (ram_sync's read-then-write
-- pattern adapted) and combinational MMIO read mux.

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.textio.all;

entity riscv_singlecycle is
  generic (
    IMEM_ADDR_W : integer := 10;
    IMEM_INIT   : string  := ""
  );
  port (
    clk : in std_logic;
    rst : in std_logic;

    -- External DMEM bus (sync write driven by the CPU's clk; async
    -- read so the writeback mux gets data in the same cycle).
    dmem_addr  : out std_logic_vector(31 downto 0);
    dmem_wdata : out std_logic_vector(31 downto 0);
    dmem_we    : out std_logic;
    dmem_re    : out std_logic;
    dmem_rdata : in  std_logic_vector(31 downto 0);

    -- Debug
    dbg_pc        : out std_logic_vector(31 downto 0);
    dbg_instr     : out std_logic_vector(31 downto 0);
    dbg_reg_we    : out std_logic;
    dbg_reg_waddr : out std_logic_vector(4  downto 0);
    dbg_reg_wdata : out std_logic_vector(31 downto 0)
  );
end entity riscv_singlecycle;

architecture rtl of riscv_singlecycle is

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

  -- `constant`: IMEM is read-only at runtime — its contents come
  -- from the .hex file at elaboration and never change. Same
  -- reasoning as the standalone CPU (cpu/riscv_singlecycle/).
  constant imem : imem_t := init_imem(IMEM_INIT);

  signal pc           : std_logic_vector(31 downto 0) := (others => '0');
  signal pc_plus_4    : std_logic_vector(31 downto 0);
  signal pc_plus_imm  : std_logic_vector(31 downto 0);
  signal next_pc      : std_logic_vector(31 downto 0);
  signal instr        : std_logic_vector(31 downto 0);

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

  alias instr_funct3 : std_logic_vector(2 downto 0) is instr(14 downto 12);

  signal rs1_data, rs2_data : std_logic_vector(31 downto 0);
  signal imm                : std_logic_vector(31 downto 0);

  signal alu_a, alu_b       : std_logic_vector(31 downto 0);
  signal alu_result         : std_logic_vector(31 downto 0);
  signal alu_zero           : std_logic;

  signal wb_data            : std_logic_vector(31 downto 0);

  signal branch_taken       : std_logic;
  signal take_branch        : std_logic;
begin

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
  instr     <= imem(to_integer(unsigned(pc(IMEM_ADDR_W+1 downto 2))));

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
    port map (instr => instr, fmt => d_imm_fmt, imm => imm);

  regfile : entity work.regfile_rv32
    port map (
      clk    => clk,
      we     => d_reg_write,
      waddr  => d_rd,
      wdata  => wb_data,
      raddr1 => d_rs1, rdata1 => rs1_data,
      raddr2 => d_rs2, rdata2 => rs2_data
    );

  alu_a <= pc       when d_alu_src_a = '1' else rs1_data;
  alu_b <= imm      when d_alu_src_b = '1' else rs2_data;

  alu : entity work.alu_rv32
    port map (a => alu_a, b => alu_b, op => d_alu_op,
              result => alu_result, zero => alu_zero);

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

  pc_plus_imm <= std_logic_vector(unsigned(pc) + unsigned(imm));

  next_pc <= (alu_result(31 downto 1) & '0') when d_is_jalr = '1'
        else pc_plus_imm                      when (d_is_jal = '1' or take_branch = '1')
        else pc_plus_4;

  -- External DMEM bus
  dmem_addr  <= alu_result;
  dmem_wdata <= rs2_data;
  dmem_we    <= d_mem_write;
  dmem_re    <= d_mem_read;

  with d_wb_src select
    wb_data <= alu_result when "00",
               dmem_rdata when "01",
               pc_plus_4  when "10",
               imm        when "11",
               alu_result when others;

  dbg_pc        <= pc;
  dbg_instr     <= instr;
  dbg_reg_we    <= d_reg_write;
  dbg_reg_waddr <= d_rd;
  dbg_reg_wdata <= wb_data;

end architecture rtl;
