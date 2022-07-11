library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.VgaUtils.all;

entity top_level_vga_test is
  port (
    clk   : in std_logic; -- Pin 23, 50MHz from the onboard oscilator.
    rgb   : out std_logic_vector (2 downto 0); -- Pins 106, 105 and 104
    hsync : out std_logic; -- Pin 101
    vsync : out std_logic -- Pin 103
  );
end entity top_level_vga_test;

architecture rtl of top_level_vga_test is
  constant SQUARE_SIZE  : integer := 30; -- In pixels
  constant SQUARE_SPEED : integer := 100_000;

  -- VGA Clock - 25 MHz clock derived from the 50MHz built-in clock
  signal vga_clk : std_logic;

  signal rgb_input, rgb_output : std_logic_vector(2 downto 0);
  signal rgb_square_color : std_logic_vector (2 downto 0) := COLOR_YELLOW;
  signal text_static_rgb : std_logic_vector (2 downto 0) := "011";
  signal text_dynamic_rgb : std_logic_vector (2 downto 0) := COLOR_PURPLE;
  signal vga_hsync, vga_vsync  : std_logic;
  signal hpos, vpos            : integer;

  signal square_x           : integer range HDATA_BEGIN to HDATA_END := HDATA_BEGIN + H_HALF - SQUARE_SIZE/2;
  signal square_y           : integer range VDATA_BEGIN to VDATA_END := VDATA_BEGIN + V_HALF - SQUARE_SIZE/2;
  signal square_speed_count : integer range 0 to SQUARE_SPEED        := 0;

  signal should_move_square : boolean;

  signal should_draw_square : boolean;
  signal should_draw_text_static : std_logic;
  signal should_draw_text_dynamic : std_logic;
  signal should_draw_text_changing : std_logic;

  -- nael
  signal counterForHalfSecond : integer range 0 to 25000000 := 0;
  signal ticksForHalfSecond : std_logic := '0';
  signal halfSecondCounter : integer := 0;
  signal counterForSquarePositionUpdate : integer range 0 to 12500000 := 0;
  signal ticksForSquarePositionUpdate : std_logic := '0';
  signal counterForDynamicTextPositionUpdate : integer range 0 to 12500000 := 0;
  signal ticksForDynamicTextPositionUpdate : std_logic := '0';
  signal xPosSquare, yPosSquare : integer := 0;
  signal xPosNael, yPosNael : integer := 5;
  signal xDirectionSquare, yDirectionSquare : boolean := true; 
  signal xDirectionText, yDirectionText : boolean := true; 
  signal hitOnStaticText1 : std_logic := '0';
  signal lastHitWasText : boolean := false;

  constant changingStringSize : integer := 20;
  signal changingString : string (1 to changingStringSize) := "                    ";

  component VgaController is
    port (
      clk     : in std_logic;
      rgb_in  : in std_logic_vector (2 downto 0);
      rgb_out : out std_logic_vector (2 downto 0);
      hsync   : out std_logic;
      vsync   : out std_logic;
      hpos    : out integer;
      vpos    : out integer
    );
  end component;

  component Debounce is
    port (
      i_Clk    : in std_logic;
      i_Switch : in std_logic;
      o_Switch : out std_logic
    );
  end component;
begin

changingString(1) <= character'val(halfSecondCounter);
changingString(2) <= character'val(halfSecondCounter +1);
changingString(3) <= character'val(halfSecondCounter +2);
changingString(4) <= character'val(halfSecondCounter +3);
changingString(5) <= character'val(halfSecondCounter +4);
changingString(6) <= character'val(halfSecondCounter +5);
changingString(7) <= character'val(halfSecondCounter +6);
changingString(8) <= character'val(halfSecondCounter +7);
changingString(9) <= character'val(halfSecondCounter +8);
changingString(10) <= character'val(halfSecondCounter +9);
changingString(11) <= character'val(halfSecondCounter +10);
changingString(12) <= character'val(halfSecondCounter +11);
changingString(13) <= character'val(halfSecondCounter +12);
changingString(14) <= character'val(halfSecondCounter +13);
changingString(15) <= character'val(halfSecondCounter +14);
changingString(16) <= character'val(halfSecondCounter +15);
changingString(17) <= character'val(halfSecondCounter +16);

