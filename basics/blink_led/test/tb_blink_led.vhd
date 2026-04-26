library ieee;

use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity tb_blink_led is
end tb_blink_led;

architecture testbench of tb_blink_led is
   signal sSimulationActive : boolean   := true;
   signal sClock50MHz       : std_logic := '0';
   signal sLed              : std_logic;

begin

   DUT : entity work.blink_led(Behavioral)
      generic map (CLOCKS_TO_OVERFLOW => 10)  -- 10 * 20 ns = 200 ns toggle
      port map (
         clk => sClock50MHz,
         led => sLed);

   -- 50 MHz: 20 ns period.
   sClock50MHz <= not sClock50MHz after 10 ns when sSimulationActive;

   CHECK : process is
   begin
      -- After one full counter window (200 ns) the led toggles.
      wait for 1 ns;
      assert sLed = '0' report "led must start at 0" severity error;

      wait for 200 ns;
      assert sLed = '1' report "led must be 1 after first 200 ns window" severity error;

      wait for 200 ns;
      assert sLed = '0' report "led must be back to 0 after second window" severity error;

      report "Simulation done!" severity note;
      sSimulationActive <= false;
      wait;
   end process;

end testbench;
