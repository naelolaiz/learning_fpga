library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.VgaUtils.all;

entity top_level_vga_test is
  port (
    clk          : in  std_logic;                        -- Pin 23, 50MHz onboard osc.
    inputButtons : in  std_logic_vector(2 downto 0);     -- Pins 88, 89, 90 (active-low)
                                                         --   (0) pause/resume animation
                                                         --   (1) reset square to centre
                                                         --   (2) cycle speed slow/med/fast
    leds         : out std_logic_vector(3 downto 0);     -- Pins 87, 86, 85, 84
                                                         --   (0) square step pulse (one clk
                                                         --       wide per step — visible on a
                                                         --       scope/waveform, blends to dim
                                                         --       on a physical LED at 50 MHz)
                                                         --   (1) pause indicator (lit = paused)
                                                         --   (2) heartbeat (~12.5 Hz blink)
                                                         --   (3) speed: lit while in fast mode
    rgb          : out std_logic_vector (2 downto 0);    -- Pins 106, 105, 104
    hsync        : out std_logic;                        -- Pin 101
    vsync        : out std_logic                         -- Pin 103
  );
end entity top_level_vga_test;

architecture rtl of top_level_vga_test is
  constant SQUARE_SIZE  : integer := 30; -- In pixels

  -- Three step periods for the square's position update, picked by
  -- the speed-cycle button (inputButtons(2)). Counted in 50 MHz
  -- master-clock ticks; the live update toggles every period, so
  -- one step = 2 * period clock cycles.
  constant SQUARE_PERIOD_FAST   : integer :=  90000;  --  ~1.8 ms / step
  constant SQUARE_PERIOD_MEDIUM : integer := 180000;  --  ~3.6 ms / step  (original tune)
  constant SQUARE_PERIOD_SLOW   : integer := 360000;  --  ~7.2 ms / step

  -- Static-text horizontal scroll bounds.
  constant STATIC_TEXT_PIXELS : integer := 37 * 8;             -- "VGA with FPGA. 1 bit per component :)"
  constant STATIC_SCROLL_MAX  : integer := (HDATA_END - HDATA_BEGIN) - STATIC_TEXT_PIXELS;
  constant STATIC_SCROLL_DIV  : integer := 1500000;            -- 50 MHz / 1.5M = ~33 px/s

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

  signal should_draw_square : boolean;
  signal should_draw_text_static : std_logic;
  signal should_draw_text_dynamic : std_logic;
  signal should_draw_text_changing : std_logic;
  signal should_draw_text_changing2 : std_logic;

  signal counterForHalfSecond : integer range 0 to 25000000 := 0;
  signal ticksForHalfSecond : std_logic := '0';                   -- ~12.5 Hz toggle (heartbeat)
  signal halfSecondCounter : integer := 0;
  signal counterForSquarePositionUpdate : integer range 0 to 12500000 := 0;
  signal ticksForSquarePositionUpdate : std_logic := '0';
  signal counterForDynamicTextPositionUpdate : integer range 0 to 12500000 := 0;
  signal ticksForDynamicTextPositionUpdate : std_logic := '0';
  signal counterForStaticTextScroll : integer range 0 to STATIC_SCROLL_DIV := 0;
  signal xPosStaticTextOffset : integer range 0 to STATIC_SCROLL_MAX := 0;
  -- Square position seeds the ranged `square_x`/`square_y` mirrors
  -- below, which are constrained to HDATA_BEGIN..HDATA_END /
  -- VDATA_BEGIN..VDATA_END. Initialise inside that range so sim
  -- doesn't fail the bound check at t=0 before the first reset.
  signal xPosSquare : integer := HDATA_BEGIN + H_HALF - SQUARE_SIZE/2;
  signal yPosSquare : integer := VDATA_BEGIN + V_HALF - SQUARE_SIZE/2;
  signal xPosText, yPosText : integer := 5;
  signal xDirectionSquare, yDirectionSquare : boolean := true;
  signal xDirectionText, yDirectionText : boolean := true;
  signal hitOnStaticText1 : std_logic := '0';
  signal lastHitWasText : boolean := false;
  signal should_move_square : boolean := false;                   -- one-cycle pulse on each step

  -- Control surface state — produced by the control_panel building
  -- block (debouncers + pause toggle + speed cycler + LED panel).
  signal sPaused      : std_logic;
  signal sResetActive : std_logic;
  signal sSpeedSelect : std_logic_vector(1 downto 0);
  signal sPanelLeds   : std_logic_vector(2 downto 0);
  -- Selected period for square steps, decoded from sSpeedSelect.
  signal squareStepPeriod : integer range SQUARE_PERIOD_FAST to SQUARE_PERIOD_SLOW
                          := SQUARE_PERIOD_MEDIUM;

  constant changingStringSize : integer := 20;
  signal changingString : string (1 to changingStringSize) := "                    ";
  signal changingString2 : string (1 to changingStringSize) := "                    ";

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

