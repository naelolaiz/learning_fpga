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
         data: IN STD_LOGIC_VECTOR (ELEMENTS_BITS_COUNT-1 DOWNTO 0);
         read_address: IN INTEGER RANGE 0 to ARRAY_SIZE-1;
         output: OUT STD_LOGIC_VECTOR (ELEMENTS_BITS_COUNT-1 DOWNTO 0)
   );
END single_clock_rom;

ARCHITECTURE rtl OF single_clock_rom IS
   TYPE romType IS ARRAY(0 TO ARRAY_SIZE-1) OF STD_LOGIC_VECTOR(ELEMENTS_BITS_COUNT-1 DOWNTO 0);


 -- uses VHDL 2008 h(ex)read
 impure function initRomFromFile return romType is
    file data_file : text open read_mode is initFile;
    variable data_fileLine : line;
    variable ROM : romType;
    variable discartedChar : character;
 begin
 -- read file with tables and fill in ROM
    for I in romType'range loop
       if(not endfile(data_file)) then
           readline(data_file, data_fileLine); 
           hread(data_fileLine, ROM(I)); -- vhdl 2008
       else
          ROM(I) := (others => '1'); -- ???????
       end if;
    end loop;
    return ROM;
 end function;

 signal rom : romType := initRomFromFile;
 attribute rom_style : string;
 attribute rom_style of rom : signal is "M9K";

BEGIN
   PROCESS (clock)
   BEGIN
      IF (clock'event AND clock = '1') THEN
         output <= rom(read_address);
      END IF;
   END PROCESS;
END rtl;
