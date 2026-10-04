-- JALR overlap, target alignment, link values, and skipped-store regression.
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
entity tb_riscv_soc_jalr is end entity;
architecture testbench of tb_riscv_soc_jalr is
    signal clk : std_logic := '0';
    signal rst : std_logic := '1';
    signal active : boolean := true;
    signal dbg_pc, dbg_instr, dbg_reg_wdata : std_logic_vector(31 downto 0);
    signal dbg_reg_we : std_logic;
    signal dbg_reg_waddr : std_logic_vector(4 downto 0);
    type regs_t is array (0 to 31) of std_logic_vector(31 downto 0);
    signal shadow_regs : regs_t := (others => (others => '0'));
    signal halted : boolean := false;
    signal halt_pc : std_logic_vector(31 downto 0) := (others => '0');
    signal uart_tx : std_logic;
begin
    dut : entity work.riscv_soc
        generic map (
            CLKS_PER_BIT => 8,
            IMEM_INIT => "../../tools/rv32_asm/programs/prog_jalr.hex")
        port map (
            clk_50mhz => clk, rst_n => not rst, uart_rx_in => '1', uart_tx_out => uart_tx,
            dbg_pc => dbg_pc, dbg_instr => dbg_instr, dbg_reg_we => dbg_reg_we,
            dbg_reg_waddr => dbg_reg_waddr, dbg_reg_wdata => dbg_reg_wdata);
    clk <= not clk after 10 ns when active;
    -- Read the commit bus before same-edge signal updates advance the instruction.
    monitor : process(clk) is
    begin
        if rising_edge(clk) and rst = '0' then
            if dbg_reg_we = '1' and unsigned(dbg_reg_waddr) /= 0 then
                shadow_regs(to_integer(unsigned(dbg_reg_waddr))) <= dbg_reg_wdata;
            end if;
            if dbg_instr = x"0000006F" then
                halt_pc <= dbg_pc;
                halted <= true;
            end if;
        end if;
    end process;
    driver : process is
        variable cycles : natural := 0;
    begin
        wait for 45 ns;
        rst <= '0';
        while not halted and cycles < 100 loop
            wait until rising_edge(clk);
            wait for 1 ns;
            cycles := cycles + 1;
        end loop;
        assert halted report "JALR program timed out" severity failure;
        assert unsigned(halt_pc) = 116
            report "JALR chose wrong path: halted at PC=" & integer'image(to_integer(unsigned(halt_pc)))
            severity failure;
        assert unsigned(shadow_regs(8)) = 4 report "Startup must commit once, followed by three JALR destinations" severity failure;
        assert unsigned(shadow_regs(9)) = 16 report "First overlapping JALR link must be 16" severity failure;
        assert unsigned(shadow_regs(18)) = 44 report "Negative-immediate overlapping JALR link must be 44" severity failure;
        assert unsigned(shadow_regs(19)) = 76 report "Distinct-register JALR link must be 76" severity failure;
        assert unsigned(shadow_regs(20)) = 42 report "Committed store/load value must be 42" severity failure;
        assert unsigned(shadow_regs(21)) = 43 report "Load-use result must be 43" severity failure;
        assert unsigned(shadow_regs(22)) = 0 report "A wrong-path store committed" severity failure;
        report "tb_riscv_soc_jalr simulation done!" severity note;
        active <= false;
        wait;
    end process;
end architecture;
