library ieee;
use ieee.std_logic_1164.all;
use IEEE.numeric_std.all;

entity tl_rom_lut is
port (inClock50Mhz    : in std_logic;
      inAddressToRead : in integer range 0 to 31; --std_logic_vector (3 downto 0);
      outReadMemory   : out std_logic_vector(7 downto 0)
     );
end tl_rom_lut;

architecture logic of tl_rom_lut is
   signal sMemoryOutput : std_logic_vector(7 downto 0);
   signal sInAddress    : integer range 0 to 31;

component single_clock_rom is
   GENERIC(
           ARRAY_SIZE          : integer;
           ELEMENTS_BITS_COUNT : integer;
           initFile            : string
   );
   PORT (
         clock: IN STD_LOGIC;
         data: IN STD_LOGIC_VECTOR (ELEMENTS_BITS_COUNT-1 DOWNTO 0);
         read_address: IN INTEGER RANGE 0 to ARRAY_SIZE-1;
         output: OUT STD_LOGIC_VECTOR (ELEMENTS_BITS_COUNT-1 DOWNTO 0)
   );
end component;


begin


  ROM_INSTANCE : single_clock_rom
  generic map(
           ARRAY_SIZE          => 32,
           ELEMENTS_BITS_COUNT => 8,
           initFile            => "MY_ROM.hex"
   )
  port map(clock => inClock50Mhz,
           data => (others => '0'),
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
