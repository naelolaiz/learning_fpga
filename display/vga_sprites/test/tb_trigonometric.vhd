library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.trigonometric.all;
use work.definitions.all;

-- Testbench for the trigonometric package.
--
-- Two processes run in parallel:
--
--   check_properties -- assertion-driven; enumerates algebraic
--   properties of multiplyBySinLUT and rotate that must hold for any
--   well-formed LUT. Fails the simulation loudly if a property is
--   violated, so a broken LUT regresses CI instead of silently
--   producing bad visuals.
--
--   sweep_for_waveform -- drives a systematic stimulus sweep into
--   signals so the rendered waveform in the gallery shows every
--   rotation index applied to a small grid of (x, y). Waveform-only,
--   no assertions.
--
-- The sweep process deliberately does not gate on the checker: the
-- waveform should be produced even if assertions are failing, so the
-- gallery still reflects what the LUT is actually computing at the
-- point of failure.

entity tb_trigonometric is
end tb_trigonometric;

architecture testbench of tb_trigonometric is

   -- Signals the waveform sweep writes to (visible in the rendered waveform PNG).
   signal indexForTableStdTestRotate : std_logic_vector(4 downto 0) := (others => '0');
   signal sInputPos                  : Pos2D := (0, 0);
   signal sOutputPos                 : Pos2D := (0, 0);
   signal sClock                     : std_logic := '0';

   -- Signals the assertion process writes to, so the checker's
   -- progress is also visible in the waveform if anyone inspects it.
   signal checkerStage      : integer := 0;
   signal checkerLUTIndex   : std_logic_vector(4 downto 0) := (others => '0');
   signal checkerLUTInput   : std_logic_vector(7 downto 0) := (others => '0');
   signal checkerLUTOutput  : std_logic_vector(7 downto 0) := (others => '0');

   signal sSimulationActive : boolean := true;

