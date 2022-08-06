library ieee;

use ieee.std_logic_1164.ALL;
use ieee.numeric_std.ALL;

entity tb_test is
end tb_test;

architecture testbench of tb_test is
   signal sClock50MHz : std_logic;
   signal sSevenSegments : std_logic_vector (6 downto 0);
   signal sCableSelect : std_logic_vector(3 downto 0);
   signal sSimulationActive : boolean := true;
begin

   DUT : entity work.test(behavior)
   port map (
         clock => sClock50MHz,
         sevenSegments => sSevenSegments,
         cableSelect   => sCableSelect);
   -- generate clock 
   sClock50MHz <= not sClock50MHz after 20 ns when sSimulationActive;

   TEST_TERMINATOR : process
   begin
     sSimulationActive <= true;
     wait for 100 ms;
     sSimulationActive <= false;
   end process;

end testbench;
