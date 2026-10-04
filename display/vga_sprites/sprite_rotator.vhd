-- sprite_rotator.vhd
--
-- Pipelined version of the `rotate` function in trigonometric.vhd:
--
--   x' = cos(r)*x - sin(r)*y
--   y' = sin(r)*x + cos(r)*y
--
-- `rotate` does all of that between two clock edges. Here the work is
-- split over two registers, so the longest path is one LUT multiply
-- instead of a multiply plus an add:
--
--   stage 1   the four products cos*x, sin*y, sin*x, cos*y
--   stage 2   the two sums
--
-- outPosition / outValid therefore lag inPosition / inValid by two
-- clocks. A new request can enter every clock; inValid simply travels
-- with its data so the user knows which outputs are real.
--
-- The block knows nothing about the sprite it serves: positions are
-- relative to the centre of rotation and each axis must fit in a
-- signed byte (-128 .. 127), the range of multiplyBySinLUT. Keeping
-- sprite size and screen position out is what lets one rotator be
-- shared by several sprites.

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.definitions.all;
use work.trigonometric.all;

entity sprite_rotator is
   port( inClock     : in  std_logic;
         inValid     : in  boolean;
         inPosition  : in  Pos2D;                        -- centre-relative
         inRotation  : in  std_logic_vector(4 downto 0); -- 32 steps per turn
         outValid    : out boolean;
         outPosition : out Pos2D);
end;

architecture logic of sprite_rotator is
   -- Stage 1 registers.
   signal sCosX   : signed(7 downto 0) := (others => '0');
   signal sSinY   : signed(7 downto 0) := (others => '0');
   signal sSinX   : signed(7 downto 0) := (others => '0');
   signal sCosY   : signed(7 downto 0) := (others => '0');
   signal sValid1 : boolean := false;

   -- Stage 2 registers.
   signal sPosition : Pos2D   := (0, 0);
   signal sValid2   : boolean := false;
begin

   process (inClock)
      variable vX : std_logic_vector(7 downto 0);
      variable vY : std_logic_vector(7 downto 0);
   begin
      if rising_edge(inClock) then
         -- Stage 1: multiply.
         vX := std_logic_vector(to_signed(inPosition.x, 8));
         vY := std_logic_vector(to_signed(inPosition.y, 8));
         sCosX   <= signed(multiplyByCosLUT(inRotation, vX));
         sSinY   <= signed(multiplyBySinLUT(inRotation, vY));
         sSinX   <= signed(multiplyBySinLUT(inRotation, vX));
         sCosY   <= signed(multiplyByCosLUT(inRotation, vY));
         sValid1 <= inValid;

         -- Stage 2: add.
         sPosition <= (to_integer(sCosX) - to_integer(sSinY),
                       to_integer(sSinX) + to_integer(sCosY));
         sValid2   <= sValid1;
      end if;
   end process;

   outPosition <= sPosition;
   outValid    <= sValid2;

end logic;
