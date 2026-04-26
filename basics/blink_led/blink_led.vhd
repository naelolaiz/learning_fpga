-- Precise-period blinking LED.
--
-- A counter wraps at exactly `CLOCKS_TO_OVERFLOW` cycles; on each
-- wrap a 1-bit `pulse` register toggles, and `led` follows `pulse`.
-- That gives an arbitrary period (`led` flips every CLOCKS_TO_OVERFLOW
-- cycles, so the full on/off period is `2 * CLOCKS_TO_OVERFLOW / f_clk`).
--
-- Cost: TWO flip-flops -- the counter AND the toggling `pulse`
-- register -- plus a comparator and a mux. The synthesised diagram
-- (`build/blink_led.svg`) shows both registers.
--
-- For a strictly simpler version that uses ONE flip-flop (the LED
-- is just the counter's top bit) at the cost of fixing the period
-- to a power of two, see the sibling `blink_led_minimal.vhd`.

library ieee;
use ieee.std_logic_1164.all;

entity blink_led is
   generic (CLOCKS_TO_OVERFLOW : integer := 50E6);
   port (clk : in  std_logic;
         led : out std_logic);
end blink_led;

architecture Behavioral of blink_led is
   signal pulse : std_logic := '0';
   signal count : integer range 0 to CLOCKS_TO_OVERFLOW := 0;
begin

   counter : process (clk)
   begin
      if rising_edge(clk) then
         if count = CLOCKS_TO_OVERFLOW - 1 then
            count <= 0;
            pulse <= not pulse;
         else
            count <= count + 1;
         end if;
      end if;
   end process;

   led <= pulse;

end Behavioral;
