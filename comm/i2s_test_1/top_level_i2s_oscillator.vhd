-- top_level_i2s_oscillator.vhd
--
-- Mono single-tone I2S source: an NCO ticks once per audio sample,
-- producing a signed 16-bit sine which is sign-extended (left-shifted
-- by 8) into the 24-bit I2S frame the master serialises.
--
-- The default phase increment yields 1 kHz at 96 kHz sample rate:
--   phaseInc = round(1000 * 2**32 / 96000) = 44_739_242
-- Override the generic to retune. Both blocks share active-high
-- reset polarity, so iReset drives both directly.

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity top_level_i2s_oscillator is
generic (
  PHASE_INC : integer := 44739242                        -- 1 kHz / 96 kHz Fs * 2^32
);
port ( iReset : in std_logic := '0';                      -- active-high
       iClock50Mhz : in std_logic := '0';
       oMasterClock : out std_logic := '0';
       oLeftRightClock : out std_logic := '0';            -- word select (= Fs)
       oSerialBitClock : out std_logic := '0';            -- BCK / data clock
       oData : out std_logic := '0'                       -- SDATA, MSB-first
       );
end entity;


architecture rtl of top_level_i2s_oscillator is
constant phaseInc : std_logic_vector (31 downto 0) := std_logic_vector(to_unsigned(PHASE_INC,32));
signal sSineNumber : std_logic_vector(15 downto 0);       -- signed
signal mySignalL : std_logic_vector (23 downto 0) := (others => '0');
signal mySignalR : std_logic_vector (23 downto 0) := (others => '0');
signal sLeftRight : std_logic := '0';
begin
  waveform_generator : entity work.nco_sine(rtl)
  port map(clk => sLeftRight,
           reset => iReset,
	   sin_out => sSineNumber,
	   phase_inc => phaseInc);

   i2s_transmiter : entity work.i2s_master(rtl)
   generic map(CLK_FREQ => 50000000)
   port map(reset => iReset,
            clk => iClock50Mhz,
	    mClk =>oMasterClock,
	    lrclk => sLeftRight,
	    sclk => oSerialBitClock,
	    sdata => oData,
	    data_l => mySignalL,
	    data_r => mySignalR);

   oLeftRightClock <= sLeftRight;
   -- 16-bit signed -> 24-bit signed: append 8 LSB zeros (= shift left 8).
   -- The LUT outputs raw signed, so no centering offset is needed.
   mySignalL <= sSineNumber & x"00";
   mySignalR <= sSineNumber & x"00";
end rtl;
