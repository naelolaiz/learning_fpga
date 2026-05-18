-- VariableTimer
--
-- A `Timer` whose trigger period can be reprogrammed at runtime via
-- a serial-load port. Composed of two pieces:
--
--   1. A shift register that captures a new limit value off `dataIn`,
--      one bit per clock, for as long as `setMax = '1'`. The first
--      clock after `setMax` rises clears the register; subsequent
--      clocks shift `dataIn` into the LSB (bits flow MSB-first into
--      the final value, matching the convention of the 2022 source).
--
--   2. An instance of the [`Timer`](../timer/) building block, fed
--      `clock` and held in reset while `setMax = '1'` so the period
--      change takes effect once the user releases the load line.
--
-- The runtime limit driven onto the inner Timer's `maxLimit` port is
-- clamped to `MAX_NUMBER` — that's both the inner Timer's
-- compile-time range and a sane upper bound for whatever bit pattern
-- the caller shifted in.

LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
use ieee.numeric_std.ALL;

entity VariableTimer is
   generic (MAX_NUMBER       : integer := 50000000;
            TRIGGER_DURATION : integer := 1);
   port (clock          : in  std_logic := '0';
         reset          : in  std_logic := '0';
         setMax         : in  std_logic := '0';
         dataIn         : in  std_logic := '0';
         timerTriggered : out std_logic := '0');
end VariableTimer;

architecture composition of VariableTimer is
   signal limitReg   : integer range 0 to MAX_NUMBER := MAX_NUMBER;
   signal innerReset : std_logic := '0';
begin

   -- Hold the inner Timer in reset while the user is shifting in a
   -- new max — counting while the limit is mid-update would produce
   -- garbage triggers.
   innerReset <= reset or setMax;

   load_limit : process(clock)
      variable shiftReg : unsigned(63 downto 0) := to_unsigned(0, 64);
      variable started  : boolean              := false;
   begin
      if rising_edge(clock) then
         if reset = '1' then
            shiftReg := to_unsigned(0, 64);
            started  := false;
            limitReg <= MAX_NUMBER;
         elsif setMax = '1' then
            if not started then
               -- First clock of the load: clear the shift register.
               shiftReg := to_unsigned(0, 64);
               started  := true;
            else
               shiftReg := shiftReg(62 downto 0) & dataIn;
            end if;
            -- Mirror the in-progress register onto limitReg, clamped
            -- to MAX_NUMBER so the inner Timer's range stays sane.
            if shiftReg <= to_unsigned(MAX_NUMBER, 64) then
               limitReg <= to_integer(shiftReg);
            else
               limitReg <= MAX_NUMBER;
            end if;
         else
            started := false;
         end if;
      end if;
   end process;

   inner : entity work.Timer(behaviorTimer)
      generic map (MAX_NUMBER       => MAX_NUMBER,
                   TRIGGER_DURATION => TRIGGER_DURATION)
      port map    (clock          => clock,
                   reset          => innerReset,
                   maxLimit       => limitReg,
                   timerTriggered => timerTriggered);

end composition;
