-- tb_fir4tap.vhd
--
-- Two canonical FIR scenarios:
--
--   1. HALVING — coeff = {128, 0, 0, 0}. Coefficient 128 = +0.5 in
--      Q1.8, so the filter halves the newest sample. (Exactly +1.0
--      would be 256, but 9-bit signed only reaches +255 — the
--      asymmetric range that comes with two's-complement. Demoing
--      a gain of 0.5 sidesteps the boundary and is still a clean
--      passthrough-with-known-scale.)
--
--   2. BOX AVERAGE — coeff = {64, 64, 64, 64} (sum 256 = +1.0).
--      Output is the average of the four most recent samples.
--
-- The TB streams samples one per clock (sample_valid pulses with one
-- idle cycle between them, so each result_valid corresponds 1:1 with
-- one sample_valid two cycles earlier).

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity tb_fir4tap is
end entity tb_fir4tap;

architecture testbench of tb_fir4tap is
  constant CLK_PERIOD : time := 10 ns;

  signal sClk          : std_logic := '0';
  signal sRst          : std_logic := '1';
  signal sSimActive    : boolean   := true;
  signal sCoeff_0      : std_logic_vector(8 downto 0) := (others => '0');
  signal sCoeff_1      : std_logic_vector(8 downto 0) := (others => '0');
  signal sCoeff_2      : std_logic_vector(8 downto 0) := (others => '0');
  signal sCoeff_3      : std_logic_vector(8 downto 0) := (others => '0');
  signal sSampleIn     : std_logic_vector(15 downto 0) := (others => '0');
  signal sSampleValid  : std_logic := '0';
  signal sResult       : std_logic_vector(15 downto 0);
  signal sResultValid  : std_logic;
begin

  dut : entity work.fir4tap
    port map (
      clk          => sClk,
      rst          => sRst,
      coeff_0      => sCoeff_0,
      coeff_1      => sCoeff_1,
      coeff_2      => sCoeff_2,
      coeff_3      => sCoeff_3,
      sample_in    => sSampleIn,
      sample_valid => sSampleValid,
      result       => sResult,
      result_valid => sResultValid
    );

  sClk <= not sClk after CLK_PERIOD/2 when sSimActive;

  driver : process
    -- Stream one sample and check the result two cycles later.
    procedure stream_and_check (
      constant tag      : in string;
      constant sample   : in integer;
      constant expected : in integer) is
    begin
      -- Drive sample on rising edge.
      wait until rising_edge(sClk);
      sSampleIn    <= std_logic_vector(to_signed(sample, 16));
      sSampleValid <= '1';
      wait until rising_edge(sClk);
      sSampleValid <= '0';
      -- Cycle N+1: samples are shifted, MAC computing.
      wait until rising_edge(sClk);
      -- Cycle N+2: result is latched, result_valid pulses.
      -- Small post-edge delay so the DUT's clocked-output updates
      -- have propagated before the TB samples them — VHDL's
      -- process ordering at the same delta cycle is otherwise
      -- non-deterministic.
      wait for 1 ns;
      assert sResultValid = '1'
        report tag & ": result_valid did not pulse"
        severity error;
      assert to_integer(signed(sResult)) = expected
        report tag & ": result expected " & integer'image(expected)
             & " got " & integer'image(to_integer(signed(sResult)))
        severity error;
    end procedure;
  begin
    wait for 2 * CLK_PERIOD;
    sRst <= '0';
    wait for CLK_PERIOD;

    -- ====== Test 1: HALVING passthrough (coeff = 0.5) ======
    sCoeff_0 <= std_logic_vector(to_signed(128, 9));
    sCoeff_1 <= (others => '0');
    sCoeff_2 <= (others => '0');
    sCoeff_3 <= (others => '0');

    stream_and_check("halve 100",  100,   50);
    stream_and_check("halve 200",  200,  100);
    stream_and_check("halve 50",    50,   25);
    stream_and_check("halve -10",  -10,   -5);
    stream_and_check("halve -1000", -1000, -500);

    -- ====== Test 2: BOX AVERAGE ======
    -- Reset the sample history so the box-average test starts clean.
    sRst <= '1';
    wait for 2 * CLK_PERIOD;
    sRst <= '0';
    wait for CLK_PERIOD;

    sCoeff_0 <= std_logic_vector(to_signed(64, 9));
    sCoeff_1 <= std_logic_vector(to_signed(64, 9));
    sCoeff_2 <= std_logic_vector(to_signed(64, 9));
    sCoeff_3 <= std_logic_vector(to_signed(64, 9));

    -- Sample 0 streamed; samples = {100, 0, 0, 0}; avg = (100+0+0+0)/4 = 25
    stream_and_check("box 100 fill1", 100, 25);
    -- samples = {100, 100, 0, 0}; avg = 200/4 = 50
    stream_and_check("box 100 fill2", 100, 50);
    -- samples = {100, 100, 100, 0}; avg = 300/4 = 75
    stream_and_check("box 100 fill3", 100, 75);
    -- samples = {100, 100, 100, 100}; avg = 100
    stream_and_check("box 100 full",  100, 100);
    -- Step up to 200; samples = {200, 100, 100, 100}; avg = 500/4 = 125
    stream_and_check("box step 200a", 200, 125);
    -- samples = {200, 200, 100, 100}; avg = 600/4 = 150
    stream_and_check("box step 200b", 200, 150);

    report "tb_fir4tap: all cases passed" severity note;
    sSimActive <= false;
    wait;
  end process;

end architecture testbench;
