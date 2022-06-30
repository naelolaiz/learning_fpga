LIBRARY ieee;

USE ieee.std_logic_1164.ALL;

entity test is
   port (D : in std_logic_vector(3 downto 0);
         S : out std_logic_vector(6 downto 0);
         cs_0 : out std_logic;
         cs_1 : out std_logic;
         cs_2 : out std_logic;
         cs_3 : out std_logic);
end test;

architecture behavior of test is
begin
   cs_0 <= '0';
   cs_1 <= '0';
   cs_2 <= '0';
   cs_3 <= '0';
   S <= "1000000" when D=not "0000" else
        "1111001" when D=not "0001" else
        "0100100" when D=not "0010" else
        "0110000" when D=not "0011" else
        "0011001" when D=not "0100" else
        "0010010" when D=not "0101" else
        "0000010" when D=not "0110" else
        "1111000" when D=not "0111" else
        "0000000" when D=not "1000" else
        "0010000" when D=not "1001" else
        "0001000" when D=not "1010" else
        "0000011" when D=not "1011" else
        "1000110" when D=not "1100" else
        "0100001" when D=not "1101" else
        "0000110" when D=not "1110" else
        "0001110" ;

end behavior;
