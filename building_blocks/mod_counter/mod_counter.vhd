-- mod_counter
--
-- Up/down modulo-N counter with carry-out. The internal state walks
-- 0 → 1 → … → MAX_NUMBER → 0 (forward) or 0 → MAX_NUMBER → … → 1
-- → 0 (backward), and `carryBit` pulses high for one cycle on
-- every wrap.
--
-- The output width is fixed at 4 bits, which makes this a drop-in
-- single BCD-digit counter when used with `MAX_NUMBER = 9` (most
-- common case in the clock display). Other moduli up to 15 fit the
-- same width — e.g. `MAX_NUMBER = 11` for a 12-hour cascade.
--
-- Originally lived as the `Digit` entity in `7segmentsDigit.vhd`
-- inside the 7-segments clock project. The logic was always a pure
-- mod-N counter; only the filename suggested it was 7-segment
-- specific. Lifted out here so other projects can share it.

LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
use ieee.numeric_std.ALL;

entity mod_counter is
   generic (MAX_NUMBER : integer range 0 to 15 := 9);
   port (clock         : in  std_logic := '0';
         reset         : in  std_logic := '0';
         direction     : in  std_logic := '1';   -- 1 = forward, 0 = backward
         currentNumber : out std_logic_vector(3 downto 0) := "0000";
         carryBit      : out std_logic := '0');
end mod_counter;

architecture behaviorModCounter of mod_counter is
   signal currentNumberSignal : integer range 0 to MAX_NUMBER := 0;
begin
   increment : process(clock, reset)
   begin
      if clock'event and clock = '1' then
         if direction = '1' then
            if currentNumberSignal = MAX_NUMBER then
               currentNumberSignal <= 0;
               carryBit <= '1';
            else
               currentNumberSignal <= currentNumberSignal + 1;
               carryBit <= '0';
            end if;
         else
            if currentNumberSignal = 0 then
               currentNumberSignal <= MAX_NUMBER;
               carryBit <= '1';
            else
               currentNumberSignal <= currentNumberSignal - 1;
               carryBit <= '0';
            end if;
         end if;
      end if;
      if reset = '1' then
         currentNumberSignal <= 0;
      end if;
   end process;
   currentNumber <= std_logic_vector(to_unsigned(currentNumberSignal, 4));
end behaviorModCounter;
