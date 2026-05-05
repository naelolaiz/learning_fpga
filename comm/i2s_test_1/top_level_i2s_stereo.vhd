library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
use IEEE.NUMERIC_STD.ALL;


entity top_level_i2s_stereo_oscillator is
  generic ( LEFT_OSCILLATOR_FREQUENCY : integer := 440;
            RIGHT_OSCILLATOR_FREQUENCY : integer := 450;
	    SAMPLE_RATE : integer := 96000);
  port ( iReset : std_logic := '1';
         iClock50Mhz : std_logic := '0';
	 oMasterClock : out std_logic := '0'; -- master clock
	 oLeftRightClock : out std_logic := '0'; -- word select
	 oSerialBitClock : out std_logic := '0'; -- sclk  (clock for data)
	 oData : out std_logic := '0'
        );
end top_level_i2s_stereo_oscillator;

architecture rtl of top_level_i2s_stereo_oscillator is
constant phase_inc_l : std_logic_vector(31 downto 0) :=  std_logic_vector(to_unsigned(19685266,32)); -- 2**32 * LEFT_OSCILLATOR_FREQUENCY / SAMPLE_RATE,32));
constant phase_inc_r : std_logic_vector(31 downto 0) :=  std_logic_vector(to_unsigned(20132659,32)); -- 2**32 * RIGHT_OSCILLATOR_FREQUENCY / SAMPLE_RATE,32));
signal mySignalL : std_logic_vector (23 downto 0) := (others => '0');
signal mySignalR : std_logic_vector (23 downto 0) := (others => '0');
signal sLeftRight : std_logic := '0';
signal sSineNumberL : std_logic_vector(15 downto 0);
signal sSineNumberR : std_logic_vector(15 downto 0);
begin

i2s_master_instance : entity work.i2s_master(rtl)
generic map (CLK_FREQ => 50000000)
port map (reset => not iReset,
          clk => iClock50Mhz,
	    mClk =>oMasterClock,
	    lrclk => sLeftRight,
	    sclk => oSerialBitClock,
	    sdata => oData,
	    data_l => mySignalL,
	    data_r => mySignalR);


function_generator_instance : entity work.fn_generator_stereo_sine
port map (clk => sLeftRight,
          reset => iReset,
	  phase_inc_left => phase_inc_l,
	  phase_inc_right => phase_inc_r,
	  sin_out_left => sSineNumberL,
	  sin_out_right => sSineNumberR);

   oLeftRightClock <= sLeftRight;
   mySignalL <= std_logic_vector(to_unsigned(to_integer(unsigned(sSineNumberL) - 8192) * 256 , 24));
   mySignalR <= std_logic_vector(to_unsigned(to_integer(unsigned(sSineNumberR) - 8192) * 256 , 24));
	  
end rtl;