begin

-- The two strings advance by one ASCII code per half-second tick;
-- changingString prints the run forward, changingString2 prints it
-- mirrored. Positions 18..20 keep their initial spaces and act as a
-- trailing buffer for the scroll. character'val rolls over at 256 —
-- harmless for the demo, just the glyphs cycle through ISO-8859-1.
gen_changing : for i in 1 to 17 generate
   changingString (i)      <= character'val(halfSecondCounter + i - 1);
   changingString2(18 - i) <= character'val(halfSecondCounter + i - 1);
end generate;
TickProcess : process (clk)
begin
    if (rising_edge(clk)) then
       -- Square step + dynamic-text + static-text-scroll counters all
       -- freeze when paused. The half-second / heartbeat counters keep
       -- running so the LED heartbeat keeps blinking even while paused.
       if sPaused = '0' then
          if counterForSquarePositionUpdate = squareStepPeriod then
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
          if counterForStaticTextScroll = STATIC_SCROLL_DIV then
             counterForStaticTextScroll <= 0;
             if xPosStaticTextOffset = STATIC_SCROLL_MAX then
                xPosStaticTextOffset <= 0;
             else
                xPosStaticTextOffset <= xPosStaticTextOffset + 1;
             end if;
          else
             counterForStaticTextScroll <= counterForStaticTextScroll + 1;
          end if;
       end if;
       if counterForHalfSecond = 4000000 then
          counterForHalfSecond <= 0;
          ticksForHalfSecond <= not ticksForHalfSecond;
          halfSecondCounter <= halfSecondCounter + 1;
       else
          counterForHalfSecond <= counterForHalfSecond + 1;
       end if;
    end if;
end process;


-- Async-reset moveSquare: while the reset button (active-low) is
-- held, the square snaps to the centre and direction state resets.
-- Otherwise it bounces and recolours on each tick edge as before.
moveSquare : process (ticksForSquarePositionUpdate, sResetActive)
begin
   if sResetActive = '1' then
      xPosSquare <= HDATA_BEGIN + (HDATA_END - HDATA_BEGIN) / 2 - SQUARE_SIZE / 2;
      yPosSquare <= VDATA_BEGIN + (VDATA_END - VDATA_BEGIN) / 2 - SQUARE_SIZE / 2;
      xDirectionSquare <= true;
      yDirectionSquare <= true;
   elsif rising_edge(ticksForSquarePositionUpdate) then
      if xDirectionSquare then
         if xPosSquare = HDATA_END - SQUARE_SIZE then
	    xDirectionSquare <= not xDirectionSquare;
	    rgb_square_color <= rgb_square_color(1 downto 0) & rgb_square_color(2);
	 else
	    xPosSquare <= xPosSquare + 1;
	 end if;
      else
         if xPosSquare = HDATA_BEGIN then
	    xDirectionSquare <= not xDirectionSquare;
	    rgb_square_color <= rgb_square_color(0) & rgb_square_color(2 downto 1);
	 else
	    xPosSquare <= xPosSquare - 1;
	 end if;
      end if;
      if yDirectionSquare then
         if yPosSquare = VDATA_END - SQUARE_SIZE - 30 then
	    yDirectionSquare <= not yDirectionSquare;
	    rgb_square_color <= rgb_square_color(2) & rgb_square_color(0) & rgb_square_color(1);
	 else
	    yPosSquare <= yPosSquare + 1;
	 end if;
      else
         if yPosSquare = VDATA_BEGIN then
	    yDirectionSquare <= not yDirectionSquare;
	    rgb_square_color <= rgb_square_color(1) & rgb_square_color(2) & rgb_square_color(0);
	 else
	    yPosSquare <= yPosSquare - 1;
	 end if;
      end if;
   end if;
end process;

-- One-clock pulse on every step. ticksForSquarePositionUpdate is a
-- toggle that flips on each step, so an edge detector against its
-- previous-cycle value picks up every transition. Without this
-- pulser, driving should_move_square from inside moveSquare's
-- rising_edge clause would latch it true after the first tick and
-- never clear — leds(0) would stick on instead of pulsing.
stepPulseGen : process (clk)
   variable lastTick : std_logic := '0';
begin
   if rising_edge(clk) then
      should_move_square <= (ticksForSquarePositionUpdate /= lastTick);
      lastTick := ticksForSquarePositionUpdate;
   end if;
end process;

