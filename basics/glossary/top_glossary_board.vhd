-- Board top for the glossary project on RZ EasyFPGA A2.2.
--
-- Two on-board buttons (KEY1=PIN_88, KEY2=PIN_89) are the *shared*
-- combinational inputs `a` and `b` for every gate. Four on-board
-- LEDs (PIN_84..PIN_87) display:
--
--   LED0 = a AND b
--   LED1 = a OR  b
--   LED2 = a XOR b
--   LED3 = a XNOR b
--
-- Press button combinations and read the corresponding row of each
-- gate's truth table off the LEDs in real time. The remaining
-- glossary outputs (NOT / NAND / NOR / reductions / muxes /
-- arithmetic / sequential variants) live in the same `glossary`
-- entity and are visible in the netlist diagram (`build/glossary.svg`)
-- but the board's 4-LED budget forces a pick.
--
-- For the *coding-style* lesson layered above the gate primitives —
-- combinational vs. sequential vs. latch, register init strategies,
-- the classic "incomplete process infers a latch" trap — see the
-- sibling project [`basics/logic_styles`](../logic_styles).
--
-- Buttons are active-low on this board (idle = '1', pressed = '0').
-- We invert so the rest of the design reads "pressed = 1".

library ieee;
use ieee.std_logic_1164.all;

entity top_glossary_board is
    port (
        clk     : in  std_logic;
        button1 : in  std_logic;  -- active-low; PIN_88 / KEY1
        button2 : in  std_logic;  -- active-low; PIN_89 / KEY2
        leds    : out std_logic_vector(3 downto 0)
    );
end entity top_glossary_board;

architecture rtl of top_glossary_board is
    signal a, b : std_logic;
    signal w_and, w_or, w_xor, w_xnor : std_logic;
begin

    a <= not button1;
    b <= not button2;

    GLOSSARY_INST : entity work.glossary(rtl)
        port map (
            a       => a,
            b       => b,
            sel     => '0',
            sel4    => "00",
            sel4_oh => "0000",
            av      => (others => '0'),
            bv      => (others => '0'),
            clk     => clk,
            rst     => '1',
            en      => '0',

            o_and  => w_and,
            o_or   => w_or,
            o_not  => open,
            o_xor  => w_xor,
            o_nand => open,
            o_nor  => open,
            o_xnor => w_xnor,

            o_reduce_or   => open,
            o_reduce_and  => open,
            o_reduce_xor  => open,
            o_reduce_bool => open,

            o_logic_not => open,
            o_logic_and => open,
            o_logic_or  => open,

            o_mux2 => open,
            o_mux4 => open,
            o_pmux => open,

            o_add => open,
            o_sub => open,
            o_mul => open,
            o_neg => open,
            o_pos => open,

            o_eq  => open,
            o_ne  => open,
            o_lt  => open,
            o_gt  => open,
            o_ge  => open,
            o_le  => open,

            o_shl   => open,
            o_shr   => open,
            o_sshr  => open,
            o_shift => open,

            o_dff     => open,
            o_dffe    => open,
            o_dffr    => open,
            o_dlatch  => open,
            o_counter => open,

            o_mem => open
        );

    leds(0) <= w_and;
    leds(1) <= w_or;
    leds(2) <= w_xor;
    leds(3) <= w_xnor;

end architecture rtl;
