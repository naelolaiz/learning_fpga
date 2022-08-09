library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.ALL;

library ieee_proposed;
use ieee_proposed.fixed_pkg.all;

library work;
use work.definitions.all;

package trigonometric is

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


     --  -- we skip 0 and 1 since they are trivial
     type MULTIPLICATION_TABLE_FOR_TRIG_FUNCTION_RESULT is array (2 to 15) of std_logic_vector (7 downto 0);
     type MULTIPLICATIONS_TABLES_TABLE_TYPE is array (0 to 15) of MULTIPLICATION_TABLE_FOR_TRIG_FUNCTION_RESULT;

     constant MULTIPLICATION_TABLES_FOR_POSITIVE_SIN : MULTIPLICATIONS_TABLES_TABLE_TYPE := -- until PI
(("00000000", "00000000", "00000000", "00000000", "00000000", "00000000", "00000000", "00000000", "00000000", "00000000", "00000000", "00000000", "00000000", "00000000"),
 ("00000110", "00001001", "00001100", "00001111", "00010010", "00010101", "00011000", "00011011", "00011110", "00100001", "00100100", "00100111", "00101010", "00101101"),
 ("00001100", "00010010", "00011000", "00011110", "00100100", "00101010", "00110000", "00110110", "00111100", "01000010", "01001000", "01001110", "01010100", "01011010"),
 ("00010010", "00011011", "00100100", "00101101", "00110110", "00111111", "01001000", "01010001", "01011010", "01100011", "01101100", "01110101", "01111110", "10000111"),
 ("00010110", "00100001", "00101100", "00110111", "01000010", "01001101", "01011000", "01100011", "01101110", "01111001", "10000100", "10001111", "10011010", "10100101"),
 ("00011010", "00100111", "00110100", "01000001", "01001110", "01011011", "01101000", "01110101", "10000010", "10001111", "10011100", "10101001", "10110110", "11000011"),
 ("00011110", "00101101", "00111100", "01001011", "01011010", "01101001", "01111000", "10000111", "10010110", "10100101", "10110100", "11000011", "11010010", "11100001"),
 ("00100000", "00110000", "01000000", "01010000", "01100000", "01110000", "10000000", "10010000", "10100000", "10110000", "11000000", "11010000", "11100000", "11110000"),
 ("00100000", "00110000", "01000000", "01010000", "01100000", "01110000", "10000000", "10010000", "10100000", "10110000", "11000000", "11010000", "11100000", "11110000"),
 ("00100000", "00110000", "01000000", "01010000", "01100000", "01110000", "10000000", "10010000", "10100000", "10110000", "11000000", "11010000", "11100000", "11110000"),
 ("00011110", "00101101", "00111100", "01001011", "01011010", "01101001", "01111000", "10000111", "10010110", "10100101", "10110100", "11000011", "11010010", "11100001"),
 ("00011010", "00100111", "00110100", "01000001", "01001110", "01011011", "01101000", "01110101", "10000010", "10001111", "10011100", "10101001", "10110110", "11000011"),
 ("00010110", "00100001", "00101100", "00110111", "01000010", "01001101", "01011000", "01100011", "01101110", "01111001", "10000100", "10001111", "10011010", "10100101"),
 ("00010010", "00011011", "00100100", "00101101", "00110110", "00111111", "01001000", "01010001", "01011010", "01100011", "01101100", "01110101", "01111110", "10000111"),
 ("00001100", "00010010", "00011000", "00011110", "00100100", "00101010", "00110000", "00110110", "00111100", "01000010", "01001000", "01001110", "01010100", "01011010"),
 ("00000110", "00001001", "00001100", "00001111", "00010010", "00010101", "00011000", "00011011", "00011110", "00100001", "00100100", "00100111", "00101010", "00101101"));




     
     --  -- we skip 0 and 1 since they are trivial
     --  type MULTIPLICATION_TABLE_FOR_TRIG_FUNCTION_RESULT is array (2 to 15) of std_logic_vector (3 downto 0);
     --  type MULTIPLICATIONS_TABLES_TABLE_TYPE is array (0 to 15) of MULTIPLICATION_TABLE_FOR_TRIG_FUNCTION_RESULT;

     --  -- 16 tables of multiplication tables for hexadecimal numbers (nibbles). TODO: optimize: sin(0), sin(pi/2,...)
     --  constant MULTIPLICATION_TABLE_FOR_SIN_RESULTS :  MULTIPLICATIONS_TABLES_TABLE_TYPE := (
     --             ('00000', '00000', '00000', '00000', '00000', '00000', '00000', '00000', '00000', '00000', '00000', '00000', '00000', '00000'),
     --             ('00001', '00001', '00010', '00010', '00010', '00011', '00011', '00011', '00100', '00100', '00101', '00101', '00101', '00110'),
     --             ('00001', '00010', '00011', '00100', '00100', '00101', '00110', '00110', '00111', '01000', '01000', '01001', '01010', '01011'),
     --             ('00010', '00011', '00100', '00101', '00110', '00110', '00111', '01000', '01001', '01010', '01011', '01100', '01101', '01110'),
     --             ('00010', '00011', '00100', '00101', '00110', '00111', '01000', '01001', '01010', '01011', '01100', '01101', '01110', '01111'),
     --             ('00010', '00011', '00100', '00101', '00110', '00110', '00111', '01000', '01001', '01010', '01011', '01100', '01101', '01110'),
     --             ('00001', '00010', '00011', '00100', '00100', '00101', '00110', '00110', '00111', '01000', '01000', '01001', '01010', '01011'),
     --             ('00001', '00001', '00010', '00010', '00010', '00011', '00011', '00011', '00100', '00100', '00101', '00101', '00101', '00110'),
     --             ('00000', '00000', '00000', '00000', '00000', '00000', '00000', '00000', '00000', '00000', '00000', '00000', '00000', '00000'),
     --             ('11111', '11111', '11110', '11110', '11110', '11101', '11101', '11101', '11100', '11100', '11011', '11011', '11011', '11010'),
     --             ('11111', '11110', '11101', '11100', '11100', '11011', '11010', '11010', '11001', '11000', '11000', '10111', '10110', '10101'),
     --             ('11110', '11101', '11100', '11011', '11010', '11010', '11001', '11000', '10111', '10110', '10101', '10100', '10011', '10010'),
     --             ('11110', '11101', '11100', '11011', '11010', '11001', '11000', '10111', '10110', '10101', '10100', '10011', '10010', '10001'),
     --             ('11110', '11101', '11100', '11011', '11010', '11010', '11001', '11000', '10111', '10110', '10101', '10100', '10011', '10010'),
     --             ('11111', '11110', '11101', '11100', '11100', '11011', '11010', '11010', '11001', '11000', '11000', '10111', '10110', '10101'),
     --             ('11111', '11111', '11110', '11110', '11110', '11101', '11101', '11101', '11100', '11100', '11011', '11011', '11011', '11010')
     --  );


     --  constant MULTIPLICATION_TABLE_FOR_COS_RESULTS : MULTIPLICATIONS_TABLES_TABLE_TYPE := (
     --             ('00010', '00011', '00100', '00101', '00110', '00111', '01000', '01001', '01010', '01011', '01100', '01101', '01110', '01111'),
     --             ('00010', '00011', '00100', '00101', '00110', '00110', '00111', '01000', '01001', '01010', '01011', '01100', '01101', '01110'),
     --             ('00001', '00010', '00011', '00100', '00100', '00101', '00110', '00110', '00111', '01000', '01000', '01001', '01010', '01011'),
     --             ('00001', '00001', '00010', '00010', '00010', '00011', '00011', '00011', '00100', '00100', '00101', '00101', '00101', '00110'),
     --             ('00000', '00000', '00000', '00000', '00000', '00000', '00000', '00000', '00000', '00000', '00000', '00000', '00000', '00000'),
     --             ('11111', '11111', '11110', '11110', '11110', '11101', '11101', '11101', '11100', '11100', '11011', '11011', '11011', '11010'),
     --             ('11111', '11110', '11101', '11100', '11100', '11011', '11010', '11010', '11001', '11000', '11000', '10111', '10110', '10101'),
     --             ('11110', '11101', '11100', '11011', '11010', '11010', '11001', '11000', '10111', '10110', '10101', '10100', '10011', '10010'),
     --             ('11110', '11101', '11100', '11011', '11010', '11001', '11000', '10111', '10110', '10101', '10100', '10011', '10010', '10001'),
     --             ('11110', '11101', '11100', '11011', '11010', '11010', '11001', '11000', '10111', '10110', '10101', '10100', '10011', '10010'),
     --             ('11111', '11110', '11101', '11100', '11100', '11011', '11010', '11010', '11001', '11000', '11000', '10111', '10110', '10101'),
     --             ('11111', '11111', '11110', '11110', '11110', '11101', '11101', '11101', '11100', '11100', '11011', '11011', '11011', '11010'),
     --             ('00000', '00000', '00000', '00000', '00000', '00000', '00000', '00000', '00000', '00000', '00000', '00000', '00000', '00000'),
     --             ('00001', '00001', '00010', '00010', '00010', '00011', '00011', '00011', '00100', '00100', '00101', '00101', '00101', '00110'),
     --             ('00001', '00010', '00011', '00100', '00100', '00101', '00110', '00110', '00111', '01000', '01000', '01001', '01010', '01011'),
     --             ('00010', '00011', '00100', '00101', '00110', '00110', '00111', '01000', '01001', '01010', '01011', '01100', '01101', '01110')
     --  );


     function multiplyBySinLUT(index      : std_logic_vector(3 downto 0);
                               inputValue : std_logic_vector(7 downto 0))  -- limited to 255 max value of input
                               return  std_logic_vector; -- signed integer

     function getTrigonometricFunctionsResult(angle : AngleType)
              return TrigonometricFunctionsResultsRecord;

     function translateOriginToCenterOfSprite (sprite_size  : Size2D;
                                              position      : Pos2D) 
              return Pos2D;

     function translateOriginBackToFirstBitCorner(sprite_size   : Size2D;
                                                  position      : Pos2D)
              return Pos2D;

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



package body trigonometric is


     function multiplyBySinLUT(index      : std_logic_vector(3 downto 0);
                               inputValue : std_logic_vector(7 downto 0))  -- limited to 255 max value of input
                               return std_logic_vector -- signed integer
                               is
     begin
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
    
end trigonometric;
