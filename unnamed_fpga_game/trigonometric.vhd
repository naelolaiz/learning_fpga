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

     function multiplyBySinLUT(index      : std_logic_vector(4 downto 0);
                               inputValue : std_logic_vector(7 downto 0))  -- limited to 255 max value of input
                               return  std_logic_vector; -- signed integer

     function multiplyByCosLUT(index      : std_logic_vector(4 downto 0);
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

end package;



package body trigonometric is
     function multiplyBySinLUT(index      : std_logic_vector(4 downto 0); -- 32 samples (instead of the 16 I was using)
                               inputValue : std_logic_vector(7 downto 0))  -- limited to 255 max value of input
                               return std_logic_vector -- signed integer
                               is
        constant sinIsNegative : boolean := index(4) = '1';
        constant indexForTable : std_logic_vector(3 downto 0) := std_logic_vector(to_unsigned(abs(to_integer(signed(index))), 4));
        alias mostSignificativeNibble is inputValue (7 downto 4);
        alias lessSignificativeNibble is inputValue (3 downto 0);
        variable op   : std_logic_vector (7 downto 0)  := (others => '0');
        variable sum  : std_logic_vector (15 downto 0) := (others => '0');
     begin
        if inputValue =  "0000"  then
           sum := (others=> '0');
        elsif indexForTable = "0001" then
           sum := (others => '0') & inputValue;
        else 
           op := MULTIPLICATION_TABLES_FOR_POSITIVE_SIN(to_integer(signed(indexForTable)))(to_integer(signed(lessSignificativeNibble)));
           sum (11 downto 4) := MULTIPLICATION_TABLES_FOR_POSITIVE_SIN(to_integer(signed(indexForTable)))(to_integer(signed(mostSignificativeNibble)));
           sum := std_logic_vector(unsigned(sum) + unsigned(op))(16 downto 1); -- lets use the MSB for the sign...
           if sinIsNegative then
              sum := std_logic_vector(to_signed(-1 * to_integer(signed(sum)), 16)); -- flip the sign if needed
           end if;
        end if;
        return sum;
     end function;

     function multiplyByCosLUT(index      : std_logic_vector(4 downto 0); -- 32 samples (instead of the 16 I was using)
                               inputValue : std_logic_vector(7 downto 0))  -- limited to 255 max value of input
                               return std_logic_vector -- signed integer
                               is
         constant indexForCos : std_logic_vector (4 downto 0) := std_logic_vector((unsigned(index) + 8) mod 32);
     begin
        return multiplyBySinLUT(indexForCos, inputValue);
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
