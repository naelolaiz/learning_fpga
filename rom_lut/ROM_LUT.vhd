-- http://www.markharvey.info/rtl/mem_init_21.02.2017/mem_init_21.02.2017.html
library std ;
use std.textio.all; 


LIBRARY ieee;
use ieee.STD_LOGIC_TEXTIO.all;
USE ieee.std_logic_1164.all;
use IEEE.numeric_std.all;

ENTITY single_clock_rom IS
   GENERIC(
           ARRAY_SIZE          : integer := 255;
           ELEMENTS_BITS_COUNT : integer := 8;
           initFile            : string  := "MY_ROM.hex"
   );
   PORT (
         clock: IN STD_LOGIC;
         read_address: IN INTEGER RANGE 0 to ARRAY_SIZE*16 - 1 ; -- we store hexadecimal numbers for a table for each index
         output: OUT STD_LOGIC_VECTOR (ELEMENTS_BITS_COUNT-1 DOWNTO 0)
   );
END single_clock_rom;

ARCHITECTURE rtl OF single_clock_rom IS

   type HexMultiplicationTableType is array (0 to 15) of std_logic_vector(7 downto 0);
   type TableOfTablesType is array (0 to ARRAY_SIZE-1) of HexMultiplicationTableType;


 impure function initRom2FromFile return TableOfTablesType is
    file data_file : text open read_mode is initFile;
    variable data_fileLine : line;
    variable ROM : TableOfTablesType;
    variable temp : std_logic_vector (16*ELEMENTS_BITS_COUNT - 1 downto 0);
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


   TYPE romType IS ARRAY(0 TO ARRAY_SIZE-1) OF STD_LOGIC_VECTOR(ELEMENTS_BITS_COUNT-1 DOWNTO 0);
 -- uses VHDL 2008 h(ex)read
 impure function initRomFromFile return romType is
    file data_file : text open read_mode is initFile;
    variable data_fileLine : line;
    variable ROM : romType;
 begin
 -- read file with tables and fill in ROM
    for I in romType'range loop
       if(not endfile(data_file)) then
           report "aaa " severity note;
           readline(data_file, data_fileLine); 
           hread(data_fileLine, ROM(I)); -- vhdl 2008
       else
          ROM(I) := (others => '1'); -- ???????
       end if;
    end loop;
    return ROM;
 end function;

 constant rom : romType := initRomFromFile;
 attribute rom_style of rom : constant is "M9K";

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

      END IF;
   END PROCESS;
END rtl;
