-- Board top for the logic_styles tutorial on RZ EasyFPGA A2.2.
--
-- Surfaces the four interesting outputs of `logic_styles` onto the
-- four on-board LEDs so the lesson is visible by hand. The 50 MHz
-- board clock is divided down to ~1.5 Hz so the registered output
-- is visibly delayed (a 50 MHz "registered" signal looks identical
-- to a wire to the eye; a 1.5 Hz one shows the sample-and-hold
-- behaviour clearly).
--
-- LED mapping
-- -----------
-- LED0 = comb_op_and          (the reference: a AND b, combinational, instant)
-- LED1 = comb_proc_latch_and  (THE LATCH TRAP: when a=1 follows b; when a=0 HOLDS)
-- LED2 = seq_sync_reset_a     (registered: samples a on the slow clock edge;
--                              button3 = synchronous reset)
-- LED3 = latch_intentional_a  (intentional transparent latch:
--                              while button2 held -> follows button1;
--                              release button2 -> freezes)
--
-- Try this on the board to see the lessons live:
--
--   1. Hold both button1 + button2: LED0 = LED1 = LED3 = 1.
--      Release button1 only.
--      LED0 instantly goes OFF (correct combinational).
--      LED1 STAYS ON because the latch trap held the last `b`.   ← bug!
--      LED3 STAYS ON because button2 is still held -> latch transparent;
--      it'll follow button1 (now released) and turn OFF too. Try
--      releasing button2 first, then button1, to see LED3 freeze
--      while LED0 toggles.
--
--   2. Watch LED2 react slowly to button1: it samples once every
--      ~0.7 s (slow clock half-period). Press button3 to clear it
--      (synchronous reset on the next slow edge).
--
-- Buttons are active-low (idle high, pressed low); we re-invert
-- so the rest of the design reads "pressed = 1".

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity top_logic_styles_board is
    port (
        clk     : in  std_logic;          -- 50 MHz board clock (PIN_23)
        button1 : in  std_logic;          -- PIN_88, KEY1: data `a`
        button2 : in  std_logic;          -- PIN_89, KEY2: data `b` AND latch enable
        button3 : in  std_logic;          -- PIN_90, KEY3: synchronous reset for the registered LED
        leds    : out std_logic_vector(3 downto 0)
    );
end entity top_logic_styles_board;

architecture rtl of top_logic_styles_board is
    signal a, b, rst : std_logic;

    -- Slow-clock divider: 50 MHz / 2^25 ≈ 1.49 Hz. The top bit of the
    -- counter toggles every 16M cycles; we use that bit directly as
    -- the clock to `logic_styles` so the registered output samples
    -- `a` at ~1.5 Hz and the lesson is visible by eye.
    signal slow_count : unsigned(24 downto 0) := (others => '0');
    signal slow_clk   : std_logic;

    signal w_comb_op           : std_logic;
    signal w_comb_proc_good    : std_logic;
    signal w_comb_proc_latch   : std_logic;
    signal w_seq_no_init       : std_logic;
    signal w_seq_decl_init     : std_logic;
    signal w_seq_sync_reset    : std_logic;
    signal w_latch_intentional : std_logic;
begin

    a   <= not button1;
    b   <= not button2;
    rst <= not button3;

    SLOW_DIV : process (clk) is
    begin
        if rising_edge(clk) then
            slow_count <= slow_count + 1;
        end if;
    end process SLOW_DIV;
    slow_clk <= slow_count(slow_count'high);

    LOGIC_STYLES_INST : entity work.logic_styles(rtl)
        port map (
            a   => a,
            b   => b,
            clk => slow_clk,
            rst => rst,
            en  => b,

            comb_op_and          => w_comb_op,
            comb_proc_good_and   => w_comb_proc_good,
            comb_proc_latch_and  => w_comb_proc_latch,
            seq_no_init_a        => w_seq_no_init,
            seq_decl_init_a      => w_seq_decl_init,
            seq_sync_reset_a     => w_seq_sync_reset,
            latch_intentional_a  => w_latch_intentional
        );

    leds(0) <= w_comb_op;
    leds(1) <= w_comb_proc_latch;
    leds(2) <= w_seq_sync_reset;
    leds(3) <= w_latch_intentional;

end architecture rtl;
