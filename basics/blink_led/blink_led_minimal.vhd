-- The "absolute minimum" blinking-LED.
--
-- One register (the counter), one adder, one wire. The LED is
-- driven directly from the counter's most-significant bit, which
-- toggles every 2^(WIDTH-1) clock cycles -- so for a 50 MHz clock
-- and WIDTH = 25 the LED flips at ~1.5 Hz (period ~1.34 s).
--
-- Compare with the sibling `blink_led.vhd`:
--
--   * `blink_led` has TWO flip-flops -- a counter AND a separate
--     1-bit `pulse` register that toggles each time the counter
--     wraps. That extra register exists to support an *exactly*
--     tunable period via the `CLOCKS_TO_OVERFLOW` generic. Cost:
--     one more register, a comparator and a mux.
--
--   * `blink_led_minimal` (this file) drops the `pulse` register
--     entirely and uses the counter top bit as the LED output.
--     Period is fixed at 2^WIDTH / f_clk -- a power of two, not
--     arbitrary. The synthesised diagram (`build/blink_led_minimal.svg`)
--     therefore shows ONE register cell instead of two.
--
-- Use this whenever an exact blink rate isn't required (which, for
-- a "hello world" sanity check, is essentially always). For a
-- precise period, prefer `blink_led`.

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity blink_led_minimal is
    generic (
        -- Counter width. Period of the LED's full on/off cycle is
        -- 2^WIDTH cycles of `clk` (the MSB toggles every 2^(WIDTH-1)).
        -- 25 -> ~1.5 Hz @ 50 MHz; 4 -> the testbench's small value.
        WIDTH : integer := 25
    );
    port (
        clk : in  std_logic;
        led : out std_logic
    );
end entity blink_led_minimal;

architecture rtl of blink_led_minimal is
    signal counter : unsigned(WIDTH-1 downto 0) := (others => '0');
begin

    process (clk) is
    begin
        if rising_edge(clk) then
            counter <= counter + 1;
        end if;
    end process;

    -- Top bit of the free-running counter is the LED. No separate
    -- `pulse` flip-flop, no overflow comparator -- compare with
    -- `blink_led.vhd` to see what each line costs in cells.
    led <= counter(WIDTH-1);

end architecture rtl;