TickProcess : process (clk)
begin
    if (rising_edge(clk)) then
       if counterForSquarePositionUpdate = 180000 then
          counterForSquarePositionUpdate <= 0;
	  ticksForSquarePositionUpdate <= not ticksForSquarePositionUpdate;
       else
          counterForSquarePositionUpdate <= counterForSquarePositionUpdate + 1;
       end if;
       if counterForDynamicTextPositionUpdate = 220000 then
          counterForDynamicTextPositionUpdate <= 0;
	  ticksForDynamicTextPositionUpdate <= not ticksForDynamicTextPositionUpdate;
       else
          counterForDynamicTextPositionUpdate <= counterForDynamicTextPositionUpdate + 1;
       end if;
       if counterForHalfSecond = 10000000 then -- 25000000-1 then
          counterForHalfSecond <= 0;
	  ticksForHalfSecond <= not ticksForHalfSecond;
	  halfSecondCounter <= halfSecondCounter + 1;
       else
          counterForHalfSecond <= counterForHalfSecond + 1;
       end if;
    end if;
end process;


moveSquare : process (ticksForSquarePositionUpdate)
begin
   if rising_edge(ticksForSquarePositionUpdate) then
      if xDirectionSquare then
         if xPosSquare = HDATA_END - SQUARE_SIZE then
	    xDirectionSquare <= not xDirectionSquare;
	    rgb_square_color <= rgb_square_color(1 downto 0) & rgb_square_color(2);
	 else
	    xPosSquare <= xPosSquare + 1;
	 end if;
      else
         if xPosSquare = HDATA_BEGIN then -- 300 then --HDATA_BEGIN + HSYNC_END then
	    xDirectionSquare <= not xDirectionSquare;
	    rgb_square_color <= rgb_square_color(0) & rgb_square_color(2 downto 1);
	 else
	    xPosSquare <= xPosSquare - 1;
	 end if;
      end if;
      if yDirectionSquare then
         if yPosSquare = VDATA_END - SQUARE_SIZE - 30 then
	    -- yPosSquare <= 220;
	    yDirectionSquare <= not yDirectionSquare;
	    rgb_square_color <= rgb_square_color(2) & rgb_square_color(0) & rgb_square_color(1);
	 else
	    yPosSquare <= yPosSquare + 1;
	 end if;
      else
         if yPosSquare = VDATA_BEGIN then
	    -- yPosSquare <= 360;
	    yDirectionSquare <= not yDirectionSquare;
	    rgb_square_color <= rgb_square_color(1) & rgb_square_color(2) & rgb_square_color(0);
	 else
	    yPosSquare <= yPosSquare - 1;
	 end if;
      end if;
      should_move_square <= true;
   else
      should_move_square <= false;
   end if;
end process;

moveText : process (ticksForDynamicTextPositionUpdate)
begin
   if rising_edge(ticksForDynamicTextPositionUpdate) then
      if xDirectionText then
         if xPosNael = HDATA_END - 292 then
	    xDirectionText <= not xDirectionText;
	    text_dynamic_rgb(0) <= '1';
	    text_dynamic_rgb <= text_dynamic_rgb(0) & text_dynamic_rgb(2 downto 1);
	 else
	    xPosNael <= xPosNael + 1;
	 end if;
      else
         if xPosNael = HDATA_BEGIN then
	    xDirectionText <= not xDirectionText;
	    text_dynamic_rgb <= text_dynamic_rgb(1 downto 0) & text_dynamic_rgb(2);
	 else
	    xPosNael <= xPosNael - 1;
	 end if;
      end if;
      if yDirectionText then
         if yPosNael = VDATA_END - 60 then
	    yDirectionText <= not yDirectionText;
	    text_dynamic_rgb <= text_dynamic_rgb(1) & text_dynamic_rgb(2) & text_dynamic_rgb(0);
	 else
	    yPosNael <= yPosNael + 1;
	 end if;
      else
         if yPosNael = VDATA_BEGIN then
	    yDirectionText <= not yDirectionText;
	    text_dynamic_rgb <= text_dynamic_rgb(2) & text_dynamic_rgb(0) & text_dynamic_rgb(1);
	 else
	    yPosNael <= yPosNael - 1;
	 end if;
      end if;
   end if;

