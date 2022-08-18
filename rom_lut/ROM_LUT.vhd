-- http://www.markharvey.info/rtl/mem_init_21.02.2017/mem_init_21.02.2017.html
library std ;
use std.textio.all; 


LIBRARY ieee;
use ieee.STD_LOGIC_TEXTIO.all;
USE ieee.std_logic_1164.all;
use IEEE.numeric_std.all;
--use IEEE.MATH_REAL.ALL;

ENTITY single_clock_rom IS
   GENERIC(
           ARRAY_SIZE          : integer := 32;
           ELEMENTS_BITS_COUNT : integer := 9
   );
   PORT (
         clock              : in std_logic;
         read_angle_idx     : in std_logic_vector(6 downto 0); -- table of 32 elements, * 4 quadrants (0-127)
         nibble_product_idx : in std_logic_vector(3 downto 0); -- multiplication table of hex number

         --  INTEGER RANGE 0 to ARRAY_SIZE*4*16 - 1 ; -- we store hexadecimal numbers for a table for each index
         output: OUT STD_LOGIC_VECTOR (ELEMENTS_BITS_COUNT DOWNTO 0) -- extra bit for sign. Currently 9 + sign
   );
END single_clock_rom;

ARCHITECTURE rtl OF single_clock_rom IS

   type HexMultiplicationTableType is array (0 to 15) of std_logic_vector(ELEMENTS_BITS_COUNT-1 downto 0);
   type TableOfTablesType is array (0 to ARRAY_SIZE-1) of HexMultiplicationTableType;

-- IMPORTANT!!!!!! In order to synthesize this as BRAM THIS NEEDS TO BE SIGNAL, NOT CONSTANT! Otherwise it will use logic elements instead of BRAM.
 signal rom : TableOfTablesType :=
