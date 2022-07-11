-- Pixel_On_Text_WithSize determines if the current pixel is on text
-- param:
--   textlength, use to init the string
-- input: 
--   VGA clock(the clk you used to update VGA)
--   display text
--   top left corner of the text box
--   current X and Y position
-- output:
--   a bit that represent whether is the pixel in text

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx primitives in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

-- note this line.The package is compiled to this directory by default.
-- so don't forget to include this directory. 
library work;
-- this line also is must.This includes the particular package into your program.
use work.commonPak.all;

entity Pixel_On_Text_WithSize is
	generic(
	   -- needed for init displayText, the default value 11 is just a random number
       textLength: integer := 11;
       fontScale: integer := 1;
       xForward: boolean := true;
       yForward: boolean := true;
       textDirection: text_direction := RightToLeft
	);
	port (
		clk: in std_logic;
		displayText: in string (1 to textLength) := (others => NUL);
		-- top left corner of the text
		position: in point_2d := (0, 0);
		-- current pixel postion
		horzCoord: in integer;
		vertCoord: in integer;
		
		pixel: out std_logic := '0'
	);

end Pixel_On_Text_WithSize;

architecture Behavioral of Pixel_On_Text_WithSize is
   constant FONT_WIDTH_SCALED: integer := FONT_WIDTH * fontScale;
   constant FONT_HEIGHT_SCALED: integer := FONT_HEIGHT * fontScale;

   signal translatedHorzCoord: integer :=0;
   signal translatedVertCoord: integer :=0;

begin
   translatedHorzCoord <= (horzCoord - position.x) / fontScale when xForward 
                      else (textLength * FONT_WIDTH)-((horzCoord - position.x) / fontScale);
   translatedVertCoord <= (vertCoord - position.y) / fontScale when yForward
                          else FONT_HEIGHT- ((vertCoord - position.y) /fontScale);

unscaledPixelOnText: entity  work.Pixel_On_Text
generic map (textLength => textLength)
port map (clk => clk,
      displayText => displayText,
      position => (0,0),
      horzCoord => translatedHorzCoord,
      vertCoord => translatedVertCoord,
      pixel => pixel);
end Behavioral;
