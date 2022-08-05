library ieee;
use ieee.std_logic_1164.all;

entity Serial2Parallel is
  generic (NUMBER_OF_BITS : integer := 16);
  port    (inClock  : in std_logic;
           inData   : in std_logic;
           inPrint  : in std_logic;
           outData  : out std_logic_vector (NUMBER_OF_BITS-1 downto 0));
end Serial2Parallel;


architecture logic of Serial2Parallel is
  signal cachedData : std_logic_vector (NUMBER_OF_BITS-1 downto 0) := (others => '0');
begin

   process(inClock, inData, inPrint, cachedData)
   begin
     if inPrint = '1' then
       outData <= cachedData;
     elsif rising_edge(inClock) then -- shift left and concatenate with inData
       cachedData <= cachedData(NUMBER_OF_BITS-2 downto 0) & inData;
     end if;

   end process;
end logic;
