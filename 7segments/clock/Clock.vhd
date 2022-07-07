
-- Clock. Encapsulating 4 7 segments digits in cascade.
LIBRARY ieee;

USE ieee.std_logic_1164.ALL;
use ieee.numeric_std.ALL;


entity Clock is
   port (
         clock: in std_logic;
	 direction: in std_logic;
         reset: in std_logic := '1';
         bcdDigits: out std_logic_vector (23 downto 0) := std_logic_vector(to_unsigned(0,24)));
end Clock;

architecture behaviorClock of Clock is
constant SECONDS_PER_DAY : std_logic_vector (16 downto 0) := std_logic_vector(to_unsigned(86400,17));
signal decimalCounterSeconds: std_logic_vector(16 downto 0) := std_logic_vector(to_unsigned(0,17)); 
signal decimalHours: integer range 0 to 23 := 0;
signal decimalMinutes: integer range 0 to 59 := 0;
signal decimalSeconds: integer range 0 to 59 := 0;

begin
   daySecondsCounter : entity work.Counter(behaviorCounterForDigit)
    generic map (MAX_NUMBER_FOR_COUNTER => std_logic_vector(to_unsigned(0,47)) & SECONDS_PER_DAY)
    port map ( clock => clock,
               direction => direction,
               counter(16 downto 0) => decimalCounterSeconds,
               reset => reset);
   -- get hours, minutes and seconds in decimal
   decimalHours <= to_integer(unsigned(decimalCounterSeconds)) / 3600;
   decimalMinutes <= (to_integer(unsigned(decimalCounterSeconds)) mod 3600) / 60;
   decimalSeconds <= (to_integer(unsigned(decimalCounterSeconds)) mod 3600) mod 60;
   -- decimal to bcd
   bcdDigits(3 downto 0) <=   std_logic_vector(to_unsigned(decimalSeconds mod 10, 4)); -- seconds unit
   bcdDigits(7 downto 4) <=   std_logic_vector(to_unsigned(decimalSeconds / 10, 4));   -- seconds tens
   bcdDigits(11 downto 8) <=  std_logic_vector(to_unsigned(decimalMinutes mod 10, 4)); -- minutes unit
   bcdDigits(15 downto 12) <= std_logic_vector(to_unsigned(decimalMinutes / 10, 4));   -- minutes tens
   bcdDigits(19 downto 16) <= std_logic_vector(to_unsigned(decimalHours mod 10, 4));   -- hour unit digits
   bcdDigits(23 downto 20) <= std_logic_vector(to_unsigned(decimalHours / 10, 4));     -- hour tens
end behaviorClock;
