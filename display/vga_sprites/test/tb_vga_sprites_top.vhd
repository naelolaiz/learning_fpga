library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

-- Runs the real board top, top_level_vga_test, and checks where a
-- sprite lands on the screen — using nothing but the pins a monitor
-- sees: rgb, hsync and vsync.
--
-- The big smiley (sprite 3) sits still at the screen centre with no
-- rotation, 25 screen pixels per sprite pixel. Its top row is
-- "00011111000", so on a scan line through that row the picture is one
-- white run, five sprite pixels wide, and black everywhere else (the
-- other two sprites are lower down).
--
-- Where that run starts follows from the design:
--
--   left edge of the sprite's box   320 - 137          = cursor x 183
--   three blank sprite pixels       183 + 3 * 25       = cursor x 258
--   cursor 0 is at hcount 155, and the sprite's answer reaches the
--   rgb pins two pixels after the cursor it belongs to   +157
--
-- so the run covers hcount 415 .. 539. The sprite itself needs three
-- clocks to answer and rgb_input adds one; the top shows the sprites
-- the cursor two pixels early, which is what brings the total back to
-- two. A change in the sprite's latency that is not matched in the top
-- moves the run and fails this test.
--
-- The testbench rebuilds the scan position from the sync pins: lines
-- are counted on hsync falling edges, pixels by time since the last
-- one. It also checks the line length.
entity tb_vga_sprites_top is
end tb_vga_sprites_top;

architecture testbench of tb_vga_sprites_top is
   constant CLK_PERIOD   : time    := 20 ns;            -- 50 MHz board clock
   constant PIXEL_PERIOD : time    := 2 * CLK_PERIOD;   -- 25 MHz pixel clock
   constant LINE_PIXELS  : integer := 800;

   -- vcount 140 = cursor y 110, inside the sprite's top row
   -- (cursor y 103 .. 127).
   constant TEST_LINE   : integer := 140;
   constant FIRST_WHITE : integer := 415;
   constant LAST_WHITE  : integer := 539;

   signal tbClock : std_logic := '0';
   signal tbRgb   : std_logic_vector(2 downto 0);
   signal tbHsync : std_logic;
   signal tbVsync : std_logic;

   signal tbLine       : integer := 0;       -- lines since power-up (= vcount)
   signal tbPixel      : integer := 0;       -- hcount on the line under test
   signal tbChecking   : boolean := false;
   signal tbWhiteCount : integer := 0;

   signal sSimulationActive : boolean := true;
begin

   tbClock <= not tbClock after CLK_PERIOD / 2 when sSimulationActive else '0';

   dut : entity work.top_level_vga_test
      port map (
         clk   => tbClock,
         rgb   => tbRgb,
         hsync => tbHsync,
         vsync => tbVsync
      );

   monitor : process
      variable vLine      : integer := 0;
      variable vPixel     : integer := 0;
      variable vWhite     : integer := 0;
      variable vLineStart : time    := 0 ns;
   begin
      -- hsync falls when hcount wraps to 0, which is also when vcount
      -- advances: n falling edges after power-up, vcount is n.
      vLine := 0;
      while vLine < TEST_LINE loop
         wait until falling_edge(tbHsync);
         assert vLine = 0 or now - vLineStart = LINE_PIXELS * PIXEL_PERIOD
            report "scan line is not " & integer'image(LINE_PIXELS) & " pixels long"
            severity failure;
         vLineStart := now;
         vLine      := vLine + 1;
         tbLine     <= vLine;
      end loop;

      assert tbVsync = '1'
         report "vsync should be inactive (high) on a visible line"
         severity failure;

      -- Sample every pixel of the line in the middle of its period.
      tbChecking <= true;
      wait for PIXEL_PERIOD / 2;
      vPixel := 0;
      while vPixel < LINE_PIXELS loop
         tbPixel <= vPixel;
         if vPixel >= FIRST_WHITE and vPixel <= LAST_WHITE then
            assert tbRgb = "111"
               report "hcount " & integer'image(vPixel)
                    & ": expected the sprite (white)"
               severity failure;
            vWhite := vWhite + 1;
            tbWhiteCount <= vWhite;
         else
            assert tbRgb = "000"
               report "hcount " & integer'image(vPixel)
                    & ": expected black outside the sprite"
               severity failure;
         end if;
         wait for PIXEL_PERIOD;
         vPixel := vPixel + 1;
      end loop;
      tbChecking <= false;

      assert vWhite = 5 * 25
         report "the sprite's top row should be 125 pixels wide"
         severity failure;

      report "vga_sprites top simulation done!" severity note;
      sSimulationActive <= false;
      wait;
   end process;

end testbench;
