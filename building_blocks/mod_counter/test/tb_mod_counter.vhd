library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

-- mod_counter: walk forward through one full cycle, then backward
-- through a second, asserting the value at each step and that
-- carryBit fires exactly on the wrap.
--
-- MAX_NUMBER = 4 keeps the cycles small enough to enumerate
-- explicitly in the stimulus.

entity tb_mod_counter is
end tb_mod_counter;

architecture testbench of tb_mod_counter is
   constant CLK_PERIOD : time := 20 ns;
   constant MAX : integer := 4;

   signal sClock            : std_logic := '0';
   signal sReset            : std_logic := '0';
   signal sDirection        : std_logic := '1';
   signal sCurrent          : std_logic_vector(3 downto 0) := "0000";
   signal sCarry            : std_logic := '0';
   signal sSimulationActive : boolean   := true;
begin

   DUT : entity work.mod_counter
      generic map (MAX_NUMBER => MAX)
      port map (clock         => sClock,
                reset         => sReset,
                direction     => sDirection,
                currentNumber => sCurrent,
                carryBit      => sCarry);

   sClock <= not sClock after CLK_PERIOD / 2 when sSimulationActive;

   STIMULUS : process
   begin
      sReset <= '1';
      wait for 2 * CLK_PERIOD;
      sReset <= '0';

      -- Forward walk: count 1, 2, 3, 4, 0 (carry on the 0 wrap).
      sDirection <= '1';
      for expected in 1 to MAX loop
         wait until rising_edge(sClock);
         wait for 1 ns;   -- let nodelabel propagate past the delta
         assert to_integer(unsigned(sCurrent)) = expected
            report "forward: at step " & integer'image(expected)
                   & " expected " & integer'image(expected) & ", got "
                   & integer'image(to_integer(unsigned(sCurrent)))
            severity failure;
         assert sCarry = '0'
            report "forward: unexpected carry mid-cycle at step "
                   & integer'image(expected)
            severity failure;
      end loop;
      -- One more clock to land on the wrap (MAX → 0 with carry).
      wait until rising_edge(sClock);
      wait for 1 ns;
      assert to_integer(unsigned(sCurrent)) = 0
         report "forward wrap: expected 0, got "
                & integer'image(to_integer(unsigned(sCurrent)))
         severity failure;
      assert sCarry = '1'
         report "forward wrap: carryBit was not asserted"
         severity failure;

      -- Backward walk: from 0, expect MAX, MAX-1, ..., 1, 0.
      sDirection <= '0';
      for expected in MAX downto 1 loop
         wait until rising_edge(sClock);
         wait for 1 ns;
         assert to_integer(unsigned(sCurrent)) = expected
            report "backward: at step " & integer'image(MAX - expected + 1)
                   & " expected " & integer'image(expected) & ", got "
                   & integer'image(to_integer(unsigned(sCurrent)))
            severity failure;
      end loop;
      -- Land on 0 with carry.
      wait until rising_edge(sClock);
      wait for 1 ns;
      assert to_integer(unsigned(sCurrent)) = 0
         report "backward wrap: expected 0, got "
                & integer'image(to_integer(unsigned(sCurrent)))
         severity failure;

      sSimulationActive <= false;
      wait;
   end process;

end testbench;
