-- tb_riscv_pipelined_loop.vhd
--
-- Pipelined-CPU twin of tb_riscv_singlecycle_loop. Counted decrement
-- loop with a back-edge branch — every iteration of the branch is a
-- taken-branch flush in the pipeline, so this also stresses the
-- flush logic in addition to RAW forwarding on t0 / t1.
--
--   prog_loop.S:
--     addi t0, x0, 5      # counter
--     addi t1, x0, 0
--   loop:
--     beq  t0, x0, done
--     addi t1, t1, 1
--     addi t0, t0, -1
--     jal  x0, loop
--   done:
--     halt
--
--   Expected: t0 (x5) = 0, t1 (x6) = 5.

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity tb_riscv_pipelined_loop is
end entity tb_riscv_pipelined_loop;

architecture testbench of tb_riscv_pipelined_loop is
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
      IMEM_INIT   => "../../tools/rv32_asm/programs/prog_loop.hex"
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

    assert shadow_regs(5) = x"00000000"
      report "prog_loop: expected t0 = 0, got "
           & integer'image(to_integer(unsigned(shadow_regs(5))))
      severity error;
    assert shadow_regs(6) = x"00000005"
      report "prog_loop: expected t1 = 5, got "
           & integer'image(to_integer(unsigned(shadow_regs(6))))
      severity error;

    report "tb_riscv_pipelined_loop simulation done!" severity note;
    sSimulationActive <= false;
    wait;
  end process;

end architecture testbench;
