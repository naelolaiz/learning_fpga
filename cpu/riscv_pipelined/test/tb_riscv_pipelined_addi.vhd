-- tb_riscv_pipelined_addi.vhd
--
-- Pipelined-CPU twin of tb_riscv_singlecycle_addi: same program, same
-- final-state check, same shadow-regfile snooping idiom. The only
-- per-cycle differences are pipeline latency (4 extra cycles for the
-- last write to retire) and that dbg_instr now reports the WB-stage
-- instruction — so halt detection fires when HALT has *retired*,
-- which conveniently guarantees all prior writes have committed.
--
--   prog_addi.S:
--     addi t0, x0, 1
--     addi t0, t0, 2     # RAW on t0 — forwarding_unit handles MEM→EX
--     halt
--
--   Expected: t0 (x5) = 0x00000003.
--
-- This TB also doubles as the DEBUG_TRACE demo: we instantiate the CPU
-- with DEBUG_TRACE => true so each simulated cycle prints PC, all four
-- pipeline-stage instructions, hazard outcomes (stall/flush/branch/
-- forward) and WB/MEM observations. The program is tiny but exercises
-- the most common pipeline event (a back-to-back RAW resolved by MEM→EX
-- forwarding), so the trace is a good first read for understanding
-- what the pipeline does cycle-by-cycle.

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity tb_riscv_pipelined_addi is
end entity tb_riscv_pipelined_addi;

architecture testbench of tb_riscv_pipelined_addi is
  constant CLK_PERIOD : time    := 20 ns;
  constant HALT_INSTR : std_logic_vector(31 downto 0) := x"0000006F";
  constant MAX_CYCLES : integer := 500;

  signal sClk : std_logic := '0';
  signal sRst : std_logic := '1';
  signal sSimulationActive : boolean := true;

  signal sPc        : std_logic_vector(31 downto 0);
  signal sInstr     : std_logic_vector(31 downto 0);
  signal sRegWe     : std_logic;
  signal sRegWaddr  : std_logic_vector(4  downto 0);
  signal sRegWdata  : std_logic_vector(31 downto 0);

  type reg_array_t is array (0 to 31) of std_logic_vector(31 downto 0);
  signal shadow_regs : reg_array_t := (others => (others => '0'));

  signal halted : std_logic := '0';
begin

  dut : entity work.riscv_pipelined
    generic map (
      IMEM_ADDR_W => 8,
      DMEM_ADDR_W => 8,
      IMEM_INIT   => "../../tools/rv32_asm/programs/prog_addi.hex",
      DEBUG_TRACE => true
    )
    port map (
      clk           => sClk,
      rst           => sRst,
      dbg_pc        => sPc,
      dbg_instr     => sInstr,
      dbg_reg_we    => sRegWe,
      dbg_reg_waddr => sRegWaddr,
      dbg_reg_wdata => sRegWdata
    );

  sClk <= not sClk after CLK_PERIOD/2 when sSimulationActive;

  shadow : process (sClk) is
  begin
    if falling_edge(sClk) then
      if sRegWe = '1' and unsigned(sRegWaddr) /= 0 then
        shadow_regs(to_integer(unsigned(sRegWaddr))) <= sRegWdata;
      end if;
      if sInstr = HALT_INSTR then
        halted <= '1';
      end if;
    end if;
  end process;

  driver : process is
    variable cycle_count : integer := 0;
  begin
    wait for 2 * CLK_PERIOD;
    sRst <= '0';

    while halted = '0' and cycle_count < MAX_CYCLES loop
      wait until rising_edge(sClk);
      cycle_count := cycle_count + 1;
    end loop;
    assert halted = '1'
      report "Timeout: program did not halt within "
           & integer'image(MAX_CYCLES) & " cycles"
      severity failure;

    wait until rising_edge(sClk);

    assert shadow_regs(5) = x"00000003"
      report "prog_addi: expected t0 = 3, got "
           & integer'image(to_integer(unsigned(shadow_regs(5))))
      severity error;

    report "tb_riscv_pipelined_addi simulation done!" severity note;
    sSimulationActive <= false;
    wait;
  end process;

end architecture testbench;
