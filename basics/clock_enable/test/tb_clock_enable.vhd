library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.env.all;

entity tb_clock_enable is end entity;
architecture test of tb_clock_enable is
    signal clk : std_logic := '0';
    signal rst : std_logic := '1';
    signal enable_async : std_logic := '0';
    signal enable_sync, tick, fast_sync, fast_tick : std_logic;
    signal count : unsigned(3 downto 0);
    signal fast_count : unsigned(0 downto 0);
begin
    clk <= not clk after 5 ns;
    dut : entity work.clock_enable port map(clk, rst, enable_async, enable_sync, tick, count);
    fast : entity work.clock_enable generic map(DIVISOR => 1, COUNT_WIDTH => 1)
        port map(clk, rst, enable_async, fast_sync, fast_tick, fast_count);
    process
        procedure step is
        begin wait until rising_edge(clk); wait for 1 ns; end procedure;
    begin
        step;
        assert tick = '0' and count = 0 and enable_sync = '0'
            report "reset must clear outputs" severity failure;
        wait until falling_edge(clk); rst <= '0'; enable_async <= '1';
        step;
        assert enable_sync = '0' report "async input bypassed first stage" severity failure;
        step;
        assert enable_sync = '1' report "second stage failed to capture input" severity failure;
        step;
        assert count = 0 and tick = '0' report "count advanced before first tick" severity failure;
        step;
        assert count = 1 and tick = '1' report "first enabled tick must increment" severity failure;
        for cycle in 5 to 68 loop
            step;
            assert (tick = '1') = (cycle mod 4 = 0) and count = (cycle / 4) mod 16
                report "tick cadence or modulo wrap wrong" severity failure;
            assert fast_tick = '1' and fast_count = (cycle - 2) mod 2
                report "DIVISOR=1 / COUNT_WIDTH=1 failed" severity failure;
        end loop;
        wait until falling_edge(clk); enable_async <= '0';
        step;
        assert enable_sync = '1' report "disable bypassed first stage" severity failure;
        step;
        assert enable_sync = '0' report "disable did not propagate" severity failure;
        for cycle in 1 to 8 loop step; end loop;
        assert count = 1 report "disabled count must hold" severity failure;
        wait until falling_edge(clk); rst <= '1';
        step; step;
        assert count = 0 and tick = '0' and fast_count = 0 and fast_tick = '0'
            report "held reset failed" severity failure;
        report "clock_enable: cadence, synchronization, hold, wrap and reset passed";
        finish;
    end process;
end architecture;