end process;


square_x <= xPosSquare;
square_y <= yPosSquare;

  controller : VgaController port map(
    clk     => vga_clk,
    rgb_in  => rgb_input,
    rgb_out => rgb_output,
    hsync   => vga_hsync,
    vsync   => vga_vsync,
    hpos    => hpos,
    vpos    => vpos
  );

  rgb   <= rgb_output;
  hsync <= vga_hsync;
  vsync <= vga_vsync;

  Square(hpos, vpos, square_x, square_y, SQUARE_SIZE, should_draw_square);

        textElement2: entity work.Pixel_On_Text2
        generic map (
        	displayText => "VGA with FPGA. 1 bit per component :)" 
        )
        port map(
        	clk => vga_clk,
        	positionX => HDATA_BEGIN,  -- HDATA_BEGIN + HSYNC_END, -- text position.x (top left)
        	positionY => VDATA_BEGIN, -- text position.y (top left)
        	horzCoord => hpos,
        	vertCoord => vpos,
        	pixel => should_draw_text_static -- result
        );

        textElement: entity work.Pixel_On_Text
        generic map (
        	textLength => changingStringSize
        )
        port map(
        	clk => vga_clk,
		displayText => changingString,
        	position => (HDATA_BEGIN,VDATA_BEGIN + 40),  -- HDATA_BEGIN + HSYNC_END, -- text position.x (top left)
        	horzCoord => hpos,
        	vertCoord => vpos,
        	pixel => should_draw_text_changing -- result
        );

        textElementMoving: entity work.Pixel_On_Text2
        generic map (
        	displayText => "<<<((([[[ * FPGA VGA TEST * ]]])))>>>" 
        )
        port map(
        	clk => vga_clk,
        	positionX => xPosNael,  -- HDATA_BEGIN + HSYNC_END, -- text position.x (top left)
        	positionY => yPosNael, -- text position.y (top left)
        	horzCoord => hpos,
        	vertCoord => vpos,
        	pixel => should_draw_text_dynamic -- result
        );

   --- hitOnStaticText1 <= should_draw_text_static and (should_draw_text_dynamic or ('1' when should_draw_square else '0'));
   hitOnStaticText1 <= should_draw_text_static when should_draw_square else should_draw_text_static and should_draw_text_dynamic;

   process(hitOnStaticText1, should_draw_square, should_draw_text_dynamic)
   begin
      if rising_edge(hitOnStaticText1) then
          -- text_static_rgb(2) <= not text_static_rgb(2);
	  if  should_draw_text_dynamic = '1' then
            if not lastHitWasText then
	       lastHitWasText <= true;
	       text_static_rgb <= text_static_rgb(1 downto 0) & text_static_rgb(2);
	    end if;
	  else
	    if lastHitWasText  then
	       lastHitWasText <= false;
	       text_static_rgb <=  text_static_rgb(0) & text_static_rgb(2 downto 1);
	    end if;
	  end if;
      end if;
   end process;


  -- We need 25MHz for the VGA so we divide the input clock by 2
  process (clk)
  begin
    if (rising_edge(clk)) then
      vga_clk <= not vga_clk;
    end if;
  end process;

  process (vga_clk)
  variable tempColorSum : std_logic_vector(2 downto 0) := "000";
  begin
    if (rising_edge(vga_clk)) then
      tempColorSum := "000";
      if should_draw_square then
         tempColorSum := tempColorSum or rgb_square_color;
      end if;
      if should_draw_text_static = '1' then
         if tempColorSum  = text_static_rgb then
	    tempColorSum := tempColorSum xor text_static_rgb;
	 else
            tempColorSum := tempColorSum or text_static_rgb;
	 end if;
      end if;
      if should_draw_text_dynamic = '1' then
         if tempColorSum  = text_dynamic_rgb then
            tempColorSum := tempColorSum xor text_dynamic_rgb;
	 else
            tempColorSum := tempColorSum or text_dynamic_rgb;
	 end if;
      end if;
      if should_draw_text_changing = '1' then
         tempColorSum  := "111";
      end if;
      rgb_input <= tempColorSum;
    end if;
  end process;
end architecture;
