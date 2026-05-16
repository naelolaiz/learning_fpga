-- tb_riscv_pipelined_load_use.vhd
--
-- Targeted load-use hazard test for the pipelined CPU. Exercises
-- the path that *can't* be resolved by forwarding alone — a load
-- in EX whose rd is consumed by the very next instruction in ID.
-- The hazard_detector must assert `stall` and the pipeline must
-- insert a one-cycle bubble; otherwise the consumer reads stale
-- data and the final state is wrong.
--
-- The single-cycle CPU produces the same final state without needing
-- a stall — running the same hex on both CPUs is a useful
-- equivalence check (this is the only TB the pipelined CPU has that
-- isn't a port of an existing single-cycle TB, but the program
-- still runs identically on either CPU).
--
--   prog_load_use.S:
--     addi t0, x0, 42   ;  sw t0, 0(x0)
--     addi t0, x0, 7    ;  sw t0, 4(x0)
--     lw   t1, 0(x0)    ;  add t2, t1, t1     -- load-use pair #1
--     lw   s0, 4(x0)    ;  add s1, s0, s0     -- load-use pair #2
--     halt
--
--   Expected final state:
--     t0 (x5) = 7    t1 (x6) = 42   t2 (x7) = 84
--     s0 (x8) = 7    s1 (x9) = 14

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity tb_riscv_pipelined_load_use is
end entity tb_riscv_pipelined_load_use;

architecture testbench of tb_riscv_pipelined_load_use is
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
      IMEM_INIT   => "../../tools/rv32_asm/programs/prog_load_use.hex"
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

    assert shadow_regs(5) = x"00000007"
      report "prog_load_use: expected t0 = 7, got "
           & integer'image(to_integer(unsigned(shadow_regs(5))))
      severity error;
    assert shadow_regs(6) = x"0000002A"
      report "prog_load_use: expected t1 = 42 (load value), got "
           & integer'image(to_integer(unsigned(shadow_regs(6))))
      severity error;
    assert shadow_regs(7) = x"00000054"
      report "prog_load_use: expected t2 = 84 (t1+t1, depends on load-use stall), got "
           & integer'image(to_integer(unsigned(shadow_regs(7))))
      severity error;
    assert shadow_regs(8) = x"00000007"
      report "prog_load_use: expected s0 = 7, got "
           & integer'image(to_integer(unsigned(shadow_regs(8))))
      severity error;
    assert shadow_regs(9) = x"0000000E"
      report "prog_load_use: expected s1 = 14 (s0+s0, depends on load-use stall), got "
           & integer'image(to_integer(unsigned(shadow_regs(9))))
      severity error;

    report "tb_riscv_pipelined_load_use simulation done!" severity note;
    sSimulationActive <= false;
    wait;
  end process;

end architecture testbench;
