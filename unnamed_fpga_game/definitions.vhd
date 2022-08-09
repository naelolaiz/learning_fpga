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

   subtype TrigFunctionSFixedResultType is sfixed (1 downto -6); -- signed q2.6 for results of sin and cos

   type TrigonometricFunctionsResultsRecord is
   record
       sin   : TrigFunctionSFixedResultType; -- signed q2.6 (2. including sign) for sin result
       cos   : TrigFunctionSFixedResultType; -- signed q2.6 for cos result
   end record;


   type TrigonometricFunctionsRecord is
   record
       angle                 : AngleType;
       trigonometric_results : TrigonometricFunctionsResultsRecord;
   end record;

   type TrigonometricFunctionsTableType is array (natural range <>) of TrigonometricFunctionsRecord;

   constant TRIGONOMETRIC_FUNCTIONS_TABLE : TrigonometricFunctionsTableType := (
     (to_ufixed(0.0, 2, -5),      (to_sfixed( 0.0, 1, -6),         to_sfixed(  1.0, 1, -6))),
     (to_ufixed(0.392699, 2, -5), (to_sfixed( 0.382683, 1, -6),    to_sfixed(  0.923879, 1, -6))),
     (to_ufixed(0.785398, 2, -5), (to_sfixed( 0.707106, 1, -6),    to_sfixed(  0.707106, 1, -6))),
     (to_ufixed(1.178097, 2, -5), (to_sfixed( 0.923879, 1, -6),    to_sfixed(  0.382683, 1, -6))),
     (to_ufixed(1.570796, 2, -5), (to_sfixed( 1.0, 1, -6),         to_sfixed(  0.0, 1, -6))),
     (to_ufixed(1.963495, 2, -5), (to_sfixed( 0.923879, 1, -6),    to_sfixed( -0.382683, 1, -6))),
     (to_ufixed(2.356194, 2, -5), (to_sfixed( 0.707106, 1, -6),    to_sfixed( -0.707106, 1, -6))),
     (to_ufixed(2.748893, 2, -5), (to_sfixed( 0.382683, 1, -6),    to_sfixed( -0.923879, 1, -6))),
     (to_ufixed(3.141592, 2, -5), (to_sfixed( 0.0, 1, -6),         to_sfixed( -1.0, 1, -6))),
     (to_ufixed(3.534291, 2, -5), (to_sfixed(-0.382683, 1, -6),    to_sfixed( -0.923879, 1, -6))),
     (to_ufixed(3.926990, 2, -5), (to_sfixed(-0.707106, 1, -6),    to_sfixed( -0.707106, 1, -6))),
     (to_ufixed(4.319689, 2, -5), (to_sfixed(-0.923879, 1, -6),    to_sfixed( -0.382683, 1, -6))),
     (to_ufixed(4.712388, 2, -5), (to_sfixed(-1.0, 1, -6),         to_sfixed(  0.0, 1, -6))),
     (to_ufixed(5.105088, 2, -5), (to_sfixed(-0.923879, 1, -6),    to_sfixed(  0.382683, 1, -6))),
     (to_ufixed(5.497787, 2, -5), (to_sfixed(-0.707106, 1, -6),    to_sfixed(  0.707106, 1, -6))),
     (to_ufixed(5.890486, 2, -5), (to_sfixed(-0.382683, 1, -6),    to_sfixed(  0.923879, 1, -6)))
     );

     function translateOriginToCenterOfSprite (sprite_size  : Size2D;
                                              position      : Pos2D) 
              return Pos2D;

     function translateOriginBackToFirstBitCorner(sprite_size   : Size2D;
                                                  position      : Pos2D)
              return Pos2D;

     function getTrigonometricFunctionsResult(angle : AngleType)
              return TrigonometricFunctionsResultsRecord;

     function rotate(sprite_size : Size2D;
                     position    : Pos2D;
                     rotation    : AngleType := ( others => '0' ))
              return Pos2D;

