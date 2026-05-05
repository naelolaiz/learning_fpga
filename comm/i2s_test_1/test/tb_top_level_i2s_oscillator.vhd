-- tb_top_level_i2s_oscillator.vhd
--
-- Integration testbench for the mono I2S oscillator: drives the
-- 50 MHz system clock and active-high reset, then asserts that the
-- I2S framing arrives on time and that the NCO is producing a
-- non-zero serial stream.
--
-- This is the framing-correctness check (rates and shape); the
-- bit-level data-path equivalence between the VHDL inline LUT and
-- the Verilog $readmemh LUT is what the per-language CI mirror
-- catches by running the same TB twice.

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity tb_top_level_i2s_oscillator is
end entity;

architecture testbench of tb_top_level_i2s_oscillator is
  constant CLK_PERIOD : time := 20 ns;            -- 50 MHz

  signal iClock50Mhz : std_logic := '0';
  signal iReset      : std_logic := '1';
  signal mclk        : std_logic;
  signal lrclk       : std_logic;
  signal sclk        : std_logic;                  -- BCK
  signal sdata       : std_logic;

  signal sim_active  : boolean := true;

  -- Event counters, sampled by edge-detect processes below.
  signal mclk_count  : integer := 0;
  signal sclk_count  : integer := 0;
  signal lrclk_count : integer := 0;

  -- Captured 24-bit left-channel sample, assembled MSB-first from
  -- SDATA on BCK rising edges (= the slave-sampling edge).
  signal capture_l   : std_logic_vector(23 downto 0) := (others => '0');
  signal capture_l_done : boolean := false;
begin

  dut : entity work.top_level_i2s_oscillator
    port map (
      iReset          => iReset,
      iClock50Mhz     => iClock50Mhz,
      oMasterClock    => mclk,
      oLeftRightClock => lrclk,
      oSerialBitClock => sclk,
      oData           => sdata
    );

  -- 50 MHz system clock.
  iClock50Mhz <= not iClock50Mhz after CLK_PERIOD/2 when sim_active else '0';

  -- Edge counters.
  mclk_counter : process (mclk)
  begin
    if rising_edge(mclk) then
      mclk_count <= mclk_count + 1;
    end if;
  end process;

  sclk_counter : process (sclk)
  begin
    if rising_edge(sclk) then
      sclk_count <= sclk_count + 1;
    end if;
  end process;

  lrclk_counter : process (lrclk)
  begin
    if (lrclk'event) then
      lrclk_count <= lrclk_count + 1;
    end if;
  end process;

  -- Assemble one left-channel sample. We start capturing on the
  -- first lrclk falling edge after the second lrclk rising edge —
  -- so the first frame (where data_l_i is still all-zero from the
  -- master's reset state) is skipped. SDATA is sampled on BCK
  -- rising edges, MSB-first.
  capture_left : process
    variable bit_idx : integer := 23;
    variable seen_lr_rising : integer := 0;
  begin
    -- Wait for the second lrclk rising edge (so we're in the right
    -- channel of frame 1) then for its falling edge (= start of
    -- frame 2's left half).
    wait until rising_edge(lrclk);
    wait until rising_edge(lrclk);
    wait until falling_edge(lrclk);
    bit_idx := 23;
    while bit_idx >= 0 loop
      wait until rising_edge(sclk);
      capture_l(bit_idx) <= sdata;
      bit_idx := bit_idx - 1;
    end loop;
    capture_l_done <= true;
    wait;
  end process;

  -- Stimulus + assertions.
  driver : process
  begin
    iReset <= '1';
    wait for 10 * CLK_PERIOD;
    iReset <= '0';

    -- Run long enough to see several full LRCLK frames.
    -- Sample period @ 96 kHz Fs ≈ 10.42 µs. 300 µs = ~28 frames.
    wait for 300 us;

    -- LRCLK should have transitioned at least 50 times (= 25 full
    -- frames at 96 kHz over 300 µs, with margin).
    assert lrclk_count > 40
      report "lrclk transitioned too few times: " & integer'image(lrclk_count)
      severity error;

    -- BCK runs at 48× LRCLK (24 bits per channel × 2 channels). For
    -- ~28 frames we expect ~1344 BCK rising edges; allow margin.
    assert sclk_count > 1000
      report "sclk too few rising edges: " & integer'image(sclk_count)
      severity error;

    -- MCLK runs at 256× sample rate ≈ 24.576 MHz. Over 300 µs
    -- that's ~7373 rising edges; allow margin.
    assert mclk_count > 6000
      report "mclk too few rising edges: " & integer'image(mclk_count)
      severity error;

    -- The capture process should have assembled a 24-bit sample by
    -- now; assert it's non-zero, which means the NCO's output has
    -- propagated through the master into the SDATA stream.
    assert capture_l_done
      report "left-channel capture did not complete in 300us"
      severity error;
    assert capture_l /= x"000000"
      report "captured left sample is all-zero - NCO not running?"
      severity error;

    report "i2s_test_1 simulation done!" severity note;
    sim_active <= false;
    wait;
  end process;

end architecture testbench;
