library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.definitions.all;

-- Exercises the sprite entity with GRAVITY_ENABLED => true. The intent is
-- to confirm that enabling gravity compiles and simulates without error,
-- and to produce a waveform showing the velocity integration + bounce.
--
-- NOTE: unnamed_fpga_game's Makefile currently runs tb_trigonometric as
-- TB_TOP (single-testbench flow in mk/common.mk). This file is listed in
-- TB_FILES so it is analysed on every build as a compile-time check of
-- the gravity path; it is not simulated until mk/common.mk learns about
-- multiple testbenches (tracked as a follow-up).
entity tb_sprite_gravity is
end tb_sprite_gravity;

architecture testbench of tb_sprite_gravity is
   constant CLK_PERIOD : time := 20 ns; -- 50 MHz, matches the board's vga_clk

   signal tbClock       : std_logic := '0';
   signal tbCursorPos   : Pos2D     := (0, 0);
   signal tbShouldDraw  : boolean;
   signal tbRunning     : boolean := true;

begin

   -- Free-running clock while the stimulus process is active.
   tbClock <= not tbClock after CLK_PERIOD / 2 when tbRunning else '0';

   dut : entity work.sprite
      generic map (
         SCREEN_SIZE            => (60, 40),   -- small screen = fast bounces
         SPRITE_WIDTH           => 3,
         SCALE                  => 1,
         SPRITE_CONTENT         => "010"
                                 & "111"
                                 & "010",
         INITIAL_ROTATION       => 0,
         INITIAL_ROTATION_SPEED => (0, 0),     -- rotation off in this TB
         INITIAL_POSITION       => (30, 5),    -- near top of the screen
         -- update_period=20: position step every 20 clocks, small enough
         -- for the TB to observe several updates in a short simulated span.
         INITIAL_SPEED          => (0, 1, 20),
         GRAVITY_ENABLED        => true,
         -- y_increments=1 every 10 clock cycles: two gravity ticks per
         -- position update so the integration is visibly non-trivial.
         GRAVITY                => (1, 10)
      )
      port map (
         inClock       => tbClock,
         inEnabled     => true,
         inCursorPos   => tbCursorPos,
         inColision    => false,
         outShouldDraw => tbShouldDraw
      );

   -- Run a fixed simulated window long enough for the sprite to fall,
   -- hit the bottom edge, and bounce at least once.
   stim : process
   begin
      wait for 200 us;
      tbRunning <= false;
      wait;
   end process;

end testbench;
