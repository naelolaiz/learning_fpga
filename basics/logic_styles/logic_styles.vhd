-- A tutorial of the *coding styles* a synthesizer infers logic from.
-- The companion project `basics/glossary` is the gallery of basic
-- gate primitives (one cell per gate); this project is about the
-- *how-it-got-there* layer that sits above those cells.
--
-- Three families of logic that a synthesizer infers from HDL:
--
--   * COMBINATIONAL — output is a pure function of current inputs;
--                     no memory.   Implemented as gates / LUTs.
--   * SEQUENTIAL    — output remembers state across clock edges;
--                     transitions only at edges. Implemented as
--                     edge-triggered registers (flip-flops).
--   * LATCH         — output is transparent while a level-sensitive
--                     `enable` is asserted, and HOLDS its last value
--                     when `enable` is deasserted. Implemented as
--                     level-sensitive latches.
--
-- And inside the SEQUENTIAL family, three different ways to get the
-- register to a known value at start-up:
--
--   * NO INIT, NO RESET     — bitstream / power-up state decides;
--                             portable behaviour: undefined.
--   * DECLARATION INIT      — `signal r : std_logic := '1';`
--                             Cyclone IV honours this via the FF's
--                             power-up value baked into the bitstream;
--                             not portable to FPGAs whose flip-flops
--                             can't be loaded with arbitrary boot
--                             values, and never portable to ASIC.
--   * EXPLICIT (SYNC) RESET — `if rst = '1' then r <= ...; elsif ...`
--                             portable; works on every target.
--
-- Output naming pattern:
--
--     name pattern              what synthesizes
--     ------------              -----------------
--     comb_op_*                 combinational, operator/concurrent style
--     comb_proc_good_*          combinational, process style, FULL coverage  ✓
--     comb_proc_latch_*         combinational, process style, INCOMPLETE     ✗ (oops, latch)
--     seq_no_init_*             register, no init, no reset                  ('U' before first edge)
--     seq_decl_init_*           register, := '1' in declaration              (Cyclone IV honours)
--     seq_sync_reset_*          register, explicit synchronous reset         (portable)
--     latch_intentional_*       level-sensitive transparent latch            (rare; specialised)
--
-- WHEN TO USE WHICH
--
--   - Pure function of inputs (gates, mux, decoder, comparator,
--     arithmetic): COMBINATIONAL. Use operator style, or a process
--     that drives every output on every code path. Both `comb_op_*`
--     and `comb_proc_good_*` are equivalent for the synthesizer.
--
--   - Anything that must remember a value (counter, debouncer,
--     pipeline stage, FSM state, registered I/O): SEQUENTIAL. Pick a
--     reset strategy:
--       · For one-off "this signal can come up at anything" wiring on
--         Cyclone IV, the declaration-init shortcut works because the
--         bitstream loads each FF's power-up value — many examples in
--         this repo use it.
--       · For anything that can be re-armed at runtime (FSMs, counters
--         that the user can clear), use an explicit reset. Cleaner
--         intent, portable, supports re-init after power-up.
--
--   - A LATCH is a separate cell from a register: no clock, only an
--     enable, *transparent* while enable is high. In FPGA flip-flop
--     fabric you almost never want this — registers are cheaper,
--     faster, and avoid timing-analysis headaches.
--
-- WHEN NOT TO
--
--   - Don't write a combinational process (`process(a, b)` /
--     `always @(*)`) without assigning every output on every code
--     path. The synthesizer infers a latch (see `comb_proc_latch_*`)
--     and Quartus warns "inferring latch(es)". Treat that warning as
--     an error in your own code.
--
--   - Don't rely on `signal r : std_logic := '...'` to bring a register
--     up to a known value if you also want it to be re-initializable
--     at runtime — it only fires once, at power-up. Use an explicit
--     reset for runtime re-arming.
--
--   - Don't rely on declaration-init (`:= '1'`) for anything outside
--     the FPGA target you're building for. ASIC flows ignore it
--     entirely; some FPGA flows partially.
--
-- The render in `build/logic_styles.svg` shows what each construct
-- maps to: gates for the combinational good cases, a `$DLATCH` cell
-- for both the trap and the intentional latch (so the lesson is
-- visible in the netlist, not just in the source), a `$DFF` for each
-- register variant, with `EN`/`SR` pins on the variants that have them.

library ieee;
use ieee.std_logic_1164.all;

entity logic_styles is
    port (
        a   : in  std_logic;
        b   : in  std_logic;
        clk : in  std_logic;
        rst : in  std_logic;  -- active-high synchronous reset for `seq_sync_reset_a`
        en  : in  std_logic;  -- transparent-latch enable for `latch_intentional_a`

        -- COMBINATIONAL: two equivalent good forms.
        comb_op_and        : out std_logic;
        comb_proc_good_and : out std_logic;

        -- COMBINATIONAL, done WRONG: incomplete process => synthesizer
        -- infers a latch even though the author probably meant
        -- "a AND b". Do not write your combinational logic this way.
        comb_proc_latch_and : out std_logic;

        -- SEQUENTIAL: three init strategies side-by-side.
        seq_no_init_a       : out std_logic;
        seq_decl_init_a     : out std_logic;
        seq_sync_reset_a    : out std_logic;

        -- LATCH (intentional, level-sensitive).
        latch_intentional_a : out std_logic
    );
