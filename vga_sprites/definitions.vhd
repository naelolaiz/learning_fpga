library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.ALL;

package definitions is

   type Pos2D is
   record
      x: integer;
      y: integer;
   end record;

   type Speed2D is
   record
      x: integer;
      y: integer;
      update_period : integer;
   end record;

   type RotationSpeed is
   record
      index_inc : integer;
      update_period : integer;
   end record;

   type Size2D is
   record
      width  : integer;
      height : integer;
   end record;

   -- Downward acceleration applied to a sprite's y-velocity.
   -- `y_increments` is added to speed.y every `update_period` clock ticks.
   -- A sprite with GRAVITY_ENABLED=false ignores this record entirely.
   type GravityAcceleration is
   record
      y_increments  : integer;
      update_period : integer;
   end record;

end package;

package body definitions is
end definitions;