-- created with python:
-- import math
-- table_size = 16
-- # first element (integer) includes sign.
-- angle_q_size = (3,5)
-- output_q_size = (2,6)
-- float_angles = [ 2 * math.pi * t / table_size for t in range(table_size) ]
-- sinTable     = [ round(math.sin(angle) * (2**output_q_size[1])) for angle in float_angles ]
-- cosTable     = [ round(math.cos(angle) * (2**output_q_size[1])) for angle in float_angles ]
-- q_angles     = [ round(angle * (2**angle_q_size[1])) for angle in float_angles ]
-- print list(zip(q_angles, sinTable, cosTable))

 -- import math
 -- table_size = 16
 -- float_angles = [ 2 * math.pi * t / table_size for t in range(table_size) ]
 -- sinTable=[math.sin(angle) for angle in float_angles]
 -- cosTable=[math.cos(angle) for angle in float_angles]
 -- print(list(zip(float_angles,sinTable,cosTable)))
 -- [(0.0, 0.0, 1.0), (0.39269908169872414, 0.3826834323650898, 0.9238795325112867), (0.7853981633974483, 0.7071067811865475, 0.7071067811865476), (1.1780972450961724, 0.9238795325112867, 0.38268343236508984), (1.5707963267948966, 1.0, 6.123233995736766e-17), (1.9634954084936207, 0.9238795325112867, -0.3826834323650897), (2.356194490192345, 0.7071067811865476, -0.7071067811865475), (2.748893571891069, 0.3826834323650899, -0.9238795325112867), (3.141592653589793, 1.2246467991473532e-16, -1.0), (3.5342917352885173, -0.38268343236508967, -0.9238795325112868), (3.9269908169872414, -0.7071067811865475, -0.7071067811865477), (4.319689898685965, -0.9238795325112865, -0.38268343236509034), (4.71238898038469, -1.0, -1.8369701987210297e-16), (5.105088062083414, -0.9238795325112866, 0.38268343236509), (5.497787143782138, -0.7071067811865477, 0.7071067811865474), (5.890486225480862, -0.3826834323650904, 0.9238795325112865)]

end package;



package body definitions is
     function translateOriginToCenterOfSprite(sprite_size   : Size2D;
                                              position      : Pos2D)
                                              return Pos2D is
       constant HALF_SPRITE_WIDTH  : integer := sprite_size.width  / 2;
       constant HALF_SPRITE_HEIGHT : integer := sprite_size.height / 2;
     begin
       return (position.x - HALF_SPRITE_WIDTH,
               position.y - HALF_SPRITE_HEIGHT);
     end function;

     function translateOriginBackToFirstBitCorner(sprite_size   : Size2D;
                                                  position      : Pos2D)
                                                  return Pos2D is
                                                  
        constant HALF_SPRITE_WIDTH  : integer := sprite_size.width  / 2;
        constant HALF_SPRITE_HEIGHT : integer := sprite_size.height / 2;
     begin
        return (position.x + HALF_SPRITE_WIDTH,
                position.y + HALF_SPRITE_HEIGHT);
     end function;


     function getTrigonometricFunctionsResult(angle : AngleType)
              return TrigonometricFunctionsResultsRecord is
        variable currentAngleInTable : AngleType := (others => '0');
     begin
        for i in TRIGONOMETRIC_FUNCTIONS_TABLE'range loop
        -- first dummy approach. TODO: improve to return nearest value in table instead
           currentAngleInTable := TRIGONOMETRIC_FUNCTIONS_TABLE(i).angle;
           if currentAngleInTable >= angle then
               return TRIGONOMETRIC_FUNCTIONS_TABLE(i).trigonometric_results;
           end if;
        end loop;
        return ((others=>'0'), (others=>'0'));
     end function; 


     function rotate(sprite_size : Size2D;
                     position    : Pos2D;
                     rotation    : AngleType := ( others => '0' )) return Pos2D is
        constant trigResults  : TrigonometricFunctionsResultsRecord := getTrigonometricFunctionsResult(rotation);
        variable newPos : Pos2D;
     begin
       -- reinterpret  as sfixed
        newPos.x :=   (position.x * to_integer(signed(to_slv(trigResults.cos))) 
                    - (position.y * to_integer(signed(to_slv(trigResults.sin))))) / 64;
        newPos.y :=   ((position.x * to_integer(signed(to_slv(trigResults.sin)))) 
                    + (position.y * to_integer(signed(to_slv(trigResults.cos))))) / 64;
        return newPos;
     end function;
    
end definitions;
