library ieee;

use ieee.std_logic_1164.ALL;
use ieee.numeric_std.ALL;

entity tb_blink_led is
end tb_blink_led;

architecture testbench of tb_blink_led is
   signal sSimulationActive : boolean   := true;
   signal sClock50MHz       : std_logic := '0';
   signal sButton           : std_logic := '1'; -- active low, default (not pressed) high
   signal sLed1, sLed2      : std_logic := '0';

begin

   DUT : entity work.blink_led(Behavioral)
   generic map( CLOCKS_TO_OVERFLOW => 10 ) -- 10 * 20 ns = 200 ns
   port map (
         clk     => sClock50MHz,
         button1 => sButton,
         led     => sLed1,
         led2    => sLed2);

   -- generate clock 
   sClock50MHz <= not sClock50MHz after 10 ns when sSimulationActive;

   -- generate button pressed
   PRESS_BUTTONS : process
   begin
     sButton <= '1';
     wait for 50 ns;
     sButton <= '0';
     wait for 40 ns;
     sButton <= '1';
     wait for 150 ns; -- 50+40+150=240ns, already in other half of the cycle
     sButton <= '0';
     wait for 50 ns;
     sButton <= '1';
     wait;
   end process;

   -- check the outputs
   EXPECTED_OUTPUTS_CHECKS : process
   begin
      wait until rising_edge(sClock50MHz);
      assert(sLed1 = '0' and sLed2 = '0') 
         report "Wrong output signals at start" severity error;
      wait until sButton = '0';
      wait until rising_edge(sClock50MHz);
      assert(sLed1 = '0' and sLed2 = '1')
         report "Wrong output signals after button pressed the first time" severity error;
      -- this happened at 90ns. We wait until being in the second half of the cycle but before the button is pressed
      wait for 130 ns;
      assert(sLed1 ='1' and sLed2 = '1') -- not inverted
         report "Wrong output signals on second cycle, button not pressed" severity error;
      wait until sButton = '0';
      wait until rising_edge(sClock50MHz);
      assert(sLed1 = '1' and sLed2 = '0')
         report "Wrong output signals on second cycle, button pressed" severity error;
      wait until sButton = '1';
      wait until rising_edge(sClock50MHz);
      assert(sLed1 = '1' and sLed2 = '1')
         report "Wrong output signals on second cycle, button released" severity error;
      report "Simulation done!" severity note;
      sSimulationActive <= false;

   end process;

end testbench;
