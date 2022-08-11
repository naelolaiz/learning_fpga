library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.trigonometric.all;
use work.definitions.all;


entity tb_trigonometric is
end tb_trigonometric;

architecture testbench of tb_trigonometric is
     signal indexForTableStdTestSinCos : std_logic_vector(4 downto 0)  := (others => '0');
     signal inputStdTestSinCos         : std_logic_vector(7 downto 0)  := (others => '0');
     signal sumStdSin                 : std_logic_vector(7 downto 0) := (others => '0');
     signal sumStdCos                  : std_logic_vector(7 downto 0) := (others => '0');

     signal indexForTableStdTestRotate : std_logic_vector(4 downto 0)  := (others => '0');
     signal sInputPos  : Pos2D := (0, 0);
     signal sOutputPos : Pos2D := (0, 0);

     signal sClock : std_logic := '0'; -- reference clock for viewing

begin
--  testing_values_lut_sin_cos : process
--    constant sprite_size      : Size2D  := (11,11);
--  begin
--     for indexForTable in 0 to 31 loop
--         indexForTableStdTestSinCos <= std_logic_vector(to_unsigned(indexForTable, 5));
--         for inputValue in -128 to 127 loop
--             inputStdTestSinCos <= std_logic_vector(to_signed(inputValue, 8));
--             sumStdSin <= multiplyBySinLUT(indexForTableStdTestSinCos,
--                                        inputStdTestSinCos);
--             sumStdCos <= multiplyByCosLUT(indexForTableStdTestSinCos,
--                                        inputStdTestSinCos);
--             wait for 1 ms;
--
--         end loop;
--     end loop;
--     wait;
--  end process;

   testing_values_rotate : process
     constant sprite_size      : Size2D  := (11,11);
     variable vInputPos , vOutputPos: Pos2D := (0,0);
   begin
       -- indexForTableStdTestRotate <= "00000"; -- no rotation
       -- vInputPos := (0,0);
       -- outputPos <= rotate(sprite_size, vInputPos, indexForTableStdTestRotate);
       -- assert (outputPos = (0,0))
       --     report "Wrong rotation @(0,0), rotation 0"; 

       -- wait for 1 ns;

       -- indexForTableStdTestRotate <= "00111"; -- pi / 2
       -- vInputPos := (0,0);
       -- outputPos <= rotate(sprite_size, vInputPos, indexForTableStdTestRotate);
       -- assert (outputPos = (0,0))
       --     report "Wrong rotation @(0,0), rotation pi/2"; 

       -- wait for 1 ns;

       -- vInputPos := (0,11);
       -- outputPos <= rotate(sprite_size, vInputPos, indexForTableStdTestRotate);
       -- assert (outputPos = (0,0))
       --     report "Wrong rotation @(0,11), rotation pi/2"; 

       -- wait for 1 ns;



     for indexForTableRotate in 0 to 31 loop
         indexForTableStdTestRotate <= std_logic_vector(to_unsigned(indexForTableRotate, 5));
         for inputX in -5 to 5 loop
             for inputY in -5 to 5 loop
                  sClock <= '0';
                  wait for 500 ns;
                  vInputPos := (inputX, inputY);
                  sInputPos <= (inputX, inputY);
                  rotate(sClock sprite_size, vInputPos, indexForTableStdTestRotate, vOutputPos);
                  sOutputPos <= vOutputPos; --rotate(sprite_size, sInputPos, indexForTableStdTestRotate);
                  sClock <= '1';
                  wait for 1 us;
             end loop;
         end loop;
     end loop;
     wait;
   end process;

end testbench;