((9x"000", 9x"000", 9x"000", 9x"000", 9x"000", 9x"000", 9x"000", 9x"000", 9x"000", 9x"000", 9x"000", 9x"000", 9x"000", 9x"000", 9x"000", 9x"000"), -- sin(0) (redundant... TODO: remove) 
 (9x"000", 9x"002", 9x"003", 9x"005", 9x"006", 9x"008", 9x"009", 9x"00b", 9x"00c", 9x"00e", 9x"00f", 9x"011", 9x"012", 9x"014", 9x"015", 9x"017"),
 (9x"000", 9x"003", 9x"006", 9x"009", 9x"00c", 9x"00f", 9x"012", 9x"015", 9x"018", 9x"01b", 9x"01e", 9x"021", 9x"024", 9x"028", 9x"02b", 9x"02e"),
 (9x"000", 9x"005", 9x"009", 9x"00e", 9x"012", 9x"017", 9x"01b", 9x"020", 9x"024", 9x"029", 9x"02d", 9x"032", 9x"037", 9x"03b", 9x"040", 9x"044"),
 (9x"000", 9x"006", 9x"00c", 9x"012", 9x"018", 9x"01e", 9x"024", 9x"02a", 9x"030", 9x"036", 9x"03c", 9x"043", 9x"049", 9x"04f", 9x"055", 9x"05b"),
 (9x"000", 9x"008", 9x"00f", 9x"017", 9x"01e", 9x"026", 9x"02d", 9x"035", 9x"03c", 9x"044", 9x"04b", 9x"053", 9x"05a", 9x"062", 9x"069", 9x"071"),
 (9x"000", 9x"009", 9x"012", 9x"01b", 9x"024", 9x"02d", 9x"036", 9x"03f", 9x"048", 9x"051", 9x"05a", 9x"063", 9x"06c", 9x"075", 9x"07e", 9x"087"),
 (9x"000", 9x"00a", 9x"015", 9x"01f", 9x"02a", 9x"034", 9x"03f", 9x"049", 9x"054", 9x"05e", 9x"068", 9x"073", 9x"07d", 9x"088", 9x"092", 9x"09d"),
 (9x"000", 9x"00c", 9x"018", 9x"024", 9x"02f", 9x"03b", 9x"047", 9x"053", 9x"05f", 9x"06b", 9x"077", 9x"082", 9x"08e", 9x"09a", 9x"0a6", 9x"0b2"),
 (9x"000", 9x"00d", 9x"01b", 9x"028", 9x"035", 9x"042", 9x"050", 9x"05d", 9x"06a", 9x"077", 9x"085", 9x"092", 9x"09f", 9x"0ac", 9x"0ba", 9x"0c7"),
 (9x"000", 9x"00f", 9x"01d", 9x"02c", 9x"03a", 9x"049", 9x"058", 9x"066", 9x"075", 9x"084", 9x"092", 9x"0a1", 9x"0af", 9x"0be", 9x"0cd", 9x"0db"),
 (9x"000", 9x"010", 9x"020", 9x"030", 9x"040", 9x"050", 9x"060", 9x"070", 9x"07f", 9x"08f", 9x"09f", 9x"0af", 9x"0bf", 9x"0cf", 9x"0df", 9x"0ef"),
 (9x"000", 9x"011", 9x"022", 9x"034", 9x"045", 9x"056", 9x"067", 9x"079", 9x"08a", 9x"09b", 9x"0ac", 9x"0bd", 9x"0cf", 9x"0e0", 9x"0f1", 9x"102"),
 (9x"000", 9x"012", 9x"025", 9x"037", 9x"04a", 9x"05c", 9x"06f", 9x"081", 9x"094", 9x"0a6", 9x"0b9", 9x"0cb", 9x"0de", 9x"0f0", 9x"103", 9x"115"),
 (9x"000", 9x"014", 9x"027", 9x"03b", 9x"04f", 9x"062", 9x"076", 9x"08a", 9x"09d", 9x"0b1", 9x"0c5", 9x"0d8", 9x"0ec", 9x"100", 9x"113", 9x"127"),
 (9x"000", 9x"015", 9x"02a", 9x"03e", 9x"053", 9x"068", 9x"07d", 9x"092", 9x"0a7", 9x"0bb", 9x"0d0", 9x"0e5", 9x"0fa", 9x"10f", 9x"123", 9x"138"),
 (9x"000", 9x"016", 9x"02c", 9x"042", 9x"058", 9x"06e", 9x"084", 9x"099", 9x"0af", 9x"0c5", 9x"0db", 9x"0f1", 9x"107", 9x"11d", 9x"133", 9x"149"),
 (9x"000", 9x"017", 9x"02e", 9x"045", 9x"05c", 9x"073", 9x"08a", 9x"0a1", 9x"0b8", 9x"0cf", 9x"0e6", 9x"0fd", 9x"114", 9x"12b", 9x"142", 9x"159"),
 (9x"000", 9x"018", 9x"030", 9x"048", 9x"060", 9x"078", 9x"090", 9x"0a8", 9x"0c0", 9x"0d8", 9x"0f0", 9x"108", 9x"120", 9x"138", 9x"14f", 9x"167"),
 (9x"000", 9x"019", 9x"032", 9x"04b", 9x"064", 9x"07c", 9x"095", 9x"0ae", 9x"0c7", 9x"0e0", 9x"0f9", 9x"112", 9x"12b", 9x"144", 9x"15d", 9x"175"),
 (9x"000", 9x"01a", 9x"034", 9x"04d", 9x"067", 9x"081", 9x"09b", 9x"0b4", 9x"0ce", 9x"0e8", 9x"102", 9x"11c", 9x"135", 9x"14f", 9x"169", 9x"183"),
 (9x"000", 9x"01b", 9x"035", 9x"050", 9x"06a", 9x"085", 9x"0a0", 9x"0ba", 9x"0d5", 9x"0ef", 9x"10a", 9x"124", 9x"13f", 9x"15a", 9x"174", 9x"18f"),
 (9x"000", 9x"01b", 9x"037", 9x"052", 9x"06d", 9x"089", 9x"0a4", 9x"0bf", 9x"0db", 9x"0f6", 9x"111", 9x"12d", 9x"148", 9x"163", 9x"17f", 9x"19a"),
 (9x"000", 9x"01c", 9x"038", 9x"054", 9x"070", 9x"08c", 9x"0a8", 9x"0c4", 9x"0e0", 9x"0fc", 9x"118", 9x"134", 9x"150", 9x"16c", 9x"188", 9x"1a4"),
 (9x"000", 9x"01d", 9x"039", 9x"056", 9x"073", 9x"08f", 9x"0ac", 9x"0c8", 9x"0e5", 9x"102", 9x"11e", 9x"13b", 9x"158", 9x"174", 9x"191", 9x"1ae"),
 (9x"000", 9x"01d", 9x"03a", 9x"058", 9x"075", 9x"092", 9x"0af", 9x"0cc", 9x"0ea", 9x"107", 9x"124", 9x"141", 9x"15e", 9x"17b", 9x"199", 9x"1b6"),
 (9x"000", 9x"01e", 9x"03b", 9x"059", 9x"077", 9x"094", 9x"0b2", 9x"0d0", 9x"0ed", 9x"10b", 9x"129", 9x"146", 9x"164", 9x"182", 9x"19f", 9x"1bd"),
 (9x"000", 9x"01e", 9x"03c", 9x"05a", 9x"078", 9x"096", 9x"0b4", 9x"0d2", 9x"0f1", 9x"10f", 9x"12d", 9x"14b", 9x"169", 9x"187", 9x"1a5", 9x"1c3"),
 (9x"000", 9x"01e", 9x"03d", 9x"05b", 9x"07a", 9x"098", 9x"0b6", 9x"0d5", 9x"0f3", 9x"112", 9x"130", 9x"14e", 9x"16d", 9x"18b", 9x"1aa", 9x"1c8"),
 (9x"000", 9x"01f", 9x"03d", 9x"05c", 9x"07b", 9x"099", 9x"0b8", 9x"0d7", 9x"0f5", 9x"114", 9x"133", 9x"151", 9x"170", 9x"18f", 9x"1ad", 9x"1cc"),
 (9x"000", 9x"01f", 9x"03e", 9x"05d", 9x"07b", 9x"09a", 9x"0b9", 9x"0d8", 9x"0f7", 9x"116", 9x"135", 9x"153", 9x"172", 9x"191", 9x"1b0", 9x"1cf"),
 (9x"000", 9x"01f", 9x"03e", 9x"05d", 9x"07c", 9x"09b", 9x"0ba", 9x"0d9", 9x"0f8", 9x"117", 9x"136", 9x"155", 9x"174", 9x"193", 9x"1b1", 9x"1d0")); -- sin PI/2 [*0,*1,..,*15]


 -- Not really needed. Commented to make it more generic. 
 --attribute rom_style : string;
 --attribute rom_style of rom : signal is "M9K";

