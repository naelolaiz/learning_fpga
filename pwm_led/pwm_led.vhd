-- pwm_led.vhd
--
-- Pulse-width-modulated LED driver. The 8-bit `duty` input picks the
-- on-fraction of every 256-tick window, so the perceived brightness of
-- the LED tracks `duty` linearly (0 = off, 255 = full bright).
--
-- Comes in handy as the building block for any analog-feel output (LED
-- dimming, motor speed, simple DACs).

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity pwm_led is
  generic (
    -- Width of the duty input. The PWM period is 2**WIDTH cycles of clk.
    WIDTH : integer := 8
  );
  port (
    clk     : in  std_logic;
    duty    : in  std_logic_vector(WIDTH-1 downto 0);
    pwm_out : out std_logic
  );
end entity pwm_led;

architecture rtl of pwm_led is
  signal counter : unsigned(WIDTH-1 downto 0) := (others => '0');
begin

  process (clk)
  begin
    if rising_edge(clk) then
      counter <= counter + 1;
    end if;
  end process;

  -- Output is high while the counter is below the requested duty.
  pwm_out <= '1' when counter < unsigned(duty) else '0';

end architecture rtl;
