library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.trigonometric.all;
use work.definitions.all;


entity tb_trigonometric is
end tb_trigonometric;

architecture testbench of tb_trigonometric is
     signal indexForTableStd : std_logic_vector(4 downto 0)  := (others => '0');
     signal inputStd         : std_logic_vector(7 downto 0)  := (others => '0');
     signal sumStdSin        : std_logic_vector(7 downto 0) := (others => '0');
     signal sumStdCos        : std_logic_vector(7 downto 0) := (others => '0');
     signal testRunning   : boolean := true;
     signal outputPos : Pos2D := (100,100);

begin
   testing_values_lut_sin_cos : process
     constant sprite_size      : Size2D  := (11,11);
   begin
      for indexForTable in 0 to 31 loop
          indexForTableStd <= std_logic_vector(to_unsigned(indexForTable, 5));
          for inputValue in -128 to 127 loop
              inputStd <= std_logic_vector(to_signed(inputValue, 8));
              sumStdSin <= multiplyBySinLUT(indexForTableStd,
                                         inputStd);
              sumStdCos <= multiplyByCosLUT(indexForTableStd,
                                         inputStd);
              wait for 1 ns;

          end loop;
      end loop;
      testRunning <= false;
      wait;
   end process;

   testing_values_rotate : process
     constant sprite_size      : Size2D  := (11,11);
     constant position : Pos2D := (100,100);
   begin
      if testRunning then
        wait on indexForTableStd;
        outputPos <= rotate(sprite_size, position, indexForTableStd);
      else
        wait;
      end if;
   end process;

end testbench;
