library ieee;
use ieee.std_logic_1164.all;
use IEEE.numeric_std.all;

entity tb_rom_lut is
end tb_rom_lut;

architecture testbench of tb_rom_lut is
   signal sClock        : std_logic                    := '0';
   signal sInAddress    : integer range 0 to 32*16-1        := 0;
   signal sReadByte     : std_logic_vector(7 downto 0) := (others=>'0');
   signal sTestRunning  : boolean                      := true;
   constant CLOCK_PERIOD : time := 4 ns;
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
      sTestRunning <= false;
      report "simulation done!" severity note;
      wait;
   end process;
end testbench;
