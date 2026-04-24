library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.definitions.all;

-- Exercises the sprite entity with GRAVITY_ENABLED => true.
--
-- Rather than probe the sprite's internal position/velocity (which
-- would require VHDL-2008 external names or exposing private state),
-- the TB asserts the gravity effect through the sprite's public
-- `outShouldDraw` port using a cause-effect pattern:
--
--   1. Place the cursor on the sprite's initial center. `outShouldDraw`
--      should go high (pixel inside sprite).
--   2. Wait long enough for gravity to accumulate enough downward
--      velocity that the sprite moves strictly below the original
--      center. `outShouldDraw` at the original center should now be
--      low — the sprite has fallen out of that pixel.
--
-- This is deliberately coarse (one before/after check instead of a
-- continuous trajectory), but any regression in the gravity path —
-- the record being ignored, the velocity accumulator not
-- incrementing, the position update not firing — fails step 2.
entity tb_sprite_gravity is
end tb_sprite_gravity;

architecture testbench of tb_sprite_gravity is
   constant CLK_PERIOD : time := 20 ns; -- 50 MHz, matches the board's vga_clk

   -- Small screen + minimal sprite so the TB runs fast and a few
   -- gravity ticks move the sprite visibly.
   constant SCREEN      : Size2D := (60, 40);
   constant INIT_CENTER : Pos2D  := (30, 8);

   signal tbClock       : std_logic := '0';
   signal tbCursorPos   : Pos2D     := (0, 0);
   signal tbShouldDraw  : boolean;
   signal tbRunning     : boolean := true;
   signal tbStage       : integer := 0;

begin

   -- Free-running clock while the stimulus process is active.
   tbClock <= not tbClock after CLK_PERIOD / 2 when tbRunning else '0';

   dut : entity work.sprite
      generic map (
         SCREEN_SIZE            => SCREEN,
         SPRITE_WIDTH           => 3,
         SCALE                  => 1,
         SPRITE_CONTENT         => "010"
                                 & "111"
                                 & "010",
         INITIAL_ROTATION       => 0,
         INITIAL_ROTATION_SPEED => (0, 0),     -- rotation off for this TB
         INITIAL_POSITION       => INIT_CENTER,
         -- update_period=20: position step every 20 clocks. Short so
         -- the TB observes several updates in < 1 ms of sim time.
         INITIAL_SPEED          => (0, 0, 20),
         GRAVITY_ENABLED        => true,
         -- y_increments=1 every 10 clock cycles -> two gravity ticks
         -- per position update, so velocity accumulates visibly fast.
         GRAVITY                => (1, 10)
      )
      port map (
         inClock       => tbClock,
         inEnabled     => true,
         inCursorPos   => tbCursorPos,
         inColision    => false,
         outShouldDraw => tbShouldDraw
      );

   stim : process
   begin
      -- Stage 1: cursor on the sprite's initial center.
      -- outShouldDraw should be high (center pixel of the sprite
      -- pattern is '1'). Allow a few clocks for the registered
      -- `ProcessPosition` to settle.
      tbStage     <= 1;
      tbCursorPos <= INIT_CENTER;
      wait for 10 * CLK_PERIOD;
      assert tbShouldDraw = true
         report "gravity TB stage 1: cursor at sprite center should draw,"
              & " but outShouldDraw is false (sprite missing at t=0?)"
         severity failure;

      -- Stage 2: wait for gravity to pull the sprite clear of the
      -- original pixel. With GRAVITY = (1, 10) on a 50 MHz clock and
      -- INITIAL_SPEED.update_period = 20, velocity reaches +2 after
      -- ~40 position updates (~800 clocks), then one more update
      -- shifts y past the half-height of the 3x3 sprite. 300 us of
      -- sim time is plenty.
      tbStage <= 2;
      wait for 300 us;

      tbCursorPos <= INIT_CENTER;   -- re-sample the original center
      wait for 4 * CLK_PERIOD;      -- registered input + one position step
      assert tbShouldDraw = false
         report "gravity TB stage 2: sprite has not moved off the original"
              & " center after 300 us -- gravity path regressed?"
         severity failure;

      tbStage <= 99;
      wait for 2 * CLK_PERIOD;
      tbRunning <= false;
      wait;
   end process;

end testbench;
