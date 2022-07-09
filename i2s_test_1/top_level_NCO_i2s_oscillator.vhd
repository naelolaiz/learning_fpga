library ieee;
use ieee.std_logic_1164.all;
--use ieee.std_logic_arith.all;
use ieee.numeric_std.all;

entity top_level_NCO_i2s_oscillator is 
port ( iReset : in std_logic := '0';
       iClock50Mhz : in std_logic := '0';
       oMasterClock : out std_logic := '0';
       oLeftRightClock : out std_logic := '0'; -- word select
       oSerialBitClock : out std_logic := '0'; -- sclk, bck. clock for data
       oData : out std_logic := '0'
       );
end entity;


architecture rtl of top_level_NCO_i2s_oscillator is
constant phaseInc : std_logic_vector (31 downto 0) := std_logic_vector(to_unsigned(171798691,32)); --858993459, 32)); --10 * 4294967296 / 50; -- 10 MHz * 2^32 / 50MHz
signal sSineNumber : std_logic_vector(15 downto 0);
signal mySignalL : std_logic_vector (23 downto 0);
signal mySignalR : std_logic_vector (23 downto 0);
signal sLeftRight : std_logic := '0';
signal counter : integer :=0;
function reverse_any_vector (a: in std_logic_vector)
return std_logic_vector is
  variable result: std_logic_vector(a'RANGE);
  alias aa: std_logic_vector(a'REVERSE_RANGE) is a;
begin
  for i in aa'RANGE loop
    result(i) := aa(i);
  end loop;
  return result;
end; -- function reverse_any_vector
begin

process (sLeftRight)
begin
   if sLeftRight'event and sLeftRight = '1' then
      counter <= counter + 1;
   end if;
end process;

  waveform_generator : entity work.waveform_gen_14addr_16value(rtl)
  port map( clk => sLeftRight,
           reset => iReset,
	   sin_out => sSineNumber,
	   phase_inc => phaseInc);

   i2s_transmiter : entity work.i2s_master(rtl)
   generic map(CLK_FREQ => 50000000)
   port map(reset => not iReset,
            clk => iClock50Mhz,
	    mClk =>oMasterClock,
	    lrclk => sLeftRight,
	    sclk => oSerialBitClock,
	    sdata => oData,
	    data_l => mySignalL,
	    data_r => mySignalR);
   oLeftRightClock <= sLeftRight;
   mySignalL (15 downto 0) <= sSineNumber; --(others => '0'); -- when std_logic_vector(to_unsigned(counter, 4))(3) = '0' else (others => '1');
   mySignalR (15 downto 0) <= sSineNumber; --(others => '0'); -- when std_logic_vector(to_unsigned(counter, 4))(3) = '1' else (others => '1');
end rtl;
