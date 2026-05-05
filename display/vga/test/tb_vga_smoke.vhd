library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.VgaUtils.all;

-- Smoke test for the vga building blocks.
--
-- vga is a "first VGA" tutorial: text + bouncing geometry, no sprites.
-- The full pixel pipeline (640x480 frames, char glyphs streaming under
-- a moving HSYNC/VSYNC counter) is too long to render meaningfully as
-- a CI waveform, so this TB instead pins the two unit primitives the
-- example actually leans on:
--
--   * `Square` from VgaUtils — strict-inequality box test that drives
--     `should_draw` for the bouncing square.
--   * `Font_Rom` from text_generator — synchronous-read 2048x8 ROM
--     keyed on (charCode*16 + row), feeding `Pixel_On_Text`.
--
-- Each gets cause-effect assertions plus a short waveform sweep so the
-- gallery has something to look at. If either primitive regresses, CI
-- fails before anybody touches a board.

entity tb_vga_smoke is
end tb_vga_smoke;

architecture testbench of tb_vga_smoke is
   constant CLK_PERIOD : time := 20 ns; -- 50 MHz, matches board vga_clk

   signal tbClock           : std_logic := '0';
   signal sSimulationActive : boolean   := true;
   signal tbStage           : integer   := 0;

   -- Square() inputs/outputs (must be signals, the procedure's
   -- arguments are signal-typed).
   signal sqHCur, sqVCur    : integer := 0;
   signal sqHPos, sqVPos    : integer := 0;
   signal sqShouldDraw      : boolean;
   constant SQ_SIZE         : integer := 10;

   -- Font_Rom plumbing.
   signal romAddr           : integer := 0;
   signal romRow            : std_logic_vector(7 downto 0);

begin

   tbClock <= not tbClock after CLK_PERIOD / 2 when sSimulationActive else '0';

   -- The Square procedure is a concurrent statement; calling it once
   -- here keeps `sqShouldDraw` continuously updated as the inputs
   -- change in the stimulus process below.
   Square(sqHCur, sqVCur, sqHPos, sqVPos, SQ_SIZE, sqShouldDraw);

   font_rom : entity work.Font_Rom
      port map (
         clk     => tbClock,
         addr    => romAddr,
         fontRow => romRow
      );

   stim : process
      -- Read the ROM at `address`, return the registered row.
      -- Font_Rom is one-cycle synchronous-read: drive the address,
      -- wait one rising edge, sample.
      procedure read_rom(constant address : in integer) is
      begin
         romAddr <= address;
         wait until rising_edge(tbClock);
         wait for 1 ns;  -- delta past the registered output update
      end procedure;
   begin
      ---------------------------------------------------------------
      -- Stage 1: Square() boundary semantics.
      -- The procedure body is `hcur > hpos and hcur < (hpos + size)
      --                    and vcur > vpos and vcur < (vpos + size)`,
      -- i.e. strict-less-than on both edges. Pin that contract.
      ---------------------------------------------------------------
      tbStage <= 1;
      sqHPos  <= 100;
      sqVPos  <= 50;

      sqHCur  <= 105;
      sqVCur  <= 55;
      wait for 1 ns;
      assert sqShouldDraw = true
         report "Square: cursor strictly inside the box should draw"
         severity failure;

      sqHCur  <= 100;  -- on the left edge — strict, so should NOT draw
      sqVCur  <= 55;
      wait for 1 ns;
      assert sqShouldDraw = false
         report "Square: cursor on the left edge must not draw (strict <)"
         severity failure;

      sqHCur  <= 110;  -- on the right edge (hpos+size) — strict, no draw
      sqVCur  <= 55;
      wait for 1 ns;
      assert sqShouldDraw = false
         report "Square: cursor on the right edge must not draw (strict <)"
         severity failure;

      sqHCur  <= 200;  -- well outside
      sqVCur  <= 200;
      wait for 1 ns;
      assert sqShouldDraw = false
         report "Square: cursor far outside should not draw"
         severity failure;

      ---------------------------------------------------------------
      -- Stage 2: Font_Rom — the NUL glyph (char 0x00) is all zeros
      -- across all 16 rows. Sweeping addr 0..15 catches a ROM that
      -- failed to load or got the addressing wrong on the low rows.
      ---------------------------------------------------------------
      tbStage <= 2;
      for r in 0 to 15 loop
         read_rom(r);
         assert romRow = "00000000"
            report "Font_Rom: NUL row " & integer'image(r)
                 & " should be all zeros, got "
                 & integer'image(to_integer(unsigned(romRow)))
            severity failure;
      end loop;

      ---------------------------------------------------------------
      -- Stage 3: Font_Rom — char 'A' (0x41) row 7 is the horizontal
      -- bar across the glyph: "11111110". Asserting an exact non-zero
      -- pattern at a non-trivial address proves both the ROM contents
      -- and the (charCode*16 + row) addressing reach the upper half
      -- of the table.
      ---------------------------------------------------------------
      tbStage <= 3;
      read_rom(16#41# * 16 + 7);
      assert romRow = "11111110"
         report "Font_Rom: 'A' row 7 expected ""11111110"", got "
              & integer'image(to_integer(unsigned(romRow)))
         severity failure;

      ---------------------------------------------------------------
      -- Stage 4: waveform sweep. Walk the cursor across the box in
      -- both axes so the rendered PNG visibly toggles `sqShouldDraw`
      -- twice per axis. No assertions — just stimulus for the
      -- gallery.
      ---------------------------------------------------------------
      tbStage <= 4;
      sqHPos  <= 20;
      sqVPos  <= 20;
      sqVCur  <= 25;     -- inside vertical band for the whole sweep
      for x in 10 to 40 loop
         sqHCur <= x;
         wait for 2 * CLK_PERIOD;
      end loop;

      tbStage <= 99;
      wait for 2 * CLK_PERIOD;
      sSimulationActive <= false;
      wait;
   end process;

end testbench;
