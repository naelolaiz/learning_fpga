library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.VgaUtils.all;
use work.definitions.all;

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


constant SCREEN_SIZE    : Size2D := (640,480);
constant SCREEN_MARGINS : Pos2D  := (155,30);


  -- VGA Clock - 25 MHz clock derived from the 50MHz built-in clock
  signal vga_clk : std_logic;

  signal rgb_input, rgb_output : std_logic_vector(2 downto 0);
  signal rgb_square_color : std_logic_vector (2 downto 0) := COLOR_YELLOW;
  signal vga_hsync, vga_vsync  : std_logic;
  signal hpos, vpos            : integer;

--  signal square_x           : integer range HDATA_BEGIN to HDATA_END := HDATA_BEGIN + H_HALF - SQUARE_SIZE/2;
--  signal square_y           : integer range VDATA_BEGIN to VDATA_END := VDATA_BEGIN + V_HALF - SQUARE_SIZE/2;

  signal cursorPosition      : Pos2D;
  signal hPosVector, vPosVector : std_logic_vector(15 downto 0) := (others => '0');
--  signal spritePosition      : Pos2D;

  signal square_speed_count : integer range 0 to SQUARE_SPEED        := 0;
  signal should_move_square : boolean;
  signal should_draw_square1 : boolean;
  signal should_draw_square2 : boolean;

  -- nael
  signal ticksForDynamicTextPositionUpdate : std_logic := '0';
  signal xPosSprite, yPosSprite : integer := 0;
  signal xPosNael, yPosNael : integer := 5;
  signal xDirectionSprite, yDirectionSprite : boolean := true; 
  signal xDirectionText, yDirectionText : boolean := true; 

  signal sSmiley1Enabled : boolean := true;

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

  component sprite is
   generic (SCREEN_SIZE    : Size2D;
            SPRITE_WIDTH   : integer;
            SCALE          : integer;
            SPRITE_CONTENT : std_logic_vector;
            INITIAL_ROTATION         : integer;
            INITIAL_ROTATION_SPEED           : RotationSpeed;
            INITIAL_POSITION         : Pos2D;
            INITIAL_SPEED            : Speed2D
            );
   port( inClock : in  std_logic;
         inEnabled : in boolean;
         --inSpritePos   : Pos2D; -- center position of sprite
         inCursorPos   : Pos2D; -- position to check
         --inRotation    : in AngleType;
         inColision : in boolean; --TODO direction
         outShouldDraw : out boolean);
  end component;

begin

cursorPosition <= (hpos - SCREEN_MARGINS.x, vpos - SCREEN_MARGINS.y);

mySprite : sprite
generic map(SCREEN_SIZE => SCREEN_SIZE,
            INITIAL_ROTATION => 8,
            INITIAL_POSITION => (200,200),
            INITIAL_SPEED => (1, 1, 150000),
            SPRITE_WIDTH => 11,
            SCALE => 3,
            SPRITE_CONTENT => "00011111000"
                             &"00100000100"
                             &"01000000010"
                             &"10010001001"
                             &"10000000001"
                             &"10000100001"
                             &"10100000101"
                             &"10010001001"
                             &"01001110010"
                             &"00100000100"
                             &"00011111000",
            INITIAL_ROTATION_SPEED => (0,0))
            --INITIAL_ROTATION_SPEED => (1, 4000000))
port map (inClock       => vga_clk,
          inEnabled     => true,
          --inSpritePos   => spritePosition,
          inCursorPos   => cursorPosition,
          outShouldDraw => should_draw_square1,
          inColision => should_draw_square2);

  mySprite2 : sprite
  generic map(SCREEN_SIZE => SCREEN_SIZE,
            INITIAL_ROTATION => 0,
              INITIAL_POSITION => (500,300),
              INITIAL_SPEED => (1, -1, 180000),
              SPRITE_WIDTH => 11,
              SCALE => 7,
                SPRITE_CONTENT => "00011111000"
                                 &"00100000100"
                                 &"01000000010"
                                 &"10010001001"
                                 &"10000100001"
                                 &"10000000001"
                                 &"10011111001"
                                 &"10100000101"
                                 &"01000000010"
                                 &"00100000100"
                                 &"00011111000",
              INITIAL_ROTATION_SPEED => (-1, 8000000))
  port map (inClock       => vga_clk,
            inEnabled     => true,
            --inSpritePos   => spritePosition,
            inCursorPos   => cursorPosition,
            outShouldDraw => should_draw_square2,
            inColision => should_draw_square1);

 -- mySprite2 : entity work.sprite(logic)
 -- generic map(SPRITE_WIDTH => 11,
 --             SCALE => 16,
 --             SPRITE_CONTENT => "00011111000"
 --                              &"00100000100"
 --                              &"01000000010"
 --                              &"10010001001"
 --                              &"10000100001"
 --                              &"10000000001"
 --                              &"10011111001"
 --                              &"10100000101"
 --                              &"01000000010"
 --                              &"00100000100"
 --                              &"00011111000")
 --            --  SPRITE_CONTENT => "00011111000"
 --            --                   &"00100000100"
 --            --                   &"01000000010"
 --            --                   &"10010001001"
 --            --                   &"10000100001"
 --            --                   &"10000000001"
 --            --                   &"10001110001"
 --            --                   &"10010001001"
 --            --                   &"01001110010"
 --            --                   &"00100000100"
 --            --                   &"00011111000")
 -- port map (inClock       => vga_clk,
 --           inEnabled     => not sSmiley1Enabled,
 --           inSpritePos   => spritePosition,
 --           inCursorPos   => cursorPosition,
 --           outShouldDraw => should_draw_square2);
--square_x <= xPosSprite;
--square_y <= yPosSprite;

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

  -- We need 25MHz for the VGA so we divide the input clock by 2
  process (clk)
  begin
    if (rising_edge(clk)) then
      vga_clk <= not vga_clk;
    end if;
  end process;

  process (vga_clk, should_draw_square1, should_draw_square2)
  variable tempColorSum : std_logic_vector(2 downto 0) := "000";
  begin
    if rising_edge(vga_clk) then
      tempColorSum := "000";
      if should_draw_square1 then
        tempColorSum := "010";
      end if;
      if should_draw_square2 then
        tempColorSum := tempColorSum or "001";
      end if;
    end if;
    rgb_input <= tempColorSum; 
  end process;

end architecture;
