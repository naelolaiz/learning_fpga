LIBRARY ieee;

USE ieee.std_logic_1164.ALL;

entity test is
   port (
	      inputButtons : in std_logic_vector(3 downto 0);
         sevenSegments : out std_logic_vector(6 downto 0);
         cableSelectDigit0 : out std_logic;
         cableSelectDigit1 : out std_logic;
         cableSelectDigit2 : out std_logic;
         cableSelectDigit3 : out std_logic);
end test;

architecture behavior of test is
begin
   cableSelectDigit0 <= '0';
   cableSelectDigit1 <= '0';
   cableSelectDigit2 <= '0';
   cableSelectDigit3 <= '0';
   sevenSegments <= "1000000" when inputButtons=not "0000" else
        "1111001" when inputButtons=not "0001" else
        "0100100" when inputButtons=not "0010" else
        "0110000" when inputButtons=not "0011" else
        "0011001" when inputButtons=not "0100" else
        "0010010" when inputButtons=not "0101" else
        "0000010" when inputButtons=not "0110" else
        "1111000" when inputButtons=not "0111" else
        "0000000" when inputButtons=not "1000" else
        "0010000" when inputButtons=not "1001" else
        "0001000" when inputButtons=not "1010" else
        "0000011" when inputButtons=not "1011" else
        "1000110" when inputButtons=not "1100" else
        "0100001" when inputButtons=not "1101" else
        "0000110" when inputButtons=not "1110" else
        "0001110" ;

end behavior;