begin

   ------------------------------------------------------------------
   -- Assertion-driven property checks.
   --
   -- These exercise algebraic properties the LUT and rotate must
   -- satisfy for ANY correct implementation, so the checker stays
   -- meaningful even if the LUT contents or fixed-point scaling are
   -- tweaked later.
   ------------------------------------------------------------------
   check_properties : process
      variable vIdx       : std_logic_vector(4 downto 0);
      variable vInput     : std_logic_vector(7 downto 0);
      variable vOutput    : std_logic_vector(7 downto 0);
      variable vPos       : Pos2D;
      variable vOutPos    : Pos2D;
      variable vOutNegPos : Pos2D;
      constant SPRITE_SIZE_CHECK : Size2D := (11, 11);
   begin
      -- Stage 1: sin(0)·x == 0 for every input.
      -- LUT row 0 is all zeros; this pins that invariant.
      checkerStage <= 1;
      for i in -128 to 127 loop
         vIdx   := "00000";
         vInput := std_logic_vector(to_signed(i, 8));
         vOutput := multiplyBySinLUT(vIdx, vInput);
         checkerLUTIndex  <= vIdx;
         checkerLUTInput  <= vInput;
         checkerLUTOutput <= vOutput;
         assert vOutput = "00000000"
            report "sin(0)*x should be 0, got "
                 & integer'image(to_integer(signed(vOutput)))
                 & " for input " & integer'image(i)
            severity failure;
         wait for 50 ns;
      end loop;

      -- Stage 2: sin(pi)·x == 0 for every input.
      -- Index 16 sets sinIsNegative='1' but indexForTable=0, so LUT
      -- row 0 is hit; flipping the sign of zero is still zero.
      checkerStage <= 2;
      for i in -128 to 127 loop
         vIdx   := "10000";
         vInput := std_logic_vector(to_signed(i, 8));
         vOutput := multiplyBySinLUT(vIdx, vInput);
         checkerLUTIndex  <= vIdx;
         checkerLUTInput  <= vInput;
         checkerLUTOutput <= vOutput;
         assert vOutput = "00000000"
            report "sin(pi)*x should be 0, got "
                 & integer'image(to_integer(signed(vOutput)))
                 & " for input " & integer'image(i)
            severity failure;
         wait for 50 ns;
      end loop;

      -- Stage 3: sin(·)·0 == 0 for every index.
      checkerStage <= 3;
      for idx in 0 to 31 loop
         vIdx   := std_logic_vector(to_unsigned(idx, 5));
         vInput := (others => '0');
         vOutput := multiplyBySinLUT(vIdx, vInput);
         checkerLUTIndex  <= vIdx;
         checkerLUTInput  <= vInput;
         checkerLUTOutput <= vOutput;
         assert vOutput = "00000000"
            report "sin(idx)*0 should be 0, got "
                 & integer'image(to_integer(signed(vOutput)))
                 & " for idx " & integer'image(idx)
            severity failure;
         wait for 50 ns;
      end loop;

      -- Stage 4: rotate((0,0), idx) == (0,0) for every rotation.
      -- Linearity: the zero vector is a fixed point of any rotation.
      checkerStage <= 4;
      vPos := (0, 0);
      for idx in 0 to 31 loop
         vIdx := std_logic_vector(to_unsigned(idx, 5));
         vOutPos := rotate(SPRITE_SIZE_CHECK, vPos, vIdx);
         assert vOutPos = (0, 0)
            report "rotate((0,0), idx=" & integer'image(idx) & ") should be (0,0), got ("
                 & integer'image(vOutPos.x) & ", " & integer'image(vOutPos.y) & ")"
            severity failure;
         wait for 50 ns;
      end loop;

      -- Stage 5: rotate is approximately linear ->
      --    rotate(-pos, idx) ~= -rotate(pos, idx), modulo LUT quantization.
      --
      -- The rotate function does integer arithmetic on 8-bit fixed-point
      -- sin/cos values, with truncation toward zero. For small input
      -- magnitudes (|pos| near 1) the truncation error is a significant
      -- fraction of the signal, so rotate(1,1) and rotate(-1,-1) can
      -- legitimately differ by ±2 in each axis without any bug present.
      -- For this reason the assertion checks a ±2-per-axis tolerance
      -- rather than strict equality. A real sign-handling break in
      -- either LUT would fail by much more than that.
      --
      -- Positions are chosen large enough (|p| >= 10) that the
      -- quantization tolerance stays well under the signal magnitude.
      checkerStage <= 5;
      for idx in 0 to 31 loop
         vIdx := std_logic_vector(to_unsigned(idx, 5));
         for px in 1 to 5 loop
            for py in 1 to 5 loop
               vPos := (px * 10, py * 10);
               vOutPos := rotate(SPRITE_SIZE_CHECK, vPos, vIdx);
               vPos := (-px * 10, -py * 10);
               vOutNegPos := rotate(SPRITE_SIZE_CHECK, vPos, vIdx);
               assert abs(vOutNegPos.x + vOutPos.x) <= 2
                  and abs(vOutNegPos.y + vOutPos.y) <= 2
                  report "rotate linearity broken at idx=" & integer'image(idx)
                       & ", pos=(" & integer'image(px*10) & "," & integer'image(py*10) & "): "
                       & "rotate(+)=(" & integer'image(vOutPos.x) & "," & integer'image(vOutPos.y) & "), "
                       & "rotate(-)=(" & integer'image(vOutNegPos.x) & "," & integer'image(vOutNegPos.y) & ")"
                  severity failure;
               wait for 50 ns;
            end loop;
         end loop;
      end loop;

      checkerStage <= 99; -- done
      wait;
   end process;


   ------------------------------------------------------------------
   -- Waveform sweep: drives every rotation index across a small grid
   -- of (x, y) into signals, so the gallery PNG shows how rotate
   -- evolves. No assertions; this block is visual only.
   ------------------------------------------------------------------
   sweep_for_waveform : process
      constant sprite_size : Size2D := (11, 11);
      variable vInputPos   : Pos2D  := (0, 0);
      variable vOutputPos  : Pos2D  := (0, 0);
   begin
      for indexForTableRotate in 0 to 31 loop
         indexForTableStdTestRotate <= std_logic_vector(to_unsigned(indexForTableRotate, 5));
         for inputX in -5 to 5 loop
            for inputY in -5 to 5 loop
               sClock <= '0';
               wait for 500 ns;
               vInputPos := (inputX, inputY);
               sInputPos <= (inputX, inputY);
               vOutputPos := rotate(sprite_size, vInputPos, indexForTableStdTestRotate);
               sOutputPos <= rotate(sprite_size, sInputPos, indexForTableStdTestRotate);
               sClock <= '1';
               wait for 1 us;
            end loop;
         end loop;
      end loop;
      sSimulationActive <= false;
      wait;
   end process;

end testbench;