end entity logic_styles;

architecture rtl of logic_styles is
    signal r_proc_good     : std_logic;
    signal r_proc_latch    : std_logic;
    signal r_no_init       : std_logic;          -- no init, no reset
    signal r_decl_init     : std_logic := '1';   -- declaration init
    signal r_sync_reset    : std_logic;          -- driven by reset path
    signal r_latch         : std_logic;
begin

    -- --------------- COMBINATIONAL (operator) -----------------------
    -- Concurrent assignment. Synthesizer sees a pure expression and
    -- produces an AND gate. Simplest, clearest style for any function
    -- of the inputs.
    comb_op_and <= a and b;

    -- --------------- COMBINATIONAL (process, GOOD) ------------------
    -- A process can also describe combinational logic, as long as
    --   (1) the sensitivity list lists every signal the body reads, and
    --   (2) every code path assigns every output.
    -- Both branches drive `r_proc_good`, so the synthesizer produces a
    -- plain AND gate identical to `comb_op_and`.
    COMB_GOOD : process (a, b) is
    begin
        if a = '1' and b = '1' then
            r_proc_good <= '1';
        else
            r_proc_good <= '0';
        end if;
    end process COMB_GOOD;
    comb_proc_good_and <= r_proc_good;

    -- --------------- COMBINATIONAL (process, BAD: LATCH) ------------
    -- CLASSIC FPGA TRAP. The `if` has no `else`: when `a = '0'`
    -- `r_proc_latch` is not assigned at all, so the synthesizer
    -- concludes "must remember the previous value" and instantiates
    -- a level-sensitive latch.
    COMB_BAD : process (a, b) is
    begin
        if a = '1' then
            r_proc_latch <= b;
        end if;
    end process COMB_BAD;
    comb_proc_latch_and <= r_proc_latch;

    -- --------------- SEQUENTIAL: no init, no reset ------------------
    -- The signal has no `:= '...'` initializer and the process has
    -- no reset branch. In simulation the output stays 'U' (uninit)
    -- until the first rising edge of clk samples a defined `a` into
    -- it. On Cyclone IV the bitstream loads each FF to '0' at
    -- power-up by default — which means hardware behaves better than
    -- simulation here, hiding the bug. Don't rely on it.
    SEQ_NO_INIT : process (clk) is
    begin
        if rising_edge(clk) then
            r_no_init <= a;
        end if;
    end process SEQ_NO_INIT;
    seq_no_init_a <= r_no_init;

    -- --------------- SEQUENTIAL: declaration init -------------------
    -- The declaration `signal r_decl_init : std_logic := '1';` above
    -- gives the simulator a known starting value AND, on Cyclone IV,
    -- bakes that value into the FF's power-up state in the bitstream.
    -- Convenient for one-shot init; not portable across FPGA families
    -- and never portable to ASIC. Many examples in this repo use this
    -- shortcut for things like a 4-bit counter or a single-shot pulse.
    SEQ_DECL_INIT : process (clk) is
    begin
        if rising_edge(clk) then
            r_decl_init <= a;
        end if;
    end process SEQ_DECL_INIT;
    seq_decl_init_a <= r_decl_init;

    -- --------------- SEQUENTIAL: explicit synchronous reset ---------
    -- An explicit reset path: while `rst = '1'` the register is
    -- forced to '1' on each rising edge; otherwise it samples `a`.
    -- Portable across every FPGA and ASIC target, and re-armable at
    -- runtime. Use this whenever the consumer needs to be able to
    -- clear the register on demand (counters, FSMs, FIFOs).
    SEQ_RESET : process (clk) is
    begin
        if rising_edge(clk) then
            if rst = '1' then
                r_sync_reset <= '1';
            else
                r_sync_reset <= a;
            end if;
        end if;
    end process SEQ_RESET;
    seq_sync_reset_a <= r_sync_reset;

    -- --------------- LATCH (intentional, level-sensitive) ----------
    -- Explicit transparent latch: while `en = '1'` the output follows
    -- `a`, when `en = '0'` it holds the last value. Rare in FPGA
    -- fabric (registers are cheaper and easier to time); shown here
    -- side-by-side with the accidental latch above so the netlist
    -- contrast is clear.
    LATCH : process (en, a) is
    begin
        if en = '1' then
            r_latch <= a;
        end if;
    end process LATCH;
    latch_intentional_a <= r_latch;

end architecture rtl;
