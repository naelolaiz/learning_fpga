library ieee;
use ieee.std_logic_1164.all;
use IEEE.numeric_std.all;

entity tl_rom_lut is
port (inClock50Mhz    : in std_logic;
      inAddressToRead : in integer range 0 to 32*16 -1; --std_logic_vector (3 downto 0);
      outReadMemory   : out std_logic_vector(8 downto 0)
     );
end tl_rom_lut;

architecture logic of tl_rom_lut is
   signal sMemoryOutput : std_logic_vector(8 downto 0);
   signal sInAddress    : integer range 0 to 32*16-1;

component single_clock_rom is
   GENERIC(
           ARRAY_SIZE          : integer;
           ELEMENTS_BITS_COUNT : integer;
           initFile            : string
   );
   PORT (
         clock: IN STD_LOGIC;
         read_address: IN INTEGER RANGE 0 to ARRAY_SIZE*16-1;
         output: OUT STD_LOGIC_VECTOR (ELEMENTS_BITS_COUNT-1 DOWNTO 0)
   );
end component;


begin


  ROM_INSTANCE : single_clock_rom
  generic map(
           ARRAY_SIZE          => 32,
           ELEMENTS_BITS_COUNT => 9,
           initFile            => "SIN_TABLES_MULT_0_TO_HALF_PI_NORMALIZED_TO_UNSIGNED_9_BIT_ON_12_BIT_WORDS.hex"
   )
  port map(clock => inClock50Mhz,
           read_address => sInAddress,
           output => sMemoryOutput);


outReadMemory <= sMemoryOutput;

   syncProcess : process (inClock50Mhz)
   begin
      if rising_edge(inClock50Mhz) then
         sInAddress <= inAddressToRead;
      end if;
   end process;

end logic;
