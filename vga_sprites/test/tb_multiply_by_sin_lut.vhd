library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.trigonometric.all;

-- Focused unit test for `multiplyBySinLUT`.
--
-- tb_trigonometric covers the end-to-end rotate() integration. This
-- testbench isolates the LUT itself and asserts the algebraic
-- symmetries it must satisfy — properties that hold for ANY correct
-- sin table, independent of scaling or wordlength choices:
--
--   (A) odd symmetry in input:     L(idx, -x) ≈ -L(idx, +x)
--   (B) anti-symmetry across π:    L(idx + 16, x) ≈ -L(idx, x)
--   (C) mirror across π/2:         L(16 - idx, x) ≈  L(idx, x)
--   (D) bounded output:            |L(idx, x)| ≤ |x| + 1
--
-- The ±1 tolerance on (A)-(C) accommodates the inherent asymmetry of
-- two's-complement truncation (|max negative| = 128 vs. |max positive|
-- = 127, and nibble-level rounding in the multiply-accumulate). A real
-- bug in sign handling or table layout would fail by far more.
--
-- Each property sweeps a small but representative set of (idx, input)
-- pairs and drives its progress onto signals so the waveform shows
-- which stage is running even when all assertions pass.
entity tb_multiply_by_sin_lut is
end tb_multiply_by_sin_lut;

architecture testbench of tb_multiply_by_sin_lut is

   constant TOL : integer := 1;

   signal sStage   : integer := 0;
   signal sIdx     : std_logic_vector(4 downto 0) := (others => '0');
   signal sInput   : std_logic_vector(7 downto 0) := (others => '0');
   signal sOutput  : integer := 0;
   signal sClock   : std_logic := '0'; -- reference clock for viewing
   signal sSimulationActive : boolean := true;

   -- Helper: call the LUT with (idx, signed integer input) and return
   -- the signed-integer output. Kept small to keep the property
   -- assertions below readable.
   function call_lut(idx : integer; x : integer) return integer is
      variable vIdx : std_logic_vector(4 downto 0);
      variable vIn  : std_logic_vector(7 downto 0);
      variable vOut : std_logic_vector(7 downto 0);
   begin
      vIdx := std_logic_vector(to_unsigned(idx mod 32, 5));
      vIn  := std_logic_vector(to_signed(x, 8));
      vOut := multiplyBySinLUT(vIdx, vIn);
      return to_integer(signed(vOut));
   end function;

begin

   check : process
      variable vPos  : integer;
      variable vNeg  : integer;
      variable vRef  : integer;
      variable vDelta : integer;
   begin
      ---------------------------------------------------------------
      -- Property A: odd symmetry in input.
      -- sin(·) maps sign(input) through to the output, so for any idx
      -- and any non-zero x, L(idx, -x) must be within TOL of -L(idx,x).
      ---------------------------------------------------------------
      sStage <= 1;
      for idx in 0 to 31 loop
         for xMag in 1 to 127 loop
            if (xMag mod 16) = 1 or xMag = 127 then   -- 9 samples per idx
               sIdx    <= std_logic_vector(to_unsigned(idx, 5));
               sInput  <= std_logic_vector(to_signed(xMag, 8));
               vPos    := call_lut(idx,  xMag);
               vNeg    := call_lut(idx, -xMag);
               vDelta  := vPos + vNeg; -- should be ~0
               sOutput <= vPos;
               assert abs(vDelta) <= TOL
                  report "A: odd symmetry broken at idx=" & integer'image(idx)
                       & ", |x|=" & integer'image(xMag)
                       & ": L(+x)=" & integer'image(vPos)
                       & ", L(-x)=" & integer'image(vNeg)
                  severity failure;
               sClock <= not sClock;
               wait for 20 ns;
            end if;
         end loop;
      end loop;

      ---------------------------------------------------------------
      -- Property B: anti-symmetry across π.
      -- sin(θ + π) = -sin(θ), so L(idx + 16, x) must be within TOL of
      -- -L(idx, x).
      ---------------------------------------------------------------
      sStage <= 2;
      for idx in 0 to 15 loop
         for x in -64 to 64 loop
            if (x mod 16) = 0 then   -- 9 samples per idx
               sIdx    <= std_logic_vector(to_unsigned(idx, 5));
               sInput  <= std_logic_vector(to_signed(x, 8));
               vPos    := call_lut(idx,      x);
               vRef    := call_lut(idx + 16, x);
               vDelta  := vPos + vRef;
               sOutput <= vPos;
               assert abs(vDelta) <= TOL
                  report "B: anti-symmetry across pi broken at idx=" & integer'image(idx)
                       & ", x=" & integer'image(x)
                       & ": L(idx)=" & integer'image(vPos)
                       & ", L(idx+16)=" & integer'image(vRef)
                  severity failure;
               sClock <= not sClock;
               wait for 20 ns;
            end if;
         end loop;
      end loop;

      ---------------------------------------------------------------
      -- Property C: mirror across π/2.
      -- sin(π - θ) = sin(θ), so L(16 - idx, x) must be within TOL of
      -- L(idx, x). Tested over idx 1..15 (idx=0 -> 16-0=16 is covered
      -- by B, and the degenerate idx=16 is also covered there).
      ---------------------------------------------------------------
      sStage <= 3;
      for idx in 1 to 15 loop
         for x in -64 to 64 loop
            if (x mod 16) = 0 then
               sIdx    <= std_logic_vector(to_unsigned(idx, 5));
               sInput  <= std_logic_vector(to_signed(x, 8));
               vPos    := call_lut(idx,       x);
               vRef    := call_lut(16 - idx,  x);
               vDelta  := vPos - vRef;
               sOutput <= vPos;
               assert abs(vDelta) <= TOL
                  report "C: mirror across pi/2 broken at idx=" & integer'image(idx)
                       & ", x=" & integer'image(x)
                       & ": L(idx)=" & integer'image(vPos)
                       & ", L(16-idx)=" & integer'image(vRef)
                  severity failure;
               sClock <= not sClock;
               wait for 20 ns;
            end if;
         end loop;
      end loop;

      ---------------------------------------------------------------
      -- Property D: |sin(·)·x| ≤ |x| + 1 for every (idx, x).
      -- A correct LUT with |sin| ≤ 1 must produce outputs no larger
      -- in magnitude than the input, modulo one unit of truncation
      -- slop. A LUT-scaling regression would blow through this bound.
      ---------------------------------------------------------------
      sStage <= 4;
      for idx in 0 to 31 loop
         for x in -127 to 127 loop
            if (x mod 32) = 0 or x = 127 or x = -127 then
               sIdx    <= std_logic_vector(to_unsigned(idx, 5));
               sInput  <= std_logic_vector(to_signed(x, 8));
               vPos    := call_lut(idx, x);
               sOutput <= vPos;
               assert abs(vPos) <= abs(x) + 1
                  report "D: bound |L(idx,x)| > |x|+1 at idx=" & integer'image(idx)
                       & ", x=" & integer'image(x)
                       & ", L=" & integer'image(vPos)
                  severity failure;
               sClock <= not sClock;
               wait for 20 ns;
            end if;
         end loop;
      end loop;

      sStage <= 99; -- done
      sSimulationActive <= false;
      wait;
   end process;

end testbench;
