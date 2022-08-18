library ieee;
use ieee.std_logic_1164.all;
use IEEE.numeric_std.all;

entity tb_rom_lut is
end tb_rom_lut;

architecture testbench of tb_rom_lut is
   signal sClock         : std_logic                    := '0';
   signal sInAddress     : integer range 0 to 32*16-1   := 0;
   signal sReadByte      : std_logic_vector(8 downto 0) := (others=>'0');
   signal sTestRunning   : boolean                      := true;
   constant CLOCK_PERIOD : time                         := 4 ns;
  ---
   signal sInAddressForSin : std_logic_vector (6 downto 0) := (others => '0');
   signal sInFactor        : integer range -128 to 127     := 2;
   signal sOutProduct      : integer range -256 to 255     := 0;
   signal sOutDone         : std_logic                     := '0';


begin

sClock <= not sClock after CLOCK_PERIOD / 2 when sTestRunning;


DUT : entity work.tl_rom_lut(logic)
port map (inClock50Mhz => sClock,
          inAddressToRead => sInAddress,
          outReadMemory => sReadByte);

   read_all_addresses : process
   begin
      for address in 0 to 32*16-1 loop
         sInAddress <= address;
         wait for CLOCK_PERIOD * 2;
         -- assert (to_integer(unsigned(sReadByte)) = 31 - address)
         --   report "wrong read value" severity error;
      end loop;
      wait;
   end process;



DUT2 : entity work.tl_sin_lut_reader(logic_sin_lut_reader)
port map (inClock50Mhz    => sClock,
          inAddressToRead => sInAddressForSin,
          inFactor        => sInFactor,
          outProduct      => sOutProduct,
          outDone         => sOutDone);
   
read_sin_values : process
   begin
      for address in 0 to 4*32*16-1 loop
         sInAddressForSin  <= std_logic_vector(to_unsigned(address, 7));
         wait for CLOCK_PERIOD * 2;
         -- assert (to_integer(unsigned(sReadByte)) = 31 - address)
         --   report "wrong read value" severity error;
      end loop;
      sTestRunning <= false;
      report "simulation done!" severity note;
      wait;
   end process;

end testbench;