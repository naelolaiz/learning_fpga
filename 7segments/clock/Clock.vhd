
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
signal carryBitSecondsUnit, carryBitSecondsTens, carryBitMinutesUnit, carryBitMinutesTens, carryBitHoursUnit: std_logic := '0';
signal decimalCounterHours: std_logic_vector(4 downto 0) := std_logic_vector(to_unsigned(0,5));
begin
 -- digit instances ...               
   digitSecsUnit : entity work.Digit(behaviorDigit)
    generic map (MAX_NUMBER => 9)
    port map (
      clock => clock,
      direction => direction,
      currentNumber => bcdDigits(3 downto 0),
      carryBit => carryBitSecondsUnit,
      reset => reset);

      digitSecsTens : entity work.Digit(behaviorDigit)
    generic map (MAX_NUMBER => 5)
    port map (
      clock => carryBitSecondsUnit,
      direction => direction,
      currentNumber => bcdDigits(7 downto 4),
      carryBit => carryBitSecondsTens,
      reset => reset); 
      
   digitMinsUnit : entity work.Digit(behaviorDigit)
    generic map (MAX_NUMBER => 9)
    port map (
      clock => carryBitSecondsTens,
      direction => direction,
      currentNumber => bcdDigits(11 downto 8),
      carryBit => carryBitMinutesUnit,
      reset => reset); 
      
   digitMinsTens : entity work.Digit(behaviorDigit)
    generic map (MAX_NUMBER => 5)
    port map (
      clock => carryBitMinutesUnit,
      direction => direction,
      currentNumber => bcdDigits(15 downto 12),
      carryBit => carryBitMinutesTens,
      reset => reset); 
   ------------------------------------------------------------------
   -- counter for for multiplexer (4 digits, one increment every 2ms)                
   digitsHours : entity work.Counter(behaviorCounterForDigit)
    generic map (MAX_NUMBER_FOR_COUNTER => 23)
    port map ( clock => carryBitMinutesTens,
               direction => direction,
	       counter(4 downto 0) => decimalCounterHours,
	       reset => reset);
   bcdDigits(19 downto 16) <= std_logic_vector(to_unsigned(to_integer(unsigned(decimalCounterHours)) mod 10, 4));
   bcdDigits(23 downto 20) <= std_logic_vector(to_unsigned(to_integer(unsigned(decimalCounterHours)) / 10, 4));

end behaviorClock;
