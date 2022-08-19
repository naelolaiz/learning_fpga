library ieee;
use ieee.std_logic_1164.all;


entity tb_simulator_writer is
end tb_simulator_writer;

architecture tb of tb_simulator_writer is
   signal clock    : std_logic := '0';
   signal outLines : std_logic_vector (4 downto 0) := (others => '0');
   signal done : boolean := false;
begin

 myWriter : entity work.tl_simulator_writer(logic)
 port map ( inClock  => clock,
            outLines => outLines,
            done => done);

 clock <= not clock after 10 ns when not done;

end tb;
