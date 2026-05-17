library ieee;
use ieee.std_logic_1164.all;

-- mode_blink: verify both modes side-by-side.
--
-- Two DUTs run from the same square-wave input, one in passthrough
-- mode (toggleMode='0'), one in half-rate mode ('1'). After a known
-- number of input rising edges we should see:
--   * passthrough output toggles 2× per input period (one per rising
--     and one per falling edge of signalIn → it equals signalIn);
--   * half-rate output toggles once per input rising edge.

entity tb_mode_blink is
end tb_mode_blink;

architecture testbench of tb_mode_blink is
   constant IN_PERIOD : time := 40 ns;   -- two transitions per period

   signal sSignalIn          : std_logic := '0';
   signal sSimulationActive  : boolean   := true;

   signal sOutPassthrough    : std_logic;
   signal sOutHalfRate       : std_logic;

   signal sPassthroughEdges  : integer := 0;
   signal sHalfRateEdges     : integer := 0;
begin

   DUT_PASS : entity work.mode_blink
      port map (signalIn   => sSignalIn,
                toggleMode => '0',
                signalOut  => sOutPassthrough);

   DUT_HALF : entity work.mode_blink
      port map (signalIn   => sSignalIn,
                toggleMode => '1',
                signalOut  => sOutHalfRate);

   sSignalIn <= not sSignalIn after IN_PERIOD / 2 when sSimulationActive;

   -- Count every transition (both rising and falling edges).
   count_pass : process(sOutPassthrough)
   begin
      if sOutPassthrough'event then
         sPassthroughEdges <= sPassthroughEdges + 1;
      end if;
   end process;

   count_half : process(sOutHalfRate)
   begin
      if sOutHalfRate'event then
         sHalfRateEdges <= sHalfRateEdges + 1;
      end if;
   end process;

   STIMULUS : process
   begin
      -- 10 input periods → 20 input transitions → 10 input rising edges.
      -- The +1 ns settles any transition that lands exactly at the end
      -- of the window into the count process before we sample it.
      wait for 10 * IN_PERIOD + 1 ns;

      -- Passthrough mirrors the input: 20 transitions.
      assert sPassthroughEdges = 20
         report "passthrough: expected 20 edges, got "
                & integer'image(sPassthroughEdges)
         severity failure;

      -- Half-rate toggles once per input rising edge: 10 transitions.
      assert sHalfRateEdges = 10
         report "half-rate: expected 10 edges, got "
                & integer'image(sHalfRateEdges)
         severity failure;

      sSimulationActive <= false;
      wait;
   end process;

end testbench;
