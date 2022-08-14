-- http://www.markharvey.info/rtl/mem_init_21.02.2017/mem_init_21.02.2017.html
library std ;
use std.textio.all; 


LIBRARY ieee;
use ieee.STD_LOGIC_TEXTIO.all;
USE ieee.std_logic_1164.all;
use IEEE.numeric_std.all;
use IEEE.MATH_REAL.ALL;

ENTITY single_clock_rom IS
   GENERIC(
           ARRAY_SIZE          : integer := 32;
           ELEMENTS_BITS_COUNT : integer := 9;
           initFile            : string  := "SIN_TABLES_MULT_0_TO_HALF_PI_NORMALIZED_TO_UNSIGNED_9_BIT_ON_12_BIT_WORDS.hex"
   );
   PORT (
         clock: IN STD_LOGIC;
         read_address: IN INTEGER RANGE 0 to ARRAY_SIZE*16 - 1 ; -- we store hexadecimal numbers for a table for each index
         output: OUT STD_LOGIC_VECTOR (ELEMENTS_BITS_COUNT-1 DOWNTO 0)
   );
END single_clock_rom;

ARCHITECTURE rtl OF single_clock_rom IS

   type HexMultiplicationTableType is array (0 to 15) of std_logic_vector(ELEMENTS_BITS_COUNT-1 downto 0);
   type TableOfTablesType is array (0 to ARRAY_SIZE-1) of HexMultiplicationTableType;


 impure function initRom2FromFile return TableOfTablesType is
    file data_file : text open read_mode is initFile;
    variable data_fileLine : line;
    variable ROM : TableOfTablesType;
    constant wordSizeCompleteNibbles : integer := natural(ceil(real(ELEMENTS_BITS_COUNT)/real(4)))*4;
    variable temp : std_logic_vector (16*wordSizeCompleteNibbles - 1 downto 0); -- read by nibbles
 begin
 -- read file with tables and fill in ROM
    for I in TableOfTablesType'range loop
       if(not endfile(data_file)) then
           readline(data_file, data_fileLine); 
           hread(data_fileLine, temp); -- vhdl 2008
           for o in 0 to 15 loop
               ROM(I)(o) := temp((o+1)*ELEMENTS_BITS_COUNT-1 downto o*ELEMENTS_BITS_COUNT);
           end loop;
       else
          ROM(I) := (others => (others => '1') ); -- ???????
       end if;
    end loop;
    return ROM;
 end function;

 constant rom2 : TableOfTablesType := initRom2FromFile;
 attribute rom_style : string;
 attribute rom_style of rom2 : constant is "M9K";

BEGIN
   PROCESS (clock)
     variable tableOfTablesIdx : natural := 0;
     variable tableIdx         : natural := 0;

   BEGIN
      IF (clock'event AND clock = '1') THEN
         --output <= rom(read_address);
         tableOfTablesIdx := read_address / 16;
         tableIdx := read_address mod 16;
         output <= rom2(tableOfTablesIdx)(tableIdx);
         --output <= rom2(tableOfTablesIdx)(tableIdx);
         --output <= rom2(tableOfTablesIdx)(15 - tableIdx); -- the words in memory are read from "right to left"

      END IF;
   END PROCESS;
END rtl;
