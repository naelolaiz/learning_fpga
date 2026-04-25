-- AlarmTrigger.vhd
--
-- Compares the running clock's BCD digits against the user-set alarm BCD
-- digits and produces an intermittent buzzer signal:
--
--   * compare bits 23..4 (everything above seconds-units) so a single
--     match holds for ~10 simulated seconds before the units roll over;
--   * the ~400 Hz tone is AND-gated by the 1 Hz square so the alarm
--     beeps once per second instead of holding a continuous tone;
--   * outside the match window the output is 'Z' (high impedance) so
--     the FPGA pin floats, matching the original 2022 behaviour.
--
-- Reproduces the original commit 083576f's intermittent-tone pattern but
-- as a standalone entity with an explicit interface, so testbenches can
-- drive synthetic BCD vectors without having to wait for clock cascades.
--
-- Pure VHDL-93 (no 2008 features) so the same source compiles under
-- either standard.

LIBRARY ieee;
USE ieee.std_logic_1164.ALL;

entity AlarmTrigger is
   port (
      mainBcd     : in  std_logic_vector(23 downto 0);
      alarmBcd    : in  std_logic_vector(23 downto 0);
      tone        : in  std_logic;        -- ~400 Hz buzzer carrier
      gate        : in  std_logic;        -- 1 Hz square (intermittence)
      buzzerOut   : out std_logic := 'Z');
end AlarmTrigger;

architecture RTL of AlarmTrigger is
begin
   buzzerOut <= tone and gate when alarmBcd(23 downto 4) = mainBcd(23 downto 4)
                              else 'Z';
end RTL;
