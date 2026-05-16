-- tb_riscv_singlecycle_branches.vhd
--
-- Runs programs/prog_branches.hex which exercises every conditional
-- branch flavour (BEQ, BNE, BLT, BGE, BLTU, BGEU) with both taken
-- and not-taken paths, plus a counter `s0` that increments only when
-- the "should be taken" branch actually fires. Final s0 = 4 means
-- every taken branch took correctly AND no not-taken branch
-- erroneously fired (the not-taken paths bump s0 to -1 if they
-- mistakenly took).
--
-- See ../../tools/rv32_asm/programs/prog_branches.S for the full
-- branch matrix.

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity tb_riscv_singlecycle_branches is
end entity tb_riscv_singlecycle_branches;

architecture testbench of tb_riscv_singlecycle_branches is
  constant CLK_PERIOD  : time    := 20 ns;
  constant HALT_INSTR  : std_logic_vector(31 downto 0) := x"0000006F";
  constant MAX_CYCLES  : integer := 200;

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

  dut : entity work.riscv_singlecycle
    generic map (
      IMEM_ADDR_W => 8,
      DMEM_ADDR_W => 8,
      IMEM_INIT   => "../../tools/rv32_asm/programs/prog_branches.hex"
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

  -- See tb_riscv_singlecycle_addi for why this samples on falling
  -- edge (matches the regfile's commit timing; rising-edge samples
  -- would catch a stale combinational re-evaluation of wb_data).
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

    -- s0 (= x8) = 4 means all four "should-be-taken" branches took,
    -- AND none of the not-taken branches fired the -1 sentinel.
    assert shadow_regs(8) = x"00000004"
      report "prog_branches: expected s0 = 4, got "
           & integer'image(to_integer(signed(shadow_regs(8))))
      severity error;

    report "tb_riscv_singlecycle_branches simulation done!" severity note;
    sSimulationActive <= false;
    wait;
  end process;

end architecture testbench;
