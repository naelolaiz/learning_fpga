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
-- constant phaseInc : std_logic_vector (31 downto 0) := std_logic_vector(to_unsigned(85899,32)); -- 1000 Hz / 50000000Hz * 2^32
constant phaseInc : std_logic_vector (31 downto 0) := std_logic_vector(to_unsigned(44739242,32)); -- 1 kHz / 96kHz * 2^32
signal sSineNumber : std_logic_vector(15 downto 0);
signal mySignalL : std_logic_vector (23 downto 0) := (others => '0');
signal mySignalR : std_logic_vector (23 downto 0) := (others => '0');
signal sLeftRight : std_logic := '0';
signal rightBinarySignal : std_logic := '0';
begin
  waveform_generator : entity work.waveform_gen_14addr_16value(rtl)
  port map(clk => sLeftRight,
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
--   process (sLeftRight)
--   begin
--   if sLeftRight'event and sLeftRight = '1' then
--      rightBinarySignal <= not rightBinarySignal;
--   end if;
--   end process;

   oLeftRightClock <= sLeftRight;
   mySignalL <= std_logic_vector(to_unsigned(to_integer(unsigned(sSineNumber) - 8192) * 256 , 24));
   mySignalR <= std_logic_vector(to_unsigned(to_integer(unsigned(sSineNumber) - 8192) * 256 , 24));
   --mySignalR <= ("111111110000000000000000") when rightBinarySignal = '1' else (others => '0');
end rtl;
