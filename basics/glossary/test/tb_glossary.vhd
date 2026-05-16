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
    signal sSel4Oh      : std_logic_vector(3 downto 0) := "0000";
    signal sAv, sBv     : std_logic_vector(3 downto 0) := (others => '0');
    signal sRst, sEn    : std_logic := '0';

    signal o_and, o_or, o_not, o_xor                  : std_logic;
    signal o_nand, o_nor, o_xnor                      : std_logic;
    signal o_reduce_or, o_reduce_and, o_reduce_xor    : std_logic;
    signal o_reduce_bool                              : std_logic;
    signal o_logic_not, o_logic_and, o_logic_or       : std_logic;
    signal o_mux2, o_mux4, o_pmux                     : std_logic;
    signal o_add, o_sub, o_neg, o_pos                 : std_logic_vector(3 downto 0);
    signal o_mul                                      : std_logic_vector(7 downto 0);
    signal o_eq, o_ne, o_lt, o_gt, o_ge, o_le         : std_logic;
    signal o_shl, o_shr, o_sshr, o_shift              : std_logic_vector(3 downto 0);
    signal o_dff, o_dffe, o_dffr, o_dlatch            : std_logic;
    signal o_counter                                  : std_logic_vector(3 downto 0);
    signal o_mem                                      : std_logic;
begin

    DUT : entity work.glossary(rtl)
        port map (
            a       => sA,
            b       => sB,
            sel     => sSel,
            sel4    => sSel4,
            sel4_oh => sSel4Oh,
            av      => sAv,
            bv      => sBv,
            clk     => sClock,
            rst     => sRst,
            en      => sEn,

            o_and  => o_and,   o_or   => o_or,   o_not  => o_not,
            o_xor  => o_xor,   o_nand => o_nand, o_nor  => o_nor,
            o_xnor => o_xnor,

            o_reduce_or   => o_reduce_or,
            o_reduce_and  => o_reduce_and,
            o_reduce_xor  => o_reduce_xor,
            o_reduce_bool => o_reduce_bool,

            o_logic_not => o_logic_not,
            o_logic_and => o_logic_and,
            o_logic_or  => o_logic_or,

            o_mux2 => o_mux2, o_mux4 => o_mux4, o_pmux => o_pmux,

            o_add => o_add, o_sub => o_sub, o_mul => o_mul,
            o_neg => o_neg, o_pos => o_pos,

            o_eq => o_eq, o_ne => o_ne, o_lt => o_lt,
            o_gt => o_gt, o_ge => o_ge, o_le => o_le,

            o_shl   => o_shl,
            o_shr   => o_shr,
            o_sshr  => o_sshr,
            o_shift => o_shift,

            o_dff     => o_dff,
            o_dffe    => o_dffe,
            o_dffr    => o_dffr,
            o_dlatch  => o_dlatch,
            o_counter => o_counter,

            o_mem => o_mem
        );

    -- 50 MHz clock (20 ns period); only ticks while sim is active.
    sClock <= not sClock after 10 ns when sSimulationActive;

    CHECK : process is
    begin
        -- Combinational block: drive a representative pattern, settle, check.
        sA      <= '1';
        sB      <= '0';
        sSel    <= '1';
        sSel4   <= "10";
        sSel4Oh <= "0100";       -- one-hot: bit 2 selected
        sAv     <= "1100";       -- 12
        sBv     <= "0011";       -- 3
        wait for 1 ns;

        assert o_and  = (sA and  sB)  report "o_and"  severity error;
        assert o_or   = (sA or   sB)  report "o_or"   severity error;
        assert o_not  = (not sA)      report "o_not"  severity error;
        assert o_xor  = (sA xor  sB)  report "o_xor"  severity error;
        assert o_nand = (sA nand sB)  report "o_nand" severity error;
        assert o_nor  = (sA nor  sB)  report "o_nor"  severity error;
        assert o_xnor = (sA xnor sB)  report "o_xnor" severity error;

        assert o_reduce_or   = '1' report "o_reduce_or"   severity error;
        assert o_reduce_and  = '0' report "o_reduce_and"  severity error;
        assert o_reduce_xor  = '0' report "o_reduce_xor"  severity error;
        assert o_reduce_bool = '1' report "o_reduce_bool" severity error;

        assert o_logic_not = '0' report "o_logic_not (av != 0)"  severity error;
        assert o_logic_and = '1' report "o_logic_and (both nz)"  severity error;
        assert o_logic_or  = '1' report "o_logic_or (any nz)"    severity error;

        assert o_mux2 = sA      report "o_mux2 (sel=1 -> a)" severity error;
        assert o_mux4 = sAv(2)  report "o_mux4 (sel4=10 -> av(2))" severity error;
        assert o_pmux = sAv(2)  report "o_pmux (sel4_oh=0100 -> av(2))" severity error;

        assert o_add = "1111"     report "o_add (12+3=15)"   severity error;
        assert o_sub = "1001"     report "o_sub (12-3=9)"    severity error;
        assert o_mul = x"24"      report "o_mul (12*3=36)"   severity error;
        assert o_neg = "0100"     report "o_neg (-12 mod 16 = 4)" severity error;
        assert o_pos = sAv        report "o_pos (+av identity)"  severity error;

        assert o_eq = '0' report "o_eq"             severity error;
        assert o_ne = '1' report "o_ne"             severity error;
        assert o_lt = '0' report "o_lt (12<3 false)"  severity error;
        assert o_gt = '1' report "o_gt (12>3)"       severity error;
        assert o_ge = '1' report "o_ge (12>=3)"      severity error;
        assert o_le = '0' report "o_le (12<=3 false)" severity error;

        assert o_shl   = "1000" report "o_shl (1100<<1)"          severity error;
        assert o_shr   = "0110" report "o_shr (1100>>1)"          severity error;
        assert o_sshr  = "1110" report "o_sshr (signed 1100>>>1)" severity error;
        -- shift by bv(1:0) = "11" = 3 → 1100<<3 = 100000... → "0000" (4-bit truncated)
        assert o_shift = "0000" report "o_shift (1100<<3)"         severity error;

        -- D-latch: en=0 holds; flip en=1 to load a; drop en, change a, must hold.
        sEn <= '1';
        sA  <= '1';
        wait for 1 ns;
        assert o_dlatch = '1' report "o_dlatch transparent on en=1" severity error;
        sEn <= '0';
        sA  <= '0';
        wait for 1 ns;
        assert o_dlatch = '1' report "o_dlatch must hold when en=0"  severity error;

        -- Sequential block: load a=1, en=1, rst=0 across the first edge.
        sA   <= '1';
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
