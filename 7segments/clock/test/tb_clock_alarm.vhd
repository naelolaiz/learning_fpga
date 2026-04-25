library ieee;
use ieee.std_logic_1164.ALL;
use ieee.numeric_std.ALL;

-- Testbench for AlarmTrigger (alarm match comparator + buzzer gating).
--
-- AlarmTrigger asserts:
--   * when `alarmBcd(23 downto 4) = mainBcd(23 downto 4)`, buzzerOut is
--     `tone AND gate`  -> intermittent ~400 Hz tone, pulsed by the 1 Hz
--     gate, recreating the original 2022 commit 083576f behaviour;
--   * outside the match window, buzzerOut is '0' (driven low). The 2022
--     source returned 'Z' here -- see AlarmTrigger.vhd for why both
--     mirrors now drive '0'.
--
-- Cause-effect properties under test:
--   (A) When BCDs match and gate is high, buzzerOut equals tone.
--   (B) When BCDs match and gate is low, buzzerOut is '0' (gated off).
--   (C) When BCDs mismatch, buzzerOut is '0' regardless of tone/gate.
--   (D) Toggling alarmBcd to break the match while tone+gate are both
--       active makes buzzerOut transition immediately to '0'.
--
-- Plain VHDL-93 style; no 2008-only constructs.

entity tb_clock_alarm is
end tb_clock_alarm;

architecture testbench of tb_clock_alarm is
   signal sMainBcd   : std_logic_vector(23 downto 0) := (others => '0');
   signal sAlarmBcd  : std_logic_vector(23 downto 0) := (others => '0');
   signal sTone      : std_logic := '0';
   signal sGate      : std_logic := '0';
   signal sBuzzer    : std_logic;

   signal sSimulationActive : boolean := true;
begin

   DUT : entity work.AlarmTrigger(RTL)
      port map (
         mainBcd   => sMainBcd,
         alarmBcd  => sAlarmBcd,
         tone      => sTone,
         gate      => sGate,
         buzzerOut => sBuzzer);

   driver : process
   begin
      -- Both BCDs at 0 => upper-20 bits match.
      sMainBcd  <= (others => '0');
      sAlarmBcd <= (others => '0');

      -- (A) match + tone=1 + gate=1  ->  buzzer = '1'
      sTone <= '1'; sGate <= '1';
      wait for 10 ns;
      assert sBuzzer = '1'
         report "(A) match+tone+gate: expected buzzer '1', got " &
                std_logic'image(sBuzzer)
         severity failure;

      -- (B) match + tone=1 + gate=0  ->  buzzer = '0' (gated off)
      sGate <= '0';
      wait for 10 ns;
      assert sBuzzer = '0'
         report "(B) match+tone+!gate: expected buzzer '0', got " &
                std_logic'image(sBuzzer)
         severity failure;

      -- Match + tone=0 + gate=1  ->  buzzer = '0' (no carrier)
      sTone <= '0'; sGate <= '1';
      wait for 10 ns;
      assert sBuzzer = '0'
         report "match+!tone+gate: expected buzzer '0', got " &
                std_logic'image(sBuzzer)
         severity failure;

      -- (C) mismatch + tone+gate both active  ->  buzzer = '0'.
      -- Flip a non-seconds-units bit so the match breaks.
      sMainBcd(8) <= '1';     -- minutes-units bit
      sTone <= '1'; sGate <= '1';
      wait for 10 ns;
      assert sBuzzer = '0'
         report "(C) mismatch: expected buzzer '0', got " &
                std_logic'image(sBuzzer)
         severity failure;

      -- Seconds-units differences DO NOT break the match — the compare
      -- is on bits 23..4. Verify the tolerance: drop minutes back to
      -- match, vary the bottom nibble, expect still buzzer = '1'.
      sMainBcd <= (others => '0');
      sMainBcd(3 downto 0) <= "0101";       -- units=5, alarm units=0
      wait for 10 ns;
      assert sBuzzer = '1'
         report "seconds-units delta: expected buzzer '1' (match holds), got " &
                std_logic'image(sBuzzer)
         severity failure;

      -- (D) Break match again, same tone/gate inputs, observe immediate
      -- transition to '0'.
      sMainBcd(7) <= '1';        -- seconds-tens bit (above the units field)
      wait for 10 ns;
      assert sBuzzer = '0'
         report "(D) match broken: expected buzzer '0', got " &
                std_logic'image(sBuzzer)
         severity failure;

      report "tb_clock_alarm PASSED." severity note;
      sSimulationActive <= false;
      wait;
   end process;

end testbench;
