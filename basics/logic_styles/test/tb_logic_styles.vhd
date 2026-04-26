library ieee;
use ieee.std_logic_1164.all;

entity tb_logic_styles is
end entity tb_logic_styles;

architecture testbench of tb_logic_styles is
    signal sSimulationActive : boolean   := true;
    signal sClock            : std_logic := '0';

    signal sA, sB    : std_logic := '0';
    signal sRst, sEn : std_logic := '0';

    signal comb_op_and        : std_logic;
    signal comb_proc_good_and : std_logic;
    signal comb_proc_latch    : std_logic;
    signal seq_no_init        : std_logic;
    signal seq_decl_init      : std_logic;
    signal seq_sync_reset     : std_logic;
    signal latch_intentional  : std_logic;
begin

    DUT : entity work.logic_styles(rtl)
        port map (
            a   => sA,
            b   => sB,
            clk => sClock,
            rst => sRst,
            en  => sEn,

            comb_op_and          => comb_op_and,
            comb_proc_good_and   => comb_proc_good_and,
            comb_proc_latch_and  => comb_proc_latch,
            seq_no_init_a        => seq_no_init,
            seq_decl_init_a      => seq_decl_init,
            seq_sync_reset_a     => seq_sync_reset,
            latch_intentional_a  => latch_intentional
        );

    -- 50 MHz clock; only ticks while sim is active.
    sClock <= not sClock after 10 ns when sSimulationActive;

    CHECK : process is
    begin
        ----------------------------------------------------------------
        -- Phase 1: observe register init values BEFORE any clock edge.
        --
        -- The clock starts low; the first rising edge happens at t=10
        -- ns. Take a 1 ns peek so signal/concurrent assigns settle but
        -- no clocked process has fired yet.
        ----------------------------------------------------------------
        wait for 1 ns;

        report "t=1 ns init observation: " &
               "seq_no_init=" & std_logic'image(seq_no_init) & " " &
               "seq_decl_init=" & std_logic'image(seq_decl_init) & " " &
               "seq_sync_reset=" & std_logic'image(seq_sync_reset) & " " &
               "latch_intentional=" & std_logic'image(latch_intentional) & " " &
               "comb_proc_latch=" & std_logic'image(comb_proc_latch)
               severity note;

        -- No init, no reset -> 'U' until first clock edge.
        assert seq_no_init = 'U'
            report "seq_no_init must be 'U' before the first clock edge"
            severity error;

        -- Declaration init '1' -> defined from t=0.
        assert seq_decl_init = '1'
            report "seq_decl_init must be '1' from t=0 (declaration init)"
            severity error;

        -- No init, reset path not yet exercised -> 'U'.
        assert seq_sync_reset = 'U'
            report "seq_sync_reset must be 'U' before the first reset+clock"
            severity error;

        -- The latch trap: incomplete process never assigned r_proc_latch
        -- because sA = '0' at t=0; signal stays 'U'. This visible
        -- 'U'-leak is the runtime symptom of the latch bug.
        assert comb_proc_latch = 'U'
            report "comb_proc_latch should be 'U' when sA='0' at startup -- this IS the bug"
            severity warning;

        -- Combinational good cases: defined as soon as inputs are defined.
        assert comb_op_and        = (sA and sB)
            report "comb_op_and reference mismatch at startup"     severity error;
        assert comb_proc_good_and = (sA and sB)
            report "comb_proc_good_and reference mismatch at startup" severity error;

        ----------------------------------------------------------------
        -- Phase 2: combinational sweep of (a, b).
        --
        -- For every input combination the two GOOD combinational
        -- variants must agree with the reference. The "trap" variant
        -- is allowed to lag/hold -- that's the bug's behaviour.
        ----------------------------------------------------------------
        for ab in 0 to 3 loop
            if ab >= 2 then sA <= '1'; else sA <= '0'; end if;
            if (ab mod 2) = 1 then sB <= '1'; else sB <= '0'; end if;
            wait for 1 ns;

            assert comb_op_and        = (sA and sB)
                report "comb_op_and mismatch"        severity error;
            assert comb_proc_good_and = (sA and sB)
                report "comb_proc_good_and mismatch" severity error;
        end loop;

        ----------------------------------------------------------------
        -- Phase 3: clock the registers with reset asserted.
        --
        -- After one rising edge with rst='1', `seq_sync_reset` must
        -- be '1'. The other two follow `sA` (which is '1' here).
        ----------------------------------------------------------------
        sA   <= '1';
        sRst <= '1';
        wait until rising_edge(sClock);
        wait for 1 ns;

        assert seq_sync_reset = '1'
            report "seq_sync_reset must be '1' after first edge with rst='1'"
            severity error;
        assert seq_no_init = '1'
            report "seq_no_init must follow sA after first edge"
            severity error;
        assert seq_decl_init = '1'
            report "seq_decl_init must follow sA after first edge"
            severity error;

        ----------------------------------------------------------------
        -- Phase 4: release reset, change `a`, clock again. All three
        -- registers should now follow `a`.
        ----------------------------------------------------------------
        sRst <= '0';
        sA   <= '0';
        wait until rising_edge(sClock);
        wait for 1 ns;

        assert seq_no_init     = '0' report "seq_no_init must follow sA"     severity error;
        assert seq_decl_init   = '0' report "seq_decl_init must follow sA"   severity error;
        assert seq_sync_reset  = '0' report "seq_sync_reset must follow sA"  severity error;

        ----------------------------------------------------------------
        -- Phase 5: intentional latch behaviour.
        --
        -- en='1' makes the latch transparent (output = a). Releasing
        -- en holds the last value even if a changes.
        ----------------------------------------------------------------
        sEn <= '1';
        sA  <= '1';
        wait for 5 ns;
        assert latch_intentional = '1'
            report "intentional latch must be transparent when en='1'"
            severity error;

        sEn <= '0';                    -- close latch
        wait for 5 ns;
        sA  <= '0';                    -- changing a must NOT change output
        wait for 5 ns;
        assert latch_intentional = '1'
            report "intentional latch must HOLD '1' after en falls"
            severity error;

        sEn <= '1';                    -- reopen
        wait for 5 ns;
        assert latch_intentional = '0'
            report "intentional latch must be transparent again when en='1'"
            severity error;

        report "Simulation done!" severity note;
        sSimulationActive <= false;
        wait;
    end process CHECK;

end architecture testbench;
