-- library ieee;
-- use ieee.std_logic_1164.all;
-- 
-- package definitions is
--     type arrayOfWords is array (natural range <>) of std_logic_vector; -- requires vhdl-08
-- end package;
--library work;
--use work.definitions.all;

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


 -- uses VHDL 2008 hread
 impure function initRomFromFile return romType is
  file data_file : text open read_mode is initFile;
  variable data_fileLine : line;
  variable ROM : romType;
  variable discartedChar : character;
 begin
  for I in romType'range loop
   readline(data_file, data_fileLine); 
   hread(data_fileLine, ROM(I)); -- vhdl 2008
  end loop;
  return ROM;
 end function;
 signal rom : romType := initRomFromFile;
 attribute rom_style : string;
 attribute rom_style of rom : signal is "M9K";




  -- constant ram_block: MEM;
   --(
--   std_logic_vector(to_unsigned(31, ELEMENTS_BITS_COUNT)),
--   std_logic_vector(to_unsigned(30, ELEMENTS_BITS_COUNT)),
--   std_logic_vector(to_unsigned(29, ELEMENTS_BITS_COUNT)),
--   std_logic_vector(to_unsigned(28, ELEMENTS_BITS_COUNT)),
--   std_logic_vector(to_unsigned(27, ELEMENTS_BITS_COUNT)),
--   std_logic_vector(to_unsigned(26, ELEMENTS_BITS_COUNT)),
--   std_logic_vector(to_unsigned(25, ELEMENTS_BITS_COUNT)),
--   std_logic_vector(to_unsigned(24, ELEMENTS_BITS_COUNT)),
--   std_logic_vector(to_unsigned(23, ELEMENTS_BITS_COUNT)),
--   std_logic_vector(to_unsigned(22, ELEMENTS_BITS_COUNT)),
--   std_logic_vector(to_unsigned(21, ELEMENTS_BITS_COUNT)),
--   std_logic_vector(to_unsigned(20, ELEMENTS_BITS_COUNT)),
--   std_logic_vector(to_unsigned(19, ELEMENTS_BITS_COUNT)),
--   std_logic_vector(to_unsigned(18, ELEMENTS_BITS_COUNT)),
--   std_logic_vector(to_unsigned(17, ELEMENTS_BITS_COUNT)),
--   std_logic_vector(to_unsigned(16, ELEMENTS_BITS_COUNT)),
--   std_logic_vector(to_unsigned(15, ELEMENTS_BITS_COUNT)),
--   std_logic_vector(to_unsigned(14, ELEMENTS_BITS_COUNT)),
--   std_logic_vector(to_unsigned(13, ELEMENTS_BITS_COUNT)),
--   std_logic_vector(to_unsigned(12, ELEMENTS_BITS_COUNT)),
--   std_logic_vector(to_unsigned(11, ELEMENTS_BITS_COUNT)),
--   std_logic_vector(to_unsigned(10, ELEMENTS_BITS_COUNT)),
--   std_logic_vector(to_unsigned(9, ELEMENTS_BITS_COUNT)),
--   std_logic_vector(to_unsigned(8, ELEMENTS_BITS_COUNT)),
--   std_logic_vector(to_unsigned(7, ELEMENTS_BITS_COUNT)),
--   std_logic_vector(to_unsigned(6, ELEMENTS_BITS_COUNT)),
--   std_logic_vector(to_unsigned(5, ELEMENTS_BITS_COUNT)),
--   std_logic_vector(to_unsigned(4, ELEMENTS_BITS_COUNT)),
--   std_logic_vector(to_unsigned(3, ELEMENTS_BITS_COUNT)),
--   std_logic_vector(to_unsigned(2, ELEMENTS_BITS_COUNT)),
--   std_logic_vector(to_unsigned(1, ELEMENTS_BITS_COUNT)),
--   std_logic_vector(to_unsigned(0, ELEMENTS_BITS_COUNT))
   --);
--attribute romstyle : string;
--attribute romstyle of ram_block : constant is "M9K";

BEGIN
--generateInitValues : for index in  0 to ARRAY_SIZE-1 generate
--   ram_block(index) <= (ARRAY_SIZE-1) - index;
--end generate;
   PROCESS (clock)
   BEGIN
      IF (clock'event AND clock = '1') THEN
         output <= rom(read_address);
      END IF;
   END PROCESS;
END rtl;