-- Buttons + LED panel are factored out into the control_panel
-- building block so the integration TB can exercise them through a
-- 1:1 Verilog mirror without dragging in the VGA timing or text
-- rendering. The panel returns the pause flag, an active-high reset
-- level, a 2-bit speed select, and the three status LEDs (pause,
-- heartbeat, fast-mode). The top decodes speedSelect to one of the
-- SQUARE_PERIOD_* constants and wires its own per-step pulse on
-- leds(0) since the step toggle lives in TickProcess.
panel : entity work.control_panel
   port map (
      clk           => clk,
      inputButtons  => inputButtons,
      heartbeatTick => ticksForHalfSecond,
      paused        => sPaused,
      resetActive   => sResetActive,
      speedSelect   => sSpeedSelect,
      panelLeds     => sPanelLeds
   );

with sSpeedSelect select squareStepPeriod <=
   SQUARE_PERIOD_FAST   when "10",
   SQUARE_PERIOD_SLOW   when "01",
   SQUARE_PERIOD_MEDIUM when others;

leds(0)          <= '1' when should_move_square else '0';
leds(3 downto 1) <= sPanelLeds;

moveText : process (ticksForDynamicTextPositionUpdate)
begin
   if rising_edge(ticksForDynamicTextPositionUpdate) then
      if xDirectionText then
         if xPosText = HDATA_END - (297 * 2) then
	    xDirectionText <= not xDirectionText;
	    text_dynamic_rgb(0) <= '1';
	    text_dynamic_rgb <= text_dynamic_rgb(0) & text_dynamic_rgb(2 downto 1);
	 else
	    xPosText <= xPosText + 1;
	 end if;
      else
         if xPosText = HDATA_BEGIN then
	    xDirectionText <= not xDirectionText;
	    text_dynamic_rgb <= text_dynamic_rgb(1 downto 0) & text_dynamic_rgb(2);
	 else
	    xPosText <= xPosText - 1;
	 end if;
      end if;
      if yDirectionText then
         if yPosText = VDATA_END - 50 then
	    yDirectionText <= not yDirectionText;
	    text_dynamic_rgb <= text_dynamic_rgb(1) & text_dynamic_rgb(2) & text_dynamic_rgb(0);
	 else
	    yPosText <= yPosText + 1;
	 end if;
      else
         if yPosText = VDATA_BEGIN then
	    yDirectionText <= not yDirectionText;
	    text_dynamic_rgb <= text_dynamic_rgb(2) & text_dynamic_rgb(0) & text_dynamic_rgb(1);
	 else
	    yPosText <= yPosText - 1;
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
        	-- Slow horizontal scroll (~33 px/s) driven by xPosStaticTextOffset.
        	-- The static text walks from HDATA_BEGIN to the right edge of
        	-- visible area minus the text width, then snaps back to start.
        	positionX => HDATA_BEGIN + xPosStaticTextOffset,
        	positionY => VDATA_BEGIN,
        	horzCoord => hpos,
        	vertCoord => vpos,
        	pixel => should_draw_text_static
        );

        textWithSize: entity work.Pixel_On_Text_WithSize
        generic map (
	        fontScale => 4,
		xForward => true,
		yForward => false,
        	textLength => changingStringSize
        )
        port map(
        	clk => vga_clk,
		displayText => changingString2,
        	position => (HDATA_BEGIN, VDATA_BEGIN + 40),
        	horzCoord => hpos,
        	vertCoord => vpos,
        	pixel => should_draw_text_changing
        );

        textWithSize2: entity work.Pixel_On_Text_WithSize
        generic map (
	        fontScale => 4,
		xForward => true,
		yForward => true,
        	textLength => changingStringSize
        )
        port map(
        	clk => vga_clk,
		displayText => changingString,
        	position => (HDATA_BEGIN + 60, VDATA_BEGIN + 80),
        	horzCoord => hpos,
        	vertCoord => vpos,
        	pixel => should_draw_text_changing2
        );

        textElementMoving: entity work.Pixel_On_Text_WithSize
        generic map (
	        textLength => 37,
		fontScale  => 2
        )
        port map(
        	clk => vga_clk,
        	position => (xPosText, yPosText),
		displayText => "<<<((([[[ * FPGA VGA TEST * ]]])))>>>",
        	horzCoord => hpos,
        	vertCoord => vpos,
        	pixel => should_draw_text_dynamic
        );

   hitOnStaticText1 <= should_draw_text_static when should_draw_square else should_draw_text_static and should_draw_text_dynamic;

   process(hitOnStaticText1, should_draw_square, should_draw_text_dynamic)
   begin
      if rising_edge(hitOnStaticText1) then
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
         if should_draw_text_changing2 = '1' then
            tempColorSum  := "011";
	 else
            tempColorSum := "010";
         end if;
      elsif should_draw_text_changing2 = '1' then
         tempColorSum := "100";
      end if;
      rgb_input <= tempColorSum;
    end if;
  end process;
end architecture;
