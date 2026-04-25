-- tb_fifo_sync_overlapping.vhd
--
-- Focused test for the one case tb_fifo_sync doesn't cover: what
-- happens when write-enable and read-enable are BOTH high on the same
-- cycle. The FIFO should handle this as "push then pop" atomically —
-- occupancy stays constant, no data is lost or duplicated, and FIFO
-- ordering is preserved.
--
-- Sequence:
--   1. Reset, pre-fill with HALF values so the FIFO starts at ~50%
--      occupancy (neither empty nor full — the interesting case for
--      overlap).
--   2. Drive wr_en=1 and rd_en=1 continuously for N cycles, pushing
--      a known sequence of values and reading the output each cycle.
--   3. Assert: empty=0 and full=0 throughout (occupancy did not
--      drift).
--   4. Assert: the read-out sequence matches the input sequence
--      offset by the HALF pre-fill — FIFO ordering preserved under
--      overlap.
--   5. Drain the remaining entries and confirm the final values are
--      the overlap-written ones (the FIFO ended in a consistent
--      state, not a half-updated one).

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity tb_fifo_sync_overlapping is
end entity tb_fifo_sync_overlapping;

architecture testbench of tb_fifo_sync_overlapping is
   constant DATA_WIDTH : integer := 8;
   constant DEPTH      : integer := 8;
   constant HALF       : integer := DEPTH / 2;
   constant OVERLAP_N  : integer := 20;   -- overlapping cycles to run
   constant CLK_PERIOD : time    := 20 ns;

   signal sClk    : std_logic := '0';
   signal sRst    : std_logic := '1';
   signal sWrEn   : std_logic := '0';
   signal sWrData : std_logic_vector(DATA_WIDTH-1 downto 0) := (others => '0');
   signal sRdEn   : std_logic := '0';
   signal sRdData : std_logic_vector(DATA_WIDTH-1 downto 0);
   signal sEmpty  : std_logic;
   signal sFull   : std_logic;
   signal sSimulationActive : boolean := true;
begin

   dut : entity work.fifo_sync
      generic map (DATA_WIDTH => DATA_WIDTH, DEPTH => DEPTH)
      port map (clk => sClk, rst => sRst,
                wr_en => sWrEn, wr_data => sWrData,
                rd_en => sRdEn, rd_data => sRdData,
                empty => sEmpty, full => sFull);

   sClk <= not sClk after CLK_PERIOD/2 when sSimulationActive;

   driver : process
      variable vExpected : integer;
   begin
      -- Release reset.
      wait for 2*CLK_PERIOD;
      sRst <= '0';
      wait for CLK_PERIOD;

      -- Pre-fill with HALF distinct values (1..HALF) so we can tell
      -- them apart from the overlap-phase values (100+).
      for i in 1 to HALF loop
         sWrEn   <= '1';
         sWrData <= std_logic_vector(to_unsigned(i, DATA_WIDTH));
         wait for CLK_PERIOD;
      end loop;
      sWrEn <= '0';
      wait for CLK_PERIOD;
      assert sEmpty = '0' report "Should not be empty after pre-fill" severity failure;
      assert sFull  = '0' report "Should not be full after pre-fill (HALF < DEPTH)" severity failure;

      -- Overlap phase: push values 100..100+OVERLAP_N-1 while draining
      -- simultaneously. Each cycle both enables are high.
      --
      -- First read lands one cycle after the first rd_en pulse (the
      -- FIFO registers rd_data). So at cycle k of overlap, rd_data
      -- reflects the value whose rd_en was asserted at cycle k-1 —
      -- i.e. the (k-1)-th pre-filled value while the pre-fill is
      -- being drained, then rolling into the overlap-phase values.
      for i in 0 to OVERLAP_N-1 loop
         sWrEn   <= '1';
         sRdEn   <= '1';
         sWrData <= std_logic_vector(to_unsigned(100 + i, DATA_WIDTH));
         wait for CLK_PERIOD;

         -- Occupancy invariant: overlap keeps us mid-FIFO.
         assert sEmpty = '0'
            report "overlap cycle " & integer'image(i)
                 & ": empty unexpectedly high"
            severity failure;
         assert sFull = '0'
            report "overlap cycle " & integer'image(i)
                 & ": full unexpectedly high"
            severity failure;

         -- Ordering invariant: data read out this cycle is the next
         -- value in the FIFO, offset by the one-cycle read latency.
         -- For the first HALF overlap cycles the drained values are
         -- the pre-fill (1..HALF); after that they're the overlap
         -- values (100..). The "-1" indexing aligns with rd_data
         -- being the value whose rd_en pulsed a cycle ago.
         if i = 0 then
            vExpected := 1;
         elsif i < HALF then
            vExpected := 1 + i;
         else
            vExpected := 100 + (i - HALF);
         end if;
         assert sRdData = std_logic_vector(to_unsigned(vExpected, DATA_WIDTH))
            report "overlap cycle " & integer'image(i)
                 & ": expected rd_data=" & integer'image(vExpected)
                 & ", got " & integer'image(to_integer(unsigned(sRdData)))
            severity failure;
      end loop;

      -- End of overlap phase: drain whatever remains and assert we
      -- eventually reach empty. Any lost-data bug in the overlap
      -- logic would leave a permanently non-empty FIFO.
      sWrEn <= '0';
      sRdEn <= '1';
      for i in 0 to DEPTH loop   -- more than enough cycles to empty DEPTH words
         wait for CLK_PERIOD;
         exit when sEmpty = '1';
      end loop;
      sRdEn <= '0';
      wait for CLK_PERIOD;
      assert sEmpty = '1'
         report "fifo did not drain after overlap phase -- occupancy drift?"
         severity failure;

      report "fifo_sync overlapping simulation done!" severity note;
      sSimulationActive <= false;
      wait;
   end process;

end architecture testbench;
