library IEEE;
use IEEE.STD_LOGIC_1164.all;

package uda1380_control_definitions is
   constant DEVICE_ADDR             : std_logic_vector(6 downto 0) := "0011000";
   constant UDA1380_REG_EVALCLK     : std_logic_vector(6 downto 0) := "0000000";
   constant UDA1380_REG_I2S         : std_logic_vector(6 downto 0) := "0000001";
   constant UDA1380_REG_PWRCTRL     : std_logic_vector(6 downto 0) := "0000010";
   constant UDA1380_REG_ANAMIX      : std_logic_vector(6 downto 0) := "0000011";
   constant UDA1380_REG_HEADAMP     : std_logic_vector(6 downto 0) := "0000100";
   constant UDA1380_REG_MSTRVOL     : std_logic_vector(6 downto 0) := "0010000";
   constant UDA1380_REG_MIXVOL      : std_logic_vector(6 downto 0) := "0010001";
   constant UDA1380_REG_MODEBBT     : std_logic_vector(6 downto 0) := "0010010";
   constant UDA1380_REG_MSTRMUTE    : std_logic_vector(6 downto 0) := "0010011";
   constant UDA1380_REG_MIXSDO      : std_logic_vector(6 downto 0) := "0010100";
   constant UDA1380_REG_DECVOL      : std_logic_vector(6 downto 0) := "0100000";
   constant UDA1380_REG_PGA         : std_logic_vector(6 downto 0) := "0100001";
   constant UDA1380_REG_ADC         : std_logic_vector(6 downto 0) := "0100010";
   constant UDA1380_REG_AGC         : std_logic_vector(6 downto 0) := "0100011";
   constant UDA1380_REG_L3          : std_logic_vector(6 downto 0) := "1111111";
   constant UDA1380_REG_HEADPHONE   : std_logic_vector(6 downto 0) := "0011000";
   constant UDA1380_REG_DEC         : std_logic_vector(6 downto 0) := "0101000";
   
   -- BITS for register address 00H (Evaluation modes and clock settings) : 2 bytes
   constant EN_ADC_BIT                : integer := 11; -- ADC clock enable (default: 0)
   constant EN_DEC_BIT                : integer := 10; -- decimator clock enable (default: 1)
   constant EN_DAC_BIT                : integer := 9;  -- FSDAC clock enable (default: 0)
   constant EN_INTERP_BIT             : integer := 8;  -- Interpolator clock enable (default: 1)
   constant ADC_CLK_BIT               : integer := 5;  -- ADC clock select (0(default)=SYSCLK; 1=WSPLL)
   constant DAC_CLK_BIT               : integer := 4;  -- DAC clock select (0(default)=SYSCLK; 1=WSPLL)
   constant SYS_DIV_1_BIT             : integer := 3;  -- bit 1 of dividers for system clock input
   constant SYS_DIV_0_BIT             : integer := 2;  -- bit 0 of dividers for system clock input
   constant WSPLL_1_BIT               : integer := 1; -- WSPLL setting (bit 1)
   constant WSPLL_0_BIT               : integer := 0; -- WSPLL setting (bit 0)
   
   -- Dividers for system clock input
   constant SYS_DIV_256Fs           : std_logic_vector(1 downto 0) := "00";
   constant SYS_DIV_384Fs           : std_logic_vector(1 downto 0) := "01";
   constant SYS_DIV_512Fs           : std_logic_vector(1 downto 0) := "10";
   constant SYS_DIV_768Fs           : std_logic_vector(1 downto 0) := "11";
   
   -- WSPLL settings
   constant WSPLL_62_5_TO_12_5       : std_logic_vector(1 downto 0) := "00";
   constant WSPLL_12_5_TO_25         : std_logic_vector(1 downto 0) := "01";
   constant WSPLL_25_TO_50           : std_logic_vector(1 downto 0) := "10";
   constant WSPLL_50_TO_100          : std_logic_vector(1 downto 0) := "11";
   
   -- Configuration bits for register address 01 (i2s) : 2 bytes
   constant SFORI_2_BIT    : integer := 10; -- digital data input formats, bit 2 (default: 0)
   constant SFORI_1_BIT    : integer := 9;  -- digital data input formats, bit 1 (default: 0)
   constant SFORI_0_BIT    : integer := 8;  -- digital data input formats, bit 0 (default: 0)
   constant SEL_SOURCE_BIT : integer := 6;  -- digital output interface mode (0(default): decimator; 1: digital mixer output)
   constant SIM_BIT        : integer := 4;  -- digital output interface mode settings (BCK0 PAD. 0 (default): slave; 1: master)
   constant SFORO_2_BIT    : integer := 2;  -- digital data output formats, bit 2 (default: 0)  
   constant SFORO_1_BIT    : integer := 1;  -- digital data output formats, bit 1 (default: 0)
   constant SFORO_0_BIT    : integer := 0;  -- digital data output formats, bit 0 (default: 0)
   
   
   constant SFOR_I2S_BUS            : std_logic_vector(2 downto 0) := "000"; -- default
   constant SFOR_LSB_JUST_16_BIT    : std_logic_vector(2 downto 0) := "001";
   constant SFOR_LSB_JUST_18_BIT    : std_logic_vector(2 downto 0) := "010";
   constant SFOR_LSB_JUST_20_BIT    : std_logic_vector(2 downto 0) := "011";
   constant SFOR_MSB_JUST           : std_logic_vector(2 downto 0) := "101";
   
   -- Configuration bits for register address 02H (Power control settings)
   constant  PON_PLL  : integer := 15; -- Power-on WSPLL (0 (default): power-off; 1: power-on)
   constant  PON_HP   : integer := 13; -- Power-on headphone driver (0(default): power-off; 1: power-on)
   constant  PON_DAC  : integer := 10; -- Power-on DAC (def: 0)
   constant  PON_BIAS : integer := 8;  -- Power-on BIAS 
   constant  EN_AVC   : integer := 7;  -- Enable control AVC
   constant  PON_AVC  : integer := 6;  -- Power-on AVC
   constant  PON_LNA  : integer := 4;  -- Power-on LNA
   constant  PON_PGAL : integer := 3;  -- Power-on PGAL
   constant  PON_ADCL : integer := 2;  -- Power-on ADCL
   constant  PON_PGAR : integer := 1;  -- Power-on PGAR
   constant  PON_ADCR : integer := 0;  -- Power-on ADCR
   
   -- Configuration bits for register address 03H (Analog mixer settings)
   constant  AVCL_5_BIT   : integer := 13; -- Analog volume control, left channel, bit 5
   constant  AVCL_4_BIT   : integer := 12; -- Analog volume control, left channel, bit 4
   constant  AVCL_3_BIT   : integer := 11; -- Analog volume control, left channel, bit 3
   constant  AVCL_2_BIT   : integer := 10; -- Analog volume control, left channel, bit 2
   constant  AVCL_1_BIT   : integer := 9;  -- Analog volume control, left channel, bit 1
   constant  AVCL_0_BIT   : integer := 8;  -- Analog volume control, left channel, bit 0
   constant  AVCR_5_BIT   : integer := 5; -- Analog volume control, right channel, bit 5
   constant  AVCR_4_BIT   : integer := 4; -- Analog volume control, right channel, bit 4
   constant  AVCR_3_BIT   : integer := 3; -- Analog volume control, right channel, bit 3
   constant  AVCR_2_BIT   : integer := 2; -- Analog volume control, right channel, bit 2
   constant  AVCR_1_BIT   : integer := 1; -- Analog volume control, right channel, bit 1
   constant  AVCR_0_BIT   : integer := 0; -- Analog volume control, right channel, bit 0
   
   constant  AVC_VALUE_16_5_dB : std_logic_vector (5 downto 0) := "000000";
   constant  AVC_VALUE_15_dB   : std_logic_vector (5 downto 0) := "000001";
   constant  AVC_VALUE_13_5_dB : std_logic_vector (5 downto 0) := "000010";
   constant  AVC_VALUE_12_dB   : std_logic_vector (5 downto 0) := "000011";
   constant  AVC_VALUE_10_5_dB : std_logic_vector (5 downto 0) := "000100";
   constant  AVC_VALUE_9_dB    : std_logic_vector (5 downto 0) := "000101";
   constant  AVC_VALUE_7_5_dB  : std_logic_vector (5 downto 0) := "000110";
   constant  AVC_VALUE_6_dB    : std_logic_vector (5 downto 0) := "000111";
   constant  AVC_VALUE_4_5_dB  : std_logic_vector (5 downto 0) := "001000";
   constant  AVC_VALUE_3_dB    : std_logic_vector (5 downto 0) := "001001";
   constant  AVC_VALUE_1_5_dB  : std_logic_vector (5 downto 0) := "001010";
   constant  AVC_VALUE_0_dB    : std_logic_vector (5 downto 0) := "001011";
   constant  AVC_VALUE_MINUS_1_5dB    : std_logic_vector (5 downto 0) := "001100";
   constant  AVC_VALUE_MINUS_3dB      : std_logic_vector (5 downto 0) := "001101";
   constant  AVC_VALUE_MINUS_4_5dB    : std_logic_vector (5 downto 0) := "001110";
   constant  AVC_VALUE_MINUS_6dB      : std_logic_vector (5 downto 0) := "001111";
   constant  AVC_VALUE_MINUS_7_5dB    : std_logic_vector (5 downto 0) := "010000";
   constant  AVC_VALUE_MINUS_9dB      : std_logic_vector (5 downto 0) := "010001";
   constant  AVC_VALUE_MINUS_10_5dB   : std_logic_vector (5 downto 0) := "010010";
   constant  AVC_VALUE_MINUS_12dB     : std_logic_vector (5 downto 0) := "010011";
   constant  AVC_VALUE_MINUS_13_5dB   : std_logic_vector (5 downto 0) := "010100";
   constant  AVC_VALUE_MINUS_15dB     : std_logic_vector (5 downto 0) := "010101";
   constant  AVC_VALUE_MINUS_16_5dB   : std_logic_vector (5 downto 0) := "010110";
   constant  AVC_VALUE_MINUS_18dB     : std_logic_vector (5 downto 0) := "010111";
   constant  AVC_VALUE_MINUS_19_5dB   : std_logic_vector (5 downto 0) := "011000";
   constant  AVC_VALUE_MINUS_21dB     : std_logic_vector (5 downto 0) := "011001";
   constant  AVC_VALUE_MINUS_INFINITY  : std_logic_vector (5 downto 0) := "111111";
   
   -- Configuration bits for register address 10H (Analog mixer settings)
   constant  MVCR_7_BIT   : integer := 15; -- Master volume control, right channel, bit 7
   constant  MVCR_6_BIT   : integer := 14; -- Master volume control, right channel, bit 6
   constant  MVCR_5_BIT   : integer := 13; -- Master volume control, right channel, bit 5
   constant  MVCR_4_BIT   : integer := 12; -- Master volume control, right channel, bit 4
   constant  MVCR_3_BIT   : integer := 11; -- Master volume control, right channel, bit 3
   constant  MVCR_2_BIT   : integer := 10; -- Master volume control, right channel, bit 2
   constant  MVCR_1_BIT   : integer := 9;  -- Master volume control, right channel, bit 1
   constant  MVCR_0_BIT   : integer := 8;  -- Master volume control, right channel, bit 0
   constant  MVCL_7_BIT   : integer := 7; -- Master volume control, left channel, bit 7
   constant  MVCL_6_BIT   : integer := 6; -- Master volume control, left channel, bit 6
   constant  MVCL_5_BIT   : integer := 5; -- Master volume control, left channel, bit 5
   constant  MVCL_4_BIT   : integer := 4; -- Master volume control, left channel, bit 4
   constant  MVCL_3_BIT   : integer := 3; -- Master volume control, left channel, bit 3
   constant  MVCL_2_BIT   : integer := 2; -- Master volume control, left channel, bit 2
   constant  MVCL_1_BIT   : integer := 1;  -- Master volume control, left channel, bit 1
   constant  MVCL_0_BIT   : integer := 0;  -- Master volume control, left channel, bit 0
   
   constant  MVC_VALUE_0_dB           : std_logic_vector (7 downto 0) := "00000000";
   constant  MVC_VALUE_MINUS_0_25dB   : std_logic_vector (7 downto 0) := "00000001";
   constant  MVC_VALUE_MINUS_0_5dB    : std_logic_vector (7 downto 0) := "00000010";
   constant  MVC_VALUE_MINUS_0_75dB   : std_logic_vector (7 downto 0) := "00000011";
   constant  MVC_VALUE_MINUS_1dB      : std_logic_vector (7 downto 0) := "00000100";
   constant  MVC_VALUE_MINUS_1_25dB   : std_logic_vector (7 downto 0) := "00000101";
   constant  MVC_VALUE_MINUS_1_5dB    : std_logic_vector (7 downto 0) := "00000110";
   constant  MVC_VALUE_MINUS_1_75dB   : std_logic_vector (7 downto 0) := "00000111";
   constant  MVC_VALUE_MINUS_2_dB     : std_logic_vector (7 downto 0) := "00001000";
   constant  MVC_VALUE_MINUS_2_25dB   : std_logic_vector (7 downto 0) := "00001001";
   constant  MVC_VALUE_MINUS_2_5dB    : std_logic_vector (7 downto 0) := "00001010";
   constant  MVC_VALUE_MINUS_2_75dB   : std_logic_vector (7 downto 0) := "00001011";
   constant  MVC_VALUE_MINUS_3_0dB    : std_logic_vector (7 downto 0) := "00001100";
   constant  MVC_VALUE_MINUS_3_25dB   : std_logic_vector (7 downto 0) := "00001101";
   constant  MVC_VALUE_MINUS_3_5_dB   : std_logic_vector (7 downto 0) := "00001110";
   constant  MVC_VALUE_MINUS_3_75dB   : std_logic_vector (7 downto 0) := "00001111";
   constant  MVC_VALUE_MINUS_4_0dB    : std_logic_vector (7 downto 0) := "00010000";
   constant  MVC_VALUE_MINUS_4_25dB   : std_logic_vector (7 downto 0) := "00010001";
   constant  MVC_VALUE_MINUS_4_5dB    : std_logic_vector (7 downto 0) := "00010010";
   constant  MVC_VALUE_MINUS_4_75dB   : std_logic_vector (7 downto 0) := "00010011";
   constant  MVC_VALUE_MINUS_5_0dB    : std_logic_vector (7 downto 0) := "00010100";
   constant  MVC_VALUE_MINUS_5_25dB   : std_logic_vector (7 downto 0) := "00010101";
   constant  MVC_VALUE_MINUS_5_5dB    : std_logic_vector (7 downto 0) := "00010110";
   constant  MVC_VALUE_MINUS_5_75dB   : std_logic_vector (7 downto 0) := "00010111";
   constant  MVC_VALUE_MINUS_6dB      : std_logic_vector (7 downto 0) := "00011000";
   constant  MVC_VALUE_MINUS_INFINITY : std_logic_vector (7 downto 0) := "11111100";
   
   -- Configuration bits for register address 11H (Digital mixer settings)
   constant  VC2_7_BIT   : integer := 15; -- Digital mixer volume control, channel 2, bit 7
   constant  VC2_6_BIT   : integer := 14; -- Digital mixer volume control, channel 2, bit 6
   constant  VC2_5_BIT   : integer := 13; -- Digital mixer volume control, channel 2, bit 5
   constant  VC2_4_BIT   : integer := 12; -- Digital mixer volume control, channel 2, bit 4
   constant  VC2_3_BIT   : integer := 11; -- Digital mixer volume control, channel 2, bit 3
   constant  VC2_2_BIT   : integer := 10; -- Digital mixer volume control, channel 2, bit 2
   constant  VC2_1_BIT   : integer := 9;  -- Digital mixer volume control, channel 2, bit 1
   constant  VC2_0_BIT   : integer := 8;  -- Digital mixer volume control, channel 2, bit 0
   constant  VC1_7_BIT   : integer := 7;  -- Digital mixer volume control, channel 1, bit 7
   constant  VC1_6_BIT   : integer := 6;  -- Digital mixer volume control, channel 1, bit 6
   constant  VC1_5_BIT   : integer := 5;  -- Digital mixer volume control, channel 1, bit 5
   constant  VC1_4_BIT   : integer := 4;  -- Digital mixer volume control, channel 1, bit 4
   constant  VC1_3_BIT   : integer := 3;  -- Digital mixer volume control, channel 1, bit 3
   constant  VC1_2_BIT   : integer := 2;  -- Digital mixer volume control, channel 1, bit 2
   constant  VC1_1_BIT   : integer := 1;  -- Digital mixer volume control, channel 1, bit 1
   constant  VC1_0_BIT   : integer := 0;  -- Digital mixer volume control, channel 1, bit 0
   
   -- Configuration bits for register address 12H (Mode, bass boost and treble)
   constant  M_1_BIT                 : integer := 15; -- Flat/minimum/maximum setting, bit 1
   constant  M_0_BIT                 : integer := 14; -- Flat/minimum/maximum setting, bit 0
   constant  TREBLE_LEFT_1_BIT       : integer := 13; -- Treble setting left, bit 1
   constant  TREBLE_LEFT_0_BIT       : integer := 12; -- Treble setting left, bit 0
   constant  BASS_BOOST_LEFT_3_BIT   : integer := 11; -- Bass boost setting left, bit 3
   constant  BASS_BOOST_LEFT_2_BIT   : integer := 10; -- Bass boost setting left, bit 2
   constant  BASS_BOOST_LEFT_1_BIT   : integer := 9;  -- Bass boost setting left, bit 1
   constant  BASS_BOOST_LEFT_0_BIT   : integer := 8;  -- Bass boost setting left, bit 0
   constant  TREBLE_RIGHT_1_BIT       : integer := 5; -- Treble setting right, bit 1
   constant  TREBLE_RIGHT_0_BIT       : integer := 4; -- Treble setting right, bit 0
   constant  BASS_BOOST_RIGHT_3_BIT   : integer := 3; -- Bass boost setting right, bit 3
   constant  BASS_BOOST_RIGHT_2_BIT   : integer := 2; -- Bass boost setting right, bit 2
   constant  BASS_BOOST_RIGHT_1_BIT   : integer := 1;  -- Bass boost setting right, bit 1
   constant  BASS_BOOST_RIGHT_0_BIT   : integer := 0;  -- Bass boost setting right, bit 0
   
   constant  M_FLAT      : std_logic_vector (1 downto 0) := "00";
   constant  M_MINIMUM   : std_logic_vector (1 downto 0) := "01";
   constant  M_MAXIMUM   : std_logic_vector (1 downto 0) := "11";
   
   constant  TREBLE_0_0_0dB : std_logic_vector (1 downto 0) := "00";
   constant  TREBLE_0_2_2dB : std_logic_vector (1 downto 0) := "01";
   constant  TREBLE_0_4_4dB : std_logic_vector (1 downto 0) := "10";
   constant  TREBLE_0_6_6dB : std_logic_vector (1 downto 0) := "11";
   
   constant  BASS_BOOST_0_0_0dB   : std_logic_vector (3 downto 0) := "0000";
   constant  BASS_BOOST_0_2_2dB   : std_logic_vector (3 downto 0) := "0001";
   constant  BASS_BOOST_0_4_4dB   : std_logic_vector (3 downto 0) := "0010";
   constant  BASS_BOOST_0_6_6dB   : std_logic_vector (3 downto 0) := "0011";
   constant  BASS_BOOST_0_8_8dB   : std_logic_vector (3 downto 0) := "0100";
   constant  BASS_BOOST_0_10_10dB : std_logic_vector (3 downto 0) := "0101";
   constant  BASS_BOOST_0_12_12dB : std_logic_vector (3 downto 0) := "0110";
   constant  BASS_BOOST_0_14_14dB : std_logic_vector (3 downto 0) := "0111";
   constant  BASS_BOOST_0_16_16dB : std_logic_vector (3 downto 0) := "1000";
   constant  BASS_BOOST_0_18_18dB : std_logic_vector (3 downto 0) := "1001";
   constant  BASS_BOOST_0_20_20dB : std_logic_vector (3 downto 0) := "1010";
   constant  BASS_BOOST_0_22_22dB : std_logic_vector (3 downto 0) := "1011";
   constant  BASS_BOOST_0_24_24dB : std_logic_vector (3 downto 0) := "1100";
   
   
   -- Configuration bits for register address 13H (Master mute, channel de-emphasis and mute)
   constant  MASTER_MUTE_BIT        : integer := 14; -- Master mute (default : 1)
   constant  CHANNEL_2_MUTE_BIT     : integer := 11; -- Channel 2 mute (default: 1)
   constant  DEEMPHASIS_2_2_BIT     : integer := 10; -- De-emphasis for channel 2(?) BIT 2. Default: 0
   constant  DEEMPHASIS_2_1_BIT     : integer := 9;  -- De-emphasis for channel 2(?) BIT 1. Default: 0
   constant  DEEMPHASIS_2_0_BIT     : integer := 8;  -- De-emphasis for channel 2(?) BIT 0. Default: 0
   
   constant  CHANNEL_1_MUTE_BIT     : integer := 3;  -- Channel 1 mute (default: 1)
   constant  DEEMPHASIS_1_2_BIT     : integer := 2;  -- De-emphasis for channel 1(?) BIT 2. Default: 0
   constant  DEEMPHASIS_1_1_BIT     : integer := 1;  -- De-emphasis for channel 1(?) BIT 1. Default: 0
   constant  DEEMPHASIS_1_0_BIT     : integer := 0;  -- De-emphasis for channel 1(?) BIT 0. Default: 0
   
   constant  DEEMPHASIS_OFF     : std_logic_vector (2 downto 0) := "000"; 
   constant  DEEMPHASIS_32KHz   : std_logic_vector (2 downto 0) := "001"; 
   constant  DEEMPHASIS_44KHz   : std_logic_vector (2 downto 0) := "010"; 
   constant  DEEMPHASIS_48KHz   : std_logic_vector (2 downto 0) := "011"; 
   constant  DEEMPHASIS_96KHz   : std_logic_vector (2 downto 0) := "100"; 

end uda1380_control_definitions;

 -- package body uda1380_control_definitions is
 -- 	function log2_float(val : positive) return natural is
 -- 	begin
 -- 		return integer(ceil(log2(real(val))));
 -- 	end function;
 -- end uda1380_control_definitions;