BEGIN
   PROCESS (clock)
     variable tableOfTablesIdx        : unsigned (4 downto 0) := (others => '0');
     --variable tableIdx                : unsigned (3 downto 0) := (others => '0');
     alias    secondOrFourthCuadrant  : std_logic is read_angle_idx(5); -- on HIGH the index should be inverted
     alias    thirdOrFourthCuadrant   : std_logic is read_angle_idx(6); -- on HIGH the output should be negative
     alias    firstQuadrantTableIndex : std_logic_vector (4 downto 0) is read_angle_idx (4 downto 0);

   BEGIN
      IF (clock'event AND clock = '1') THEN
         case secondOrFourthCuadrant is
           when '1'    => 
             tableOfTablesIdx := 31 - unsigned(firstQuadrantTableIndex);
           when '0'    =>
             tableOfTablesIdx := unsigned(firstQuadrantTableIndex);
           when others => 
         end case;
         case thirdOrFourthCuadrant is
            when '1'    =>
               output <= std_logic_vector(to_signed(to_integer(signed(rom(to_integer(unsigned(tableOfTablesIdx)))(to_integer(unsigned(nibble_product_idx))))) * (-1), ELEMENTS_BITS_COUNT+1)) ;
            when '0'    =>
               output <= "0" & rom(to_integer(unsigned(tableOfTablesIdx)))(to_integer(unsigned(nibble_product_idx)));
            when others =>
         end case;
      END IF;
   END PROCESS;
END rtl;
