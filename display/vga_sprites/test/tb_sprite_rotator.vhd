library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.definitions.all;
use work.trigonometric.all;

-- Checks sprite_rotator against the combinational `rotate` function it
-- pipelines.
--
-- One request enters per clock: every position of an 11x11 sprite
-- (-5..5 on each axis, origin at the centre) at each of the 32
-- rotation steps. Every fifth request is sent with inValid low. The
-- testbench keeps its own two-deep delay line of what `rotate`
-- returns, and on every clock asserts that
--
--   * outValid is inValid from two clocks earlier, and
--   * when it is high, outPosition equals rotate() of the position and
--     rotation presented two clocks earlier.
--
-- At the end it asserts that every valid request was actually checked.
entity tb_sprite_rotator is
end tb_sprite_rotator;

architecture testbench of tb_sprite_rotator is
   constant CLK_PERIOD : time := 20 ns;

   -- rotate() takes the sprite size but does not use it.
   constant SPRITE_SIZE : Size2D  := (11, 11);
   constant LIMIT       : integer := 5;

   signal tbClock       : std_logic := '0';
   signal tbValid       : boolean   := false;
   signal tbPosition    : Pos2D     := (0, 0);
   signal tbRotation    : std_logic_vector(4 downto 0) := (others => '0');
   signal tbOutValid    : boolean;
   signal tbOutPosition : Pos2D;

   -- Reference, delayed to line up with the DUT's two stages.
   signal tbRef1      : Pos2D   := (0, 0);
   signal tbRef2      : Pos2D   := (0, 0);
   signal tbRefValid1 : boolean := false;
   signal tbRefValid2 : boolean := false;

   signal tbSent    : integer := 0;   -- valid requests sent
   signal tbChecked : integer := 0;   -- valid results compared

   signal sSimulationActive : boolean := true;
begin

   tbClock <= not tbClock after CLK_PERIOD / 2 when sSimulationActive else '0';

   dut : entity work.sprite_rotator
      port map (
         inClock     => tbClock,
         inValid     => tbValid,
         inPosition  => tbPosition,
         inRotation  => tbRotation,
         outValid    => tbOutValid,
         outPosition => tbOutPosition
      );

   -- Just before each edge the DUT outputs belong to the request sampled
   -- two edges ago, which is what tbRef2 holds.
   check : process (tbClock)
   begin
      if rising_edge(tbClock) then
         tbRef1      <= rotate(SPRITE_SIZE, tbPosition, tbRotation);
         tbRefValid1 <= tbValid;
         tbRef2      <= tbRef1;
         tbRefValid2 <= tbRefValid1;

         assert tbOutValid = tbRefValid2
            report "outValid is not inValid delayed by two clocks"
            severity failure;
         if tbRefValid2 then
            assert tbOutPosition = tbRef2
               report "rotator output (" & integer'image(tbOutPosition.x) & ", "
                    & integer'image(tbOutPosition.y) & ") differs from rotate() ("
                    & integer'image(tbRef2.x) & ", " & integer'image(tbRef2.y) & ")"
               severity failure;
            tbChecked <= tbChecked + 1;
         end if;
      end if;
   end process;

   -- Inputs change on falling edges, clear of the edge the DUT samples.
   stim : process
      variable vRot   : integer := 0;
      variable vX     : integer := 0;
      variable vY     : integer := 0;
      variable vCount : integer := 0;
      variable vSent  : integer := 0;
   begin
      wait until falling_edge(tbClock);

      vRot := 0;
      while vRot < 32 loop
         vY := -LIMIT;
         while vY <= LIMIT loop
            vX := -LIMIT;
            while vX <= LIMIT loop
               tbRotation <= std_logic_vector(to_unsigned(vRot, 5));
               tbPosition <= (vX, vY);
               if vCount mod 5 = 4 then
                  tbValid <= false;
               else
                  tbValid <= true;
                  vSent   := vSent + 1;
               end if;
               vCount := vCount + 1;
               tbSent <= vSent;
               wait until falling_edge(tbClock);
               vX := vX + 1;
            end loop;
            vY := vY + 1;
         end loop;
         vRot := vRot + 1;
      end loop;

      -- Let the last requests drain through both stages.
      tbValid <= false;
      wait for 4 * CLK_PERIOD;

      assert tbChecked = tbSent
         report "checked " & integer'image(tbChecked) & " results for "
              & integer'image(tbSent) & " valid requests"
         severity failure;
      assert tbSent > 3000
         report "sweep sent too few requests" severity failure;

      report "sprite_rotator simulation done!" severity note;
      sSimulationActive <= false;
      wait;
   end process;

end testbench;
