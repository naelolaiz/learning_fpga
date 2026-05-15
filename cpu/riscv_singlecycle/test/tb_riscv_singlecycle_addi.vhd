-- tb_riscv_singlecycle_addi.vhd
--
-- Loads programs/prog_addi.hex into the CPU's IMEM, runs until the
-- HALT instruction (`jal x0, 0` = 0x0000006F) appears on the
-- instruction bus, and asserts the final architectural register
-- state matches what the program is supposed to compute:
--
--   prog_addi.S:
--     addi t0, x0, 1     # t0 = 1
--     addi t0, t0, 2     # t0 = 3
--     halt               # jal x0, .
--
--   Expected: t0 (= x5) = 0x00000003.
--
-- Architecture note: the testbench keeps a *shadow* register file
-- in `shadow_regs`, snooped from the CPU's debug bus
-- (dbg_reg_we / dbg_reg_waddr / dbg_reg_wdata). This avoids
-- hierarchical references into dut.regfile.regs and works the same
-- way for the upcoming pipelined CPU — both DUTs expose the same
-- debug bus, so the testbench is portable across them.

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity tb_riscv_singlecycle_addi is
end entity tb_riscv_singlecycle_addi;

architecture testbench of tb_riscv_singlecycle_addi is
  constant CLK_PERIOD  : time    := 20 ns;
  constant HALT_INSTR  : std_logic_vector(31 downto 0) := x"0000006F";
  constant MAX_CYCLES  : integer := 200;

  signal sClk : std_logic := '0';
  signal sRst : std_logic := '1';
  signal sSimulationActive : boolean := true;

  -- DUT debug bus
  signal sPc        : std_logic_vector(31 downto 0);
  signal sInstr     : std_logic_vector(31 downto 0);
  signal sRegWe     : std_logic;
  signal sRegWaddr  : std_logic_vector(4  downto 0);
  signal sRegWdata  : std_logic_vector(31 downto 0);

  -- Shadow regfile (mirrors the CPU's commits via the debug bus).
  type reg_array_t is array (0 to 31) of std_logic_vector(31 downto 0);
  signal shadow_regs : reg_array_t := (others => (others => '0'));

  signal halted : std_logic := '0';
begin

  dut : entity work.riscv_singlecycle
    generic map (
      IMEM_ADDR_W => 8,                                              -- 256 instr is plenty
      DMEM_ADDR_W => 8,
      IMEM_INIT   => "../../tools/rv32_asm/programs/prog_addi.hex"
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

  -- Snoop the debug bus and shadow every commit. x0 writes are
  -- dropped (matches the regfile's own behaviour).
  --
  -- Sample on the FALLING edge — the same edge the regfile commits
  -- on. Sampling on the rising edge would catch wb_data AFTER the
  -- regfile already updated, when the combinational chain has
  -- re-evaluated with the new register state and `wb_data` no
  -- longer reflects what was actually written. (`addi t0, t0, 2`
  -- writes 3 at the falling edge, then the combinational chain
  -- recomputes with the new t0=3 and shows wb_data=5 — a stale
  -- "what-if" value, not what hit storage.)
  --
  -- Halt detection is independent of the write timing, but we keep
  -- it on the same edge so the testbench has a single sampling clock.
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
    -- Reset window
    wait for 2 * CLK_PERIOD;
    sRst <= '0';

    -- Run until halt or timeout
    while halted = '0' and cycle_count < MAX_CYCLES loop
      wait until rising_edge(sClk);
      cycle_count := cycle_count + 1;
    end loop;
    assert halted = '1'
      report "Timeout: program did not halt within "
           & integer'image(MAX_CYCLES) & " cycles"
      severity failure;

    -- Give the CPU one more clock so any writeback initiated on the
    -- HALT cycle (there shouldn't be one, but be safe) has settled.
    wait until rising_edge(sClk);

    -- Final assertion: t0 (x5) should hold 3.
    assert shadow_regs(5) = x"00000003"
      report "prog_addi: expected t0 = 3, got "
           & integer'image(to_integer(unsigned(shadow_regs(5))))
      severity error;

    report "tb_riscv_singlecycle_addi simulation done!" severity note;
    sSimulationActive <= false;
    wait;
  end process;

end architecture testbench;
