library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity blink_led is
	Port (clk : in STD_LOGIC;
	      button1 : in STD_LOGIC;
			led : out STD_LOGIC;
			led2 : out STD_LOGIC);
end blink_led;

architecture Behavioral of blink_led is
	signal pulse : std_LOGIC := '0';
	signal count : integer range 0 to 50000000 := 0;
begin

	
	counter : process(clk)
	begin
		if clk'event and clk = '1' then
			if count = 49999999 then
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
