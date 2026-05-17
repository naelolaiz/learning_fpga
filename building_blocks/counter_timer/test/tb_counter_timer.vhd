library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

-- CounterTimer: confirm the saturating-wrap cascade.
--
-- Tiny generics so the test fits in a short window: an inner Timer
-- with MAX_NUMBER=9 (period 10 cycles — Timer ticks at
-- counter==MAX_NUMBER then wraps, so the period is MAX+1), and a
-- counter modulus of 4. Expected behaviour:
--
--   * the inner Timer ticks every 10 clocks → `timerTriggered`
--     pulses high once per period;
--   * the counter advances on each tick: 0 → 1 → 2 → 3 → 4 → 0;
--   * after 50 clocks (5 ticks) the counter is back at 0;
--   * after 100 clocks (10 ticks) the counter is at 0 again.

entity tb_counter_timer is
end tb_counter_timer;

architecture testbench of tb_counter_timer is
   constant CLK_PERIOD : time := 20 ns;

   signal sClock            : std_logic := '0';
   signal sReset            : std_logic := '0';
   signal sSimulationActive : boolean   := true;

   signal sTick    : std_logic                       := '0';
   signal sCounter : std_logic_vector(63 downto 0)   := (others => '0');
begin

   DUT : entity work.CounterTimer
      generic map (MAX_NUMBER_FOR_TIMER => 9, MAX_NUMBER_FOR_COUNTER => 4)
      port map (clock          => sClock,
                reset          => sReset,
                timerTriggered => sTick,
                counter        => sCounter);

   sClock <= not sClock after CLK_PERIOD / 2 when sSimulationActive;

   STIMULUS : process
   begin
      sReset <= '1';
      wait for 2 * CLK_PERIOD;
      sReset <= '0';

      -- After 5 ticks (50 clocks) the counter should have wrapped
      -- exactly once: sequence 0→1→2→3→4→0.
      wait for 50 * CLK_PERIOD;
      assert to_integer(unsigned(sCounter)) = 0
         report "after 5 ticks expected counter=0, got "
                & integer'image(to_integer(unsigned(sCounter)))
         severity failure;

      -- After 10 ticks (100 clocks total → 50 more) it should wrap
      -- a second time, back to 0.
      wait for 50 * CLK_PERIOD;
      assert to_integer(unsigned(sCounter)) = 0
         report "after 10 ticks expected counter=0, got "
                & integer'image(to_integer(unsigned(sCounter)))
         severity failure;

      sSimulationActive <= false;
      wait;
   end process;

end testbench;
