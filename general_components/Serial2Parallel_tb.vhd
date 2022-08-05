library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity Serial2Parallel_tb is
end Serial2Parallel_tb;

architecture tb of Serial2Parallel_tb is
  constant NUMBER_OF_BITS : integer := 16;
  signal sCounter : std_logic_vector (NUMBER_OF_BITS-1 downto 0);
  signal sClock : std_logic := '0';
  signal sData : std_logic := '0';
  signal sPrint : std_logic := '0';
  signal sOutData : std_logic_vector (NUMBER_OF_BITS-1 downto 0);


begin

 tbInstance : entity work.Serial2Parallel(logic)
 generic map (NUMBER_OF_BITS => NUMBER_OF_BITS)
 port map(inClock => sClock,
          inData  => sData,
          inPrint => sPrint,
          outData => sOutData);

process
begin
  for i in 0 to ((2** NUMBER_OF_BITS) - 1) loop
     sClock <= '0';
     sPrint <= '0';
     sCounter <= std_logic_vector(to_unsigned(i,NUMBER_OF_BITS));
     wait for 1 ns;
     sClock <= '1';
     wait for 1 ns;
     for b in NUMBER_OF_BITS-1 downto 0 loop
        sClock <= '0';
        sData <= sCounter(b);
        wait for 1 ns;
        sClock <= '1';
        wait for 1 ns;
     end loop;
     sClock <= '0';
     wait for 1 ns;
     sPrint <= '1';
     sClock <= '1';
     wait for 1 ns;
     sData <= '0';
     sClock <= '0';
     wait for 1 ns;
     sClock <= '1';
     wait for 1 ns;
     assert ( sCounter = sOutData )
     report "Error" severity error;
  end loop;
  wait; -- finish simulation
end process;

end tb;
