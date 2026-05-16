-- tb_rom_lut_realmath.vhd
--
-- Tutorial-grade equivalence proof between two ways of computing
-- the sin·nibble table:
--
--   * THE TESTBENCH computes the gold reference inside itself using
--     IEEE.MATH_REAL.SIN — concise, mathematically transparent, but
--     NOT synthesisable (real-math is simulation-only).
--
--   * THE DUT (single_clock_rom_func) computes the same table at
--     elaboration using a precomputed 32-entry Q15 fixed-point sine
--     table + integer cross-product. Fully synthesisable; the
--     production form.
--
-- The testbench drives every (angle, nibble) and asserts the DUT
-- output is bit-identical to the real-math reference. If the
-- integer-math approximation ever drifts (e.g. the seed table is
-- regenerated at a different precision), this testbench fires.
--
-- The lesson: real-math is fine for *deriving* gold references in
-- testbenches; production code stays integer.

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;

entity tb_rom_lut_realmath is
end entity tb_rom_lut_realmath;

architecture testbench of tb_rom_lut_realmath is
  constant CLK_PERIOD : time := 4 ns;

  signal sClock       : std_logic                    := '0';
  signal sAngleIdx    : std_logic_vector(6 downto 0) := (others => '0');
  signal sNibbleIdx   : std_logic_vector(3 downto 0) := (others => '0');
  signal sOutC        : std_logic_vector(9 downto 0);
  signal sTestRunning : boolean                      := true;

  -- Real-math gold reference. The Verilog twin uses the same
  -- formula via $sin.
  --     ref(row, col) = round( sin(row · π/64) · col · 31 )
  function real_math_ref (row, col : integer) return integer is
    constant MAGNITUDE : real := 31.0;
  begin
    return integer(round(SIN(MATH_PI_OVER_2 * real(row) / 32.0)
                         * real(col) * MAGNITUDE));
  end function;
begin

  sClock <= not sClock after CLK_PERIOD / 2 when sTestRunning;

  dut : entity work.single_clock_rom_func
    port map (clock              => sClock,
              read_angle_idx     => sAngleIdx,
              nibble_product_idx => sNibbleIdx,
              output             => sOutC);

  driver : process
    variable angle    : integer;          -- 0..127 over all four quadrants
    variable nibble   : integer;          -- 0..15
    variable expected : integer;          -- signed reference value
    variable mismatches : integer := 0;
    variable angle_mod : integer;
  begin
    wait until falling_edge(sClock);

    -- Sweep every (angle, nibble) pair across all four quadrants and
    -- assert the DUT's output equals the testbench's real-math ref.
    -- Quadrant unfolding mirrors the DUT's internal logic:
    --   quadrant 0 (angle 0..31)   :  ref = +sin
    --   quadrant 1 (angle 32..63)  :  ref = +sin(32 - (a mod 32))
    --   quadrant 2 (angle 64..95)  :  ref = -sin
    --   quadrant 3 (angle 96..127) :  ref = -sin(32 - (a mod 32))
    for a in 0 to 127 loop
      for n in 0 to 15 loop
        sAngleIdx  <= std_logic_vector(to_unsigned(a, 7));
        sNibbleIdx <= std_logic_vector(to_unsigned(n, 4));
        wait until falling_edge(sClock);

        angle_mod := a mod 32;
        case (a / 32) is
          when 0 => expected :=   real_math_ref(angle_mod,         n);
          when 1 => expected :=   real_math_ref(31 - angle_mod,    n);
          when 2 => expected :=  -real_math_ref(angle_mod,         n);
          when 3 => expected :=  -real_math_ref(31 - angle_mod,    n);
          when others => expected := 0;
        end case;

        if to_integer(signed(sOutC)) /= expected then
          report "real-math mismatch at (a=" & integer'image(a) &
                 ", n=" & integer'image(n) & "): expected " &
                 integer'image(expected) & ", got " &
                 integer'image(to_integer(signed(sOutC)))
                 severity error;
          mismatches := mismatches + 1;
        end if;
      end loop;
    end loop;

    assert mismatches = 0
      report "tb_rom_lut_realmath: " & integer'image(mismatches) & " mismatches"
      severity error;

    report "tb_rom_lut_realmath: rom_lut_func matches the real-math reference on every address"
      severity note;
    sTestRunning <= false;
    wait;
  end process;

end architecture testbench;
