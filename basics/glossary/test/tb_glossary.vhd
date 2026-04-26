library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity tb_glossary is
end entity tb_glossary;

architecture testbench of tb_glossary is
    signal sSimulationActive : boolean   := true;
    signal sClock            : std_logic := '0';

    signal sA, sB, sSel : std_logic := '0';
    signal sSel4        : std_logic_vector(1 downto 0) := "00";
    signal sAv, sBv     : std_logic_vector(3 downto 0) := (others => '0');
    signal sRst, sEn    : std_logic := '0';

    signal o_and, o_or, o_not, o_xor                  : std_logic;
    signal o_nand, o_nor, o_xnor                      : std_logic;
    signal o_reduce_or, o_reduce_and, o_reduce_xor    : std_logic;
    signal o_mux2, o_mux4                             : std_logic;
    signal o_add, o_sub, o_shl, o_shr                 : std_logic_vector(3 downto 0);
    signal o_eq, o_lt                                 : std_logic;
    signal o_dff, o_dffe, o_dffr                      : std_logic;
    signal o_counter                                  : std_logic_vector(3 downto 0);
begin

    DUT : entity work.glossary(rtl)
        port map (
            a    => sA,
            b    => sB,
            sel  => sSel,
            sel4 => sSel4,
            av   => sAv,
            bv   => sBv,
            clk  => sClock,
            rst  => sRst,
            en   => sEn,

            o_and  => o_and,
            o_or   => o_or,
            o_not  => o_not,
            o_xor  => o_xor,
            o_nand => o_nand,
            o_nor  => o_nor,
            o_xnor => o_xnor,

            o_reduce_or  => o_reduce_or,
            o_reduce_and => o_reduce_and,
            o_reduce_xor => o_reduce_xor,

            o_mux2 => o_mux2,
            o_mux4 => o_mux4,

            o_add => o_add,
            o_sub => o_sub,
            o_eq  => o_eq,
            o_lt  => o_lt,
            o_shl => o_shl,
            o_shr => o_shr,

            o_dff     => o_dff,
            o_dffe    => o_dffe,
            o_dffr    => o_dffr,
            o_counter => o_counter
        );

    -- 50 MHz clock (20 ns period); only ticks while sim is active.
    sClock <= not sClock after 10 ns when sSimulationActive;

    CHECK : process is
    begin
        -- Combinational block: drive a representative pattern, settle, check.
        sA    <= '1';
        sB    <= '0';
        sSel  <= '1';
        sSel4 <= "10";
        sAv   <= "1100";  -- 12
        sBv   <= "0011";  -- 3
        wait for 1 ns;

        assert o_and  = (sA and  sB)  report "o_and"  severity error;
        assert o_or   = (sA or   sB)  report "o_or"   severity error;
        assert o_not  = (not sA)      report "o_not"  severity error;
        assert o_xor  = (sA xor  sB)  report "o_xor"  severity error;
        assert o_nand = (sA nand sB)  report "o_nand" severity error;
        assert o_nor  = (sA nor  sB)  report "o_nor"  severity error;
        assert o_xnor = (sA xnor sB)  report "o_xnor" severity error;

        assert o_reduce_or  = '1' report "o_reduce_or"  severity error;
        assert o_reduce_and = '0' report "o_reduce_and" severity error;
        assert o_reduce_xor = '0' report "o_reduce_xor" severity error;

        assert o_mux2 = sA      report "o_mux2 (sel=1 -> a)" severity error;
        assert o_mux4 = sAv(2)  report "o_mux4 (sel4=10 -> av(2))" severity error;

        assert o_add = "1111" report "o_add (12+3=15)"  severity error;
        assert o_sub = "1001" report "o_sub (12-3=9)"   severity error;
        assert o_eq  = '0'    report "o_eq"             severity error;
        assert o_lt  = '0'    report "o_lt (12<3 false)" severity error;
        assert o_shl = "1000" report "o_shl (1100<<1)"  severity error;
        assert o_shr = "0110" report "o_shr (1100>>1)"  severity error;

        -- Sequential block: load a=1, en=1, rst=0 across the first edge.
        sRst <= '0';
        sEn  <= '1';
        wait until rising_edge(sClock);
        wait for 1 ns;
        assert o_dff     = '1'    report "o_dff after first edge"             severity error;
        assert o_dffe    = '1'    report "o_dffe after first edge with en=1"  severity error;
        assert o_dffr    = '1'    report "o_dffr after first edge no rst"     severity error;
        assert o_counter = "0001" report "o_counter after first edge"         severity error;

        -- Disable enable, change a: dffe must freeze, dff/dffr follow a, counter ticks.
        sA  <= '0';
        sEn <= '0';
        wait until rising_edge(sClock);
        wait for 1 ns;
        assert o_dff     = '0'    report "o_dff after second edge (a=0)"      severity error;
        assert o_dffe    = '1'    report "o_dffe must hold when en=0"         severity error;
        assert o_dffr    = '0'    report "o_dffr after second edge (a=0)"     severity error;
        assert o_counter = "0010" report "o_counter after second edge"        severity error;

        -- Synchronous reset: dffr and counter clear; dff still tracks a.
        sRst <= '1';
        wait until rising_edge(sClock);
        wait for 1 ns;
        assert o_dffr    = '0'    report "o_dffr after rst"      severity error;
        assert o_counter = "0000" report "o_counter after rst"   severity error;

        report "Simulation done!" severity note;
        sSimulationActive <= false;
        wait;
    end process CHECK;

end architecture testbench;
