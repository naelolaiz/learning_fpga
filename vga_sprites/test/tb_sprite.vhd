library ieee;

use ieee.std_logic_1164.ALL;
use ieee.numeric_std.ALL;

library work;
--use work.MyPackage.all;

entity tb_sprite is
end tb_sprite;

architecture testbench of tb_sprite is
   signal sSimulationActive : boolean   := true;
   signal sClock50MHz        : std_logic := '0';
   signal sEnabled : boolean := true;
   signal sSpritePosX, sSpritePosY  : std_logic_vector (15 downto 0) := (others => '0');
   signal sCursorX, sCursorY : std_logic_vector (15 downto 0) := (others => '0');
   signal sRotation : RotationType := ZERO;
   signal sShouldDraw : boolean := false;

   constant SpriteContent : std_logic_vector := "11111"
                                               &"11000"
                                               &"01100"
                                               &"00110"
                                               &"00011";

    type test_vector is record
        spritePosX,spritePosY : integer;
        rotation : RotationType;
        x0,y0,
        x1,y1,
        x2,y2,
        x3,y3,
        x4,y4,
        x5,y5,
        x6,y6,
        x7,y7,
        x8,y8,
        x9,y9,
        x10,y10,
        x11,y11,
        x12,y12,
        x13,y13 : integer; -- list of expected outputs
    end record; 

    type test_vector_array is array (natural range <>) of test_vector;
    constant test_vectors : test_vector_array := (
        (0, 0, ZERO, 0,0,0,1,0,2,0,3,0,4,1,0,1,1,2,1,2,2,3,2,3,3,4,3,4,4)
        );
begin

   DUT : entity work.sprite(logic)
   generic map(SPRITE_WIDTH => 5,
               SCALE => 1,
               SPRITE_CONTENT => SpriteContent)
   port map (
         inClock       => sClock50MHz,
         inSpritePosX  => sSpritePosX,
         inSpritePosY  => sSpritePosY,
         inCursorX     => sCursorX,
         inCursorY     => sCursorY,
         inRotation    => sRotation,
         outShouldDraw => sShouldDraw);

   -- generate clock 
   sClock50MHz <= not sClock50MHz after 10 ns when sSimulationActive;

   -- generate button pressed
   PRESS_BUTTONS : process
   begin
     sButton <= '1';
     wait for 50 ns;
     sButton <= '0';
     wait for 40 ns;
     sButton <= '1';
     wait for 150 ns; -- 50+40+150=240ns, already in other half of the cycle
     sButton <= '0';
     wait for 50 ns;
     sButton <= '1';
     wait;
   end process;

   -- check the outputs
   EXPECTED_OUTPUTS_CHECKS : process
   begin
      wait until rising_edge(sClock50MHz);
      assert(sLed1 = '0' and sLed2 = '0') 
         report "Wrong output signals at start" severity error;
      wait until sButton = '0';
      wait until rising_edge(sClock50MHz);
      assert(sLed1 = '0' and sLed2 = '1')
         report "Wrong output signals after button pressed the first time" severity error;
      -- this happened at 90ns. We wait until being in the second half of the cycle but before the button is pressed
      wait for 130 ns;
      assert(sLed1 ='1' and sLed2 = '1') -- not inverted
         report "Wrong output signals on second cycle, button not pressed" severity error;
      wait until sButton = '0';
      wait until rising_edge(sClock50MHz);
      assert(sLed1 = '1' and sLed2 = '0')
         report "Wrong output signals on second cycle, button pressed" severity error;
      wait until sButton = '1';
      wait until rising_edge(sClock50MHz);
      assert(sLed1 = '1' and sLed2 = '1')
         report "Wrong output signals on second cycle, button released" severity error;
      report "Simulation done!" severity note;
      sSimulationActive <= false;

   end process;

end testbench;
