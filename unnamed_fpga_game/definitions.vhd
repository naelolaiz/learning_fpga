library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.ALL;

library ieee_proposed;
use ieee_proposed.fixed_pkg.all;


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

   subtype AngleType                    is ufixed (2 downto -5); -- unsigned q3.5 for angle (enough for 0..2*PI)

   type RotationSpeed is
   record
      --angle_inc: AngleType; -- TODO!
      index_inc : integer;
      update_period : integer;
   end record;

   type Size2D is
   record
      width  : integer;
      height : integer;
   end record;

end package;

package body definitions is
end definitions;
