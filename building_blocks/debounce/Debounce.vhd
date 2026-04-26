-------------------------------------------------------------------------------
-- File downloaded from http://www.nandland.com
-------------------------------------------------------------------------------
-- This module is used to debounce any switch or button coming into the FPGA.
-- Does not allow the output of the switch to change unless the switch is
-- steady long enough time.
-------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity Debounce is
  generic (
    -- Default 250 000 ticks of a 25 MHz clock = 10 ms. Testbenches
    -- override to a much smaller value so sim time stays bounded.
    DEBOUNCE_LIMIT : integer := 250000
  );
  port (
    i_Clk    : in std_logic;
    i_Switch : in std_logic;
    o_Switch : out std_logic
  );
end entity Debounce;

architecture RTL of Debounce is

  signal r_Count : integer range 0 to DEBOUNCE_LIMIT := 0;
  signal r_State : std_logic                         := '0';

begin

  p_Debounce : process (i_Clk) is
  begin
    if rising_edge(i_Clk) then

      -- Switch input is different than internal switch value, so an input is
      -- changing.  Increase counter until it is stable for DEBOUNCE_LIMIT.
      if (i_Switch /= r_State and r_Count < DEBOUNCE_LIMIT) then
        r_Count <= r_Count + 1;

        -- End of counter reached, switch is stable, register it, reset counter
      elsif r_Count = DEBOUNCE_LIMIT then
        r_State <= i_Switch;
        r_Count <= 0;

        -- Switches are the same state, reset the counter
      else
        r_Count <= 0;

      end if;
    end if;
  end process p_Debounce;

  -- Assign internal register to output (debounced!)
  o_Switch <= r_State;

end architecture RTL;