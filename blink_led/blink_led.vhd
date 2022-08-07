library ieee;
use ieee.std_logic_1164.all;

entity blink_led is
   generic (CLOCKS_TO_OVERFLOW : integer := 50E6);
   port (clk     : in std_logic;
         button1 : in std_logic;
         led     : out std_logic;
         led2    : out std_logic);
end blink_led;

architecture Behavioral of blink_led is
   signal pulse : std_LOGIC := '0';
   signal count : integer range 0 to CLOCKS_TO_OVERFLOW := 0;
begin

   
   counter : process(clk)
   begin
      if clk'event and clk = '1' then
         if count = CLOCKS_TO_OVERFLOW-1 then
            count <= 0;
            pulse <= not pulse;
         else
            count <= count + 1;
         end if;
      end if;
   
   end process;
   
   led <= pulse;
   led2 <= pulse xnor button1;
   
end Behavioral;
