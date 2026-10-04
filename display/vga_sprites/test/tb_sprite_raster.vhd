library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.definitions.all;
use work.trigonometric.all;

-- Scans a whole small screen past a rotated, stationary sprite and
-- compares every pixel with a reference computed in one step.
--
-- The sprite answers "draw this pixel?" three clocks after the cursor
-- is presented (see ProcessPosition in sprite.vhd). The reference
-- function below does the same arithmetic between two clock edges —
-- bounding box, scale, centre, the combinational `rotate`, content
-- lookup — and the testbench delays its answer by three clocks before
-- comparing. So the test pins down both the picture and the latency:
-- a pipeline stage that slips, or x / y crossed on the way through the
-- rotator, shows up as a pixel mismatch.
--
-- The sprite is an "F": no rotation or mirroring maps it onto itself,
-- so an image drawn upside down or mirrored fails too. It does not
-- move (speed 0) and its rotation is fixed (rotation speed 0), which
-- keeps the reference a pure function of the cursor.
entity tb_sprite_raster is
end tb_sprite_raster;

architecture testbench of tb_sprite_raster is
   constant CLK_PERIOD : time := 20 ns;

   constant SCREEN   : Size2D  := (48, 36);
   constant CENTER   : Pos2D   := (24, 18);
   constant WIDTH    : integer := 5;
   constant HEIGHT   : integer := 5;
   constant SCALE    : integer := 3;
   constant ROTATION : integer := 3;       -- 3/32 of a turn
   constant LATENCY  : integer := 3;

   -- Row by row, top row first, leftmost pixel first.
   constant CONTENT : string(1 to WIDTH * HEIGHT) := "11111"
                                                   & "10000"
                                                   & "11100"
                                                   & "10000"
                                                   & "10000";

   constant SPRITE_SIZE : Size2D  := (WIDTH, HEIGHT);
   constant HALF_W      : integer := WIDTH  * SCALE / 2;
   constant HALF_H      : integer := HEIGHT * SCALE / 2;

   -- What the sprite should answer for a cursor position.
   function expectedDraw (cursor : Pos2D) return boolean is
      variable p : Pos2D;
   begin
      if   cursor.x < CENTER.x - HALF_W or cursor.x > CENTER.x + HALF_W
        or cursor.y < CENTER.y - HALF_H or cursor.y > CENTER.y + HALF_H then
         return false;
      end if;
      p := ((cursor.x - (CENTER.x - HALF_W)) / SCALE,
            (cursor.y - (CENTER.y - HALF_H)) / SCALE);
      p := translateOriginToCenterOfSprite(SPRITE_SIZE, p);
      p := rotate(SPRITE_SIZE, p, std_logic_vector(to_unsigned(ROTATION, 5)));
      p := translateOriginBackToFirstBitCorner(SPRITE_SIZE, p);
      if p.x < 0 or p.x > WIDTH - 1 or p.y < 0 or p.y > HEIGHT - 1 then
         return false;
      end if;
      return CONTENT(p.y * WIDTH + p.x + 1) = '1';
   end function;

   type boolean_vector_t is array (1 to LATENCY) of boolean;

   signal tbClock      : std_logic := '0';
   signal tbCursorPos  : Pos2D     := (0, 0);
   signal tbScanning   : boolean   := false;
   signal tbShouldDraw : boolean;

   -- Reference answers and "this slot holds a scanned pixel" flags,
   -- delayed to line up with the sprite's output.
   signal tbExpected : boolean_vector_t := (others => false);
   signal tbArmed    : boolean_vector_t := (others => false);

   signal tbChecked : integer := 0;   -- pixels compared
   signal tbDrawn   : integer := 0;   -- of those, pixels drawn

   signal sSimulationActive : boolean := true;
begin

   tbClock <= not tbClock after CLK_PERIOD / 2 when sSimulationActive else '0';

   dut : entity work.sprite
      generic map (
         SCREEN_SIZE            => SCREEN,
         SPRITE_WIDTH           => WIDTH,
         SCALE                  => SCALE,
         SPRITE_CONTENT         => "11111"
                                 & "10000"
                                 & "11100"
                                 & "10000"
                                 & "10000",
         INITIAL_ROTATION       => ROTATION,
         INITIAL_ROTATION_SPEED => (0, 0),       -- hold the rotation
         INITIAL_POSITION       => CENTER,
         INITIAL_SPEED          => (0, 0, 1000)  -- stand still
      )
      port map (
         inClock       => tbClock,
         inEnabled     => true,
         inCursorPos   => tbCursorPos,
         inColision    => false,
         outShouldDraw => tbShouldDraw
      );

   -- Just before each edge, outShouldDraw belongs to the cursor sampled
   -- LATENCY edges ago, which is what the last delay slot holds.
   check : process (tbClock)
   begin
      if rising_edge(tbClock) then
         tbExpected <= expectedDraw(tbCursorPos) & tbExpected(1 to LATENCY - 1);
         tbArmed    <= tbScanning                & tbArmed(1 to LATENCY - 1);

         if tbArmed(LATENCY) then
            assert tbShouldDraw = tbExpected(LATENCY)
               report "pixel mismatch " & integer'image(tbChecked)
                    & " pixels into the scan: sprite says "
                    & boolean'image(tbShouldDraw) & ", reference says "
                    & boolean'image(tbExpected(LATENCY))
               severity failure;
            tbChecked <= tbChecked + 1;
            if tbShouldDraw then
               tbDrawn <= tbDrawn + 1;
            end if;
         end if;
      end if;
   end process;

   -- The cursor moves on falling edges, clear of the edge the sprite
   -- samples on, one pixel per clock in raster order.
   stim : process
      variable vX : integer := 0;
      variable vY : integer := 0;
   begin
      -- Let the sprite latch its position before scanning.
      wait for 4 * CLK_PERIOD;
      wait until falling_edge(tbClock);

      vY := 0;
      while vY < SCREEN.height loop
         vX := 0;
         while vX < SCREEN.width loop
            tbCursorPos <= (vX, vY);
            tbScanning  <= true;
            wait until falling_edge(tbClock);
            vX := vX + 1;
         end loop;
         vY := vY + 1;
      end loop;
      tbScanning <= false;

      -- Drain the pipeline.
      wait for (LATENCY + 2) * CLK_PERIOD;

      assert tbChecked = SCREEN.width * SCREEN.height
         report "compared " & integer'image(tbChecked) & " pixels, expected "
              & integer'image(SCREEN.width * SCREEN.height)
         severity failure;
      -- The F has 11 pixels at SCALE 3, so about 99 screen pixels; a
      -- blank or solid image would also "match" a broken reference.
      assert tbDrawn > 40 and tbDrawn < 140
         report "implausible number of drawn pixels: " & integer'image(tbDrawn)
         severity failure;

      report "sprite raster simulation done!" severity note;
      sSimulationActive <= false;
      wait;
   end process;

end testbench;
