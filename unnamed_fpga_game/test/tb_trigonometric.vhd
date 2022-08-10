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
     signal sumStd           : std_logic_vector(15 downto 0) := (others => '0');

begin
   testing_values : process
     --variable indexForTable : integer range 0 to 31  := 0;
     --variable inputValue    : integer range -128 to 127 := 0;
     --variable sum           : integer  := 0;

--     constant sprite_size      : Size2D  := (11,11);

   begin


      for indexForTable in 0 to 31 loop
          indexForTableStd <= std_logic_vector(to_unsigned(indexForTable, 5));
          for inputValue in -128 to 127 loop
              inputStd <= std_logic_vector(to_signed(inputValue, 8));
              sumStd <= multiplyBySinLUT(indexForTableStd,
                                         inputStd);
              wait for 1 ns;

          end loop;
      end loop;
      wait;
   end process;
end testbench;
