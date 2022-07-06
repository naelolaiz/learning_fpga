
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
 
   digitHoursUnit : entity work.Digit(behaviorDigit)
    generic map (MAX_NUMBER => 3)
    port map (
      clock => carryBitMinutesTens,
      direction => direction,
      currentNumber => bcdDigits(19 downto 16),
      carryBit => carryBitHoursUnit,
      reset => reset); 
      
   digitHoursTens : entity work.Digit(behaviorDigit)
    generic map (MAX_NUMBER => 2)
    port map (
      clock => carryBitHoursUnit,
      direction => direction,
      currentNumber => bcdDigits(23 downto 20),
      reset => reset);
      

end behaviorClock;
