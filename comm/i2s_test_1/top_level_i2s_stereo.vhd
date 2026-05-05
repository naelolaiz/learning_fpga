-- top_level_i2s_stereo.vhd
--
-- Two-tone I2S source: separate NCO per channel, separate phase
-- increment per channel. Defaults are 440 Hz and 450 Hz at 96 kHz Fs
-- - close enough to alias as a slow beat (10 Hz wobble in mono mix,
-- clear separation through stereo headphones).

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;


entity top_level_i2s_stereo is
  generic ( PHASE_INC_LEFT  : integer := 19685266;        -- 440 Hz @ 96 kHz Fs
            PHASE_INC_RIGHT : integer := 20132659         -- 450 Hz @ 96 kHz Fs
            );
  port ( iReset : std_logic := '0';                       -- active-high
         iClock50Mhz : std_logic := '0';
	 oMasterClock : out std_logic := '0';
	 oLeftRightClock : out std_logic := '0';          -- word select (= Fs)
	 oSerialBitClock : out std_logic := '0';          -- BCK
	 oData : out std_logic := '0'                     -- SDATA, MSB-first
        );
end top_level_i2s_stereo;

architecture rtl of top_level_i2s_stereo is
constant phase_inc_l : std_logic_vector(31 downto 0) := std_logic_vector(to_unsigned(PHASE_INC_LEFT,32));
constant phase_inc_r : std_logic_vector(31 downto 0) := std_logic_vector(to_unsigned(PHASE_INC_RIGHT,32));
signal mySignalL : std_logic_vector (23 downto 0) := (others => '0');
signal mySignalR : std_logic_vector (23 downto 0) := (others => '0');
signal sLeftRight : std_logic := '0';
signal sSineNumberL : std_logic_vector(15 downto 0);     -- signed
signal sSineNumberR : std_logic_vector(15 downto 0);     -- signed
begin

i2s_master_instance : entity work.i2s_master(rtl)
generic map (CLK_FREQ => 50000000)
port map (reset => iReset,
          clk => iClock50Mhz,
	    mClk =>oMasterClock,
	    lrclk => sLeftRight,
	    sclk => oSerialBitClock,
	    sdata => oData,
	    data_l => mySignalL,
	    data_r => mySignalR);


nco_left : entity work.nco_sine(rtl)
port map (clk => sLeftRight,
          reset => iReset,
	  phase_inc => phase_inc_l,
	  sin_out => sSineNumberL);

nco_right : entity work.nco_sine(rtl)
port map (clk => sLeftRight,
          reset => iReset,
	  phase_inc => phase_inc_r,
	  sin_out => sSineNumberR);

   oLeftRightClock <= sLeftRight;
   -- 16-bit signed -> 24-bit signed: append 8 LSB zeros (= shift left 8).
   -- The LUT outputs raw signed, so no centering offset is needed.
   mySignalL <= sSineNumberL & x"00";
   mySignalR <= sSineNumberR & x"00";

end rtl;
