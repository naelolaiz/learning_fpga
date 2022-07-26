library IEEE;
use IEEE.STD_LOGIC_1164.all;
--use ieee.std_logic_arith.all;
use ieee.numeric_std.all;

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
   type EV_MODES_AND_CLOCK_SETTINGS_TYPE is record
      EVALUATION_BITS           : std_logic_vector(15 downto 13); --  := "000"; -- evaluation bits (use default)
      EMPTY_BIT1                : std_logic_vector(12 downto 12); --  := "0";
      EN_ADC_BIT                : std_logic_vector(11 downto 11); --  := "0"; -- ADC clock enable
      EN_DEC_BIT                : std_logic_vector(10 downto 10); --  := "1"; -- decimator clock enable
      EN_DAC_BIT                : std_logic_vector(9  downto 9) ; --  := "0";  -- FSDAC clock enable
      EN_INTERP_BIT             : std_logic_vector(8  downto 8) ; --  := "1";  -- Interpolator clock enable
      EMPTY_BITS2               : std_logic_vector(6 downto 7)  ; --  := "00";
      ADC_CLK_BIT               : std_logic_vector(5  downto 5) ; --  := "0";  -- ADC clock select (0=SYSCLK; 1=WSPLL)
      DAC_CLK_BIT               : std_logic_vector(4  downto 4) ; --  := "0";  -- DAC clock select (0=SYSCLK; 1=WSPLL)
      SYS_DIV_BITS              : std_logic_vector(3  downto 2) ; --  := "00";  -- dividers for system clock input
      WSPLL_BITS                : std_logic_vector(1  downto 0) ; --  := "10";  -- WSPLL setting
   end record  EV_MODES_AND_CLOCK_SETTINGS_TYPE;
   
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
   type I2S_INPUT_AND_OUTPUT_SETTINGS_TYPE is record
      EMPTY_BITS     : std_logic_vector (15 downto 11);  -- := (others => '0');
      SFORI_BITS     : std_logic_vector (10 downto 8) ;  -- := "000"; -- digital data input formats
      EMPTY_BIT2     : std_logic_vector (7 downto 7)  ;  -- := "0";
      SEL_SOURCE_BIT : std_logic_vector (6 downto 6)  ;  -- := "0";  -- digital output interface mode (0: decimator; 1: digital mixer output)
      EMPTY_BIT3     : std_logic_vector (5 downto 5)  ;  -- := "0";
      SIM_BIT        : std_logic_vector (4 downto 4)  ;  -- := "0";  -- digital output interface mode settings (BCK0 PAD. 0: slave; 1: master)
      EMPTY_BIT4     : std_logic_vector (3 downto 3)  ;  -- := "0";
      SFORO_BITS     : std_logic_vector (2 downto 0)  ;  -- := "000";  -- digital data output formats
   end record I2S_INPUT_AND_OUTPUT_SETTINGS_TYPE;
   
   
   constant SFOR_I2S_BUS            : std_logic_vector(2 downto 0) := "000"; -- default
   constant SFOR_LSB_JUST_16_BIT    : std_logic_vector(2 downto 0) := "001";
   constant SFOR_LSB_JUST_18_BIT    : std_logic_vector(2 downto 0) := "010";
   constant SFOR_LSB_JUST_20_BIT    : std_logic_vector(2 downto 0) := "011";
   constant SFOR_MSB_JUST           : std_logic_vector(2 downto 0) := "101";
   
   -- Configuration bits for register address 02H (Power control settings)
   type POWER_CONTROL_SETTINGS_TYPE is record
      PON_PLL  : std_logic_vector (15 downto 15)  ; -- := "0"; -- Power-on WSPLL (0: power-off; 1: power-on)
      EMPTY_BIT : std_logic_vector(14 downto 14)  ; -- := "0";
      PON_HP   : std_logic_vector (13 downto 13)  ; -- := "0"; -- Power-on headphone driver (0: power-off; 1: power-on)
      EMPTY_BITS2 : std_logic_vector(12 downto 11); --   := "0";
      PON_DAC  : std_logic_vector (10 downto 10)  ; -- := "0"; -- Power-on DAC
      EMPTY_BIT3 : std_logic_vector(9 downto 9)   ; -- := "0";
      PON_BIAS : std_logic_vector (8  downto 8)   ; -- := "0";  -- Power-on BIAS 
      EN_AVC   : std_logic_vector (7  downto 7)   ; -- := "0";  -- Enable control AVC
      PON_AVC  : std_logic_vector (6  downto 6)   ; -- := "0";  -- Power-on AVC
      EMPTY_BIT4 : std_logic_vector(5 downto 5)   ; -- := "0";
      PON_LNA  : std_logic_vector (4  downto 4)   ; -- := "0";  -- Power-on LNA
      PON_PGAL : std_logic_vector (3  downto 3)   ; -- := "0";  -- Power-on PGAL
      PON_ADCL : std_logic_vector (2  downto 2)   ; -- := "0";  -- Power-on ADCL
      PON_PGAR : std_logic_vector (1  downto 1)   ; -- := "0";  -- Power-on PGAR
      PON_ADCR : std_logic_vector (0  downto 0)   ; -- := "0";  -- Power-on ADCR
   end record POWER_CONTROL_SETTINGS_TYPE;
  
   -- Configuration bits for register address 03H (Analog mixer settings)
   type ANALOG_MIXER_SETTINGS_TYPE is record
      EMPTY_BITS : std_logic_vector (15 downto 14); -- := "00";
      ANALOG_VOLUME_CONTROL_LEFT_CHANNEL_BITS   : std_logic_vector (13 downto 8); -- := (others => '1'); -- Analog volume control, left channel
      EMPTY_BITS2 : std_logic_vector (7 downto 6); -- := "00";
      ANALOG_VOLUME_CONTROL_RIGHT_CHANNEL_BITS  : std_logic_vector (5 downto 0); --  := (others => '1');  -- Analog volume control, right channel
   end record ANALOG_MIXER_SETTINGS_TYPE;

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
   type MASTER_VOLUME_CONTROL_TYPE is record
      MVC_RIGHT  : std_logic_vector (15 downto 8); --  := (others => '0');
      MVC_LEFT   : std_logic_vector (7 downto 0); --  := (others => '0');
   end record MASTER_VOLUME_CONTROL_TYPE;
   
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
   type MIXER_VOLUME_CONTROL_TYPE is record
      VC2_BITS   : std_logic_vector (15 downto 8); -- := (others => '0'); -- Digital mixer volume control, channel 2
      VC1_BITS   : std_logic_vector (7 downto 0); --  := (others => '0');  -- Digital mixer volume control, channel 1
   end record MIXER_VOLUME_CONTROL_TYPE;
   
   -- Configuration bits for register address 12H (Mode, bass boost and treble)
   type MODE_BASSBOOST_AND_TREBLE_TYPE is record
      M_BITS                : std_logic_vector(15 downto 14) ; -- := "00"; -- Flat/minimum/maximum setting
      TREBLE_LEFT_BITS      : std_logic_vector(13 downto 12) ; -- := "00"; -- Treble setting left
      BASS_BOOST_LEFT_BITS  : std_logic_vector(11 downto 8)  ; -- := "0000" -- Bass boost setting left
      TREBLE_RIGHT_BITS     : std_logic_vector(5 downto 4)   ; -- := "00";    -- Treble setting right
      BASS_BOOST_RIGHT_BITS : std_logic_vector(3 downto 0)   ; -- := "0000"; -- Bass boost setting right
   end record MODE_BASSBOOST_AND_TREBLE_TYPE;
   
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
   type MUTE_AND_DEEMPHASIS_TYPE is record
      EMPTY_BIT              : std_logic_vector (15 downto 15) ; -- := "0";
      MASTER_MUTE_BIT        : std_logic_vector (14 downto 14) ; -- := "1"; -- Master mute
      EMPTY_BITS2            : std_logic_vector (13 downto 12) ; -- := "00";
      CHANNEL_2_MUTE_BIT     : std_logic_vector (11 downto 11) ; -- := "1"; -- Channel 2 mute
      DEEMPHASIS_2_BITS      : std_logic_vector (10 downto 8)  ; -- := (others => '0'); -- De-emphasis for channel 2(?).
      EMPTY_BITS3            : std_logic_vector (7 downto 4)   ; -- := "0000";
     
      CHANNEL_1_MUTE_BIT     : std_logic_vector (3 downto 3) ; --   := "1";   -- Channel 1 mute
      DEEMPHASIS_1_BITS      : std_logic_vector (2 downto 0) ; --   := (others => '0'); -- De-emphasis for channel 1(?).
   end record MUTE_AND_DEEMPHASIS_TYPE;
   
   constant  DEEMPHASIS_OFF     : std_logic_vector (2 downto 0) := "000"; 
   constant  DEEMPHASIS_32KHz   : std_logic_vector (2 downto 0) := "001"; 
   constant  DEEMPHASIS_44KHz   : std_logic_vector (2 downto 0) := "010"; 
   constant  DEEMPHASIS_48KHz   : std_logic_vector (2 downto 0) := "011"; 
   constant  DEEMPHASIS_96KHz   : std_logic_vector (2 downto 0) := "100"; 

  -- Configuration bits for register address 14H (Mixer, silence detector and oversampling settings)
  type MIXER_SILENCEDETECTOR_OVERSAMPLING_TYPE is record
     DA_POL_INV_BIT  : std_logic_vector (15 downto 15) ; -- := "0";
     SEL_NS_BIT      : std_logic_vector (14 downto 14) ; -- := "0";
     MIX_POS_BIT     : std_logic_vector (13 downto 13) ; -- := "0";
     MIX_BIT         : std_logic_vector (12 downto 12) ; -- := "0";
     EMPTY_BITS      : std_logic_vector (11 downto 8)  ; -- := "0000";
     SILENCE_BIT     : std_logic_vector (7 downto 7)   ; -- := "0";
     SDET_ON_BIT     : std_logic_vector (6 downto 6)   ; -- := "0";
     SD_VALUE_BITS    : std_logic_vector (5 downto 4)  ; -- := "00";
     EMPTY_BITS2      : std_logic_vector (3 downto 2)  ; -- := "00";
     OS_BITS          : std_logic_vector (1 downto 0)  ; -- := "00";
  end record MIXER_SILENCEDETECTOR_OVERSAMPLING_TYPE;

  constant SILENCE_DETECTOR_3200_SAMPLES  : std_logic_vector (1 downto 0) := "00";
  constant SILENCE_DETECTOR_4800_SAMPLES  : std_logic_vector (1 downto 0) := "01";
  constant SILENCE_DETECTOR_9600_SAMPLES  : std_logic_vector (1 downto 0) := "10";
  constant SILENCE_DETECTOR_19200_SAMPLES : std_logic_vector (1 downto 0) := "11";

  constant OVERSAMPLING_INPUT_SINGLE_SPEED : std_logic_vector (1 downto 0) := "00";
  constant OVERSAMPLING_INPUT_DOUBLE_SPEED : std_logic_vector (1 downto 0) := "01";
  constant OVERSAMPLING_INPUT_QUAD_SPEED   : std_logic_vector (1 downto 0) := "10";

  -- Configuration bits for register address 22H (ADC settings)
  type ADC_SETTINGS_TYPE is record
     EMPTY_BITS     : std_logic_vector (15 downto 13) ; -- := "000";
     ADCPOL_INV_BIT : std_logic_vector (12 downto 12) ; -- := "0"; -- ADC polarity control. 0: non inverting; 1: inverting.
     VGA_CTRL_BITS  : std_logic_vector (11 downto 8)  ; -- := (others => '0'); -- Microphone input VGA gain settings
     EMPTY_BITS2    : std_logic_vector (7 downto 4)   ; -- := "0000";
     SEL_LNA_BIT    : std_logic_vector (3 downto 3)   ; -- := "0"; -- Line input select. 0: select line input. 1: select LNA for the left channel ADC.
     SEL_MIC_BIT    : std_logic_vector (2 downto 2)   ; -- := "0"; -- Microphone input select. 0: select right channel ADC. Select left channel ADC.
     SKIP_DCFIL_BIT : std_logic_vector (1 downto 1)   ; -- := "1"; -- DC filter bypass. 0: DC filter enabled; 1: DC filter bypassed.
     EN_DCFIL       : std_logic_vector (0 downto 0)   ; -- := "0"; -- DC filter enable. 0: DC filter disabled; 1: DC filter enabled.
  end record ADC_SETTINGS_TYPE;
  -- microphone input VGA gain setting bits
  constant VGA_CONTROL_0dB  : std_logic_vector (3 downto 0)  := "0000"; 
  constant VGA_CONTROL_2dB  : std_logic_vector (3 downto 0)  := "0001"; 
  constant VGA_CONTROL_4dB  : std_logic_vector (3 downto 0)  := "0010"; 
  constant VGA_CONTROL_6dB  : std_logic_vector (3 downto 0)  := "0011"; 
  constant VGA_CONTROL_8dB  : std_logic_vector (3 downto 0)  := "0100"; 
  constant VGA_CONTROL_10dB : std_logic_vector (3 downto 0)  := "0101"; 
  constant VGA_CONTROL_12dB : std_logic_vector (3 downto 0)  := "0110"; 
  constant VGA_CONTROL_14dB : std_logic_vector (3 downto 0)  := "0111"; 
  constant VGA_CONTROL_16dB : std_logic_vector (3 downto 0)  := "1000"; 
  constant VGA_CONTROL_18dB : std_logic_vector (3 downto 0)  := "1001"; 
  constant VGA_CONTROL_20dB : std_logic_vector (3 downto 0)  := "1010"; 
  constant VGA_CONTROL_22dB : std_logic_vector (3 downto 0)  := "1011"; 
  constant VGA_CONTROL_24dB : std_logic_vector (3 downto 0)  := "1100"; 
  constant VGA_CONTROL_26dB : std_logic_vector (3 downto 0)  := "1101"; 
  constant VGA_CONTROL_28dB : std_logic_vector (3 downto 0)  := "1110"; 
  constant VGA_CONTROL_30dB : std_logic_vector (3 downto 0)  := "1111"; 

  -- Configuration bits for register address 23H (AGC settings)
  type AGC_SETTINGS_TYPE is record
     EMPTY_BITS     : std_logic_vector (15 downto 11) ; -- := "00000";
     AGC_TIME_BITS  : std_logic_vector (10 downto 8)  ; -- := "000"; -- AGC time constant settings
     EMPTY_BITS2    : std_logic_vector (7 downto 4)   ; -- := "0000";
     AGC_LEVEL_BITS : std_logic_vector (3 downto 2)   ; -- := "00";  -- AGC target level settings
     EMPTY_BITS3    : std_logic_vector (1 downto 1)   ; -- := "0";
     AGC_ENABLE_BIT : std_logic_vector (0 downto 0)   ; -- := "0";   -- AGC enable control. 0: off; 1: AGC enabled
  end record AGC_SETTINGS_TYPE;

  -- AGC time constant setting bits
  constant AGC_TIME_11_100_ms_at_44100 : std_logic_vector (2 downto 0) := "000"; 
  constant AGC_TIME_16_100_ms_at_44100 : std_logic_vector (2 downto 0) := "001"; 
  constant AGC_TIME_11_200_ms_at_44100 : std_logic_vector (2 downto 0) := "010"; 
  constant AGC_TIME_16_200_ms_at_44100 : std_logic_vector (2 downto 0) := "011"; 
  constant AGC_TIME_21_200_ms_at_44100 : std_logic_vector (2 downto 0) := "100"; 
  constant AGC_TIME_11_400_ms_at_44100 : std_logic_vector (2 downto 0) := "101"; 
  constant AGC_TIME_16_400_ms_at_44100 : std_logic_vector (2 downto 0) := "110"; 
  constant AGC_TIME_21_400_ms_at_44100 : std_logic_vector (2 downto 0) := "111"; 

  -- AGC target level setting bits
  constant AGC_LEVEL_MINUS_5_5dBFS  : std_logic_vector (1 downto 0) := "00";
  constant AGC_LEVEL_MINUS_8dBFS    : std_logic_vector (1 downto 0) := "01";
  constant AGC_LEVEL_MINUS_11_5dBFS : std_logic_vector (1 downto 0) := "10";
  constant AGC_LEVEL_MINUS_14dBFS   : std_logic_vector (1 downto 0) := "11";

  -- Configuration bits for register 18H (Headphone driver and interpolation filter read-out)
  type HEADPHONE_DRIVER_AND_INTEPOLATOR_FILTER_SETTINGS_TYPE is record
     EMPTY_BITS       : std_logic_vector (15 downto 11) ; -- := "00000";
     HP_STCTV_BIT     : std_logic_vector (10 downto 10); -- Headphone driver short-circuit detection
     HP_STCTL_BIT     : std_logic_vector (9  downto 9);  -- Left headphone driver short-circuit detection
     HP_STCTR_BIT     : std_logic_vector (8  downto 8);  -- Right headphone driver short-circuit detection
     EMPTY_BIT2       : std_logic_vector (7  downto 7);  -- Right headphone driver short-circuit detection
     SDETR2_BIT       : std_logic_vector (6  downto 6);  -- Interpolator silence detect channel 2 right
     SDETL2_BIT       : std_logic_vector (5  downto 5);  -- Interpolator silence detect channel 2 left
     SDETR1_BIT       : std_logic_vector (4  downto 4);  -- Interpolator silence detect channel 1 right
     SDETL1_BIT       : std_logic_vector (3  downto 3);  -- Interpolator silence detect channel 1 left
     MUTE_STATE_M_BIT : std_logic_vector (2 downto 2); -- Interpolator muting
     MUTE_STATE_CH2   : std_logic_vector (1 downto 1); -- Interpolator muting channel 2
     MUTE_STATE_CH1   : std_logic_vector (0 downto 0); -- Interpolator muting channel 1
  end record HEADPHONE_DRIVER_AND_INTEPOLATOR_FILTER_SETTINGS_TYPE;

  type I2C_COMMAND_TYPE is record
     reg_address         : std_logic_vector (22 downto 16);
     command_first_byte  : std_logic_vector (15 downto 8);
     command_second_byte : std_logic_vector (7 downto 0);
  end record I2C_COMMAND_TYPE;


-- uint8_t UDA1380InitData[][3] =
-- commands to initialize
constant INIT_RESET_L3_SETTINGS : I2C_COMMAND_TYPE := ( reg_address => UDA1380_REG_L3,
                                                   command_first_byte => x"00",
                                                   command_second_byte => x"00"
                                                   );

constant INIT_ENABLE_ALL_POWER : I2C_COMMAND_TYPE := ( reg_address => UDA1380_REG_PWRCTRL,
                                                   command_first_byte => x"A5",
                                                   command_second_byte => x"DF"
                                                   );

constant INIT_WSPLL_ALL_CLOCKS_ENABLED : I2C_COMMAND_TYPE := ( reg_address => UDA1380_REG_EVALCLK,
                                                   command_first_byte => x"0F",
                                                   command_second_byte => x"39"
                                                   );

constant INIT_I2S_CONFIGURATION_I2S_DIGITALMIXER_BCK0_SLAVE : I2C_COMMAND_TYPE := ( reg_address => UDA1380_REG_I2S,
                                                   command_first_byte => x"00",
                                                   command_second_byte => x"00"
                                                   );

constant INIT_MIXER_INPUT_GAIN_CONFIGURATION : I2C_COMMAND_TYPE := ( reg_address => UDA1380_REG_ANAMIX,
                                                   command_first_byte => x"00",
                                                   command_second_byte => x"00"
                                                   );

constant INIT_ENABLE_HEADPHONE_SHORT_CIRCUIT_PROTECTION : I2C_COMMAND_TYPE := ( reg_address => UDA1380_REG_HEADAMP,
                                                   command_first_byte => x"02",
                                                   command_second_byte => x"02"
                                                   );

constant INIT_FULL_MASTER_VOLUME : I2C_COMMAND_TYPE := ( reg_address => UDA1380_REG_MSTRVOL,
                                                   command_first_byte => x"00",
                                                   command_second_byte => x"00"
                                                   );

constant INIT_FULL_MIXER_VOLUME_BOTH_CHANNELS : I2C_COMMAND_TYPE := ( reg_address => UDA1380_REG_MIXVOL,
                                                   command_first_byte => x"00",
                                                   command_second_byte => x"00"
                                                   );

constant INIT_FLAT_TREBLE_AND_BOOST : I2C_COMMAND_TYPE := ( reg_address => UDA1380_REG_MODEBBT,
                                                   command_first_byte => x"55",
                                                   command_second_byte => x"15"
                                                   );

constant INIT_DISABLE_MUTE_AND_DEEMPHASIS : I2C_COMMAND_TYPE := ( reg_address => UDA1380_REG_MSTRMUTE,
                                                   command_first_byte => x"00",
                                                   command_second_byte => x"00"
                                                   );
constant INIT_MIXER_OFF_OTHER_OFF : I2C_COMMAND_TYPE := ( reg_address => UDA1380_REG_MIXSDO,
                                                   command_first_byte => x"00",
                                                   command_second_byte => x"00"
                                                   );

constant INIT_ADC_DECIMATOR_VOLUME_MAX : I2C_COMMAND_TYPE := ( reg_address => UDA1380_REG_DECVOL,
                                                   command_first_byte => x"00",
                                                   command_second_byte => x"00"
                                                   );

constant INIT_NO_PGA_MUTE_FULL_GAIN : I2C_COMMAND_TYPE := ( reg_address => UDA1380_REG_PGA,
                                                   command_first_byte => x"00",
                                                   command_second_byte => x"00"
                                                   );

constant INIT_SELECT_LINE_IN_AND_MIC_MAX_MIC_GAIN : I2C_COMMAND_TYPE := ( reg_address => UDA1380_REG_ADC,
                                                   command_first_byte => x"0F",
                                                   command_second_byte => x"02"
                                                   );

constant INIT_AGC_SETTINGS : I2C_COMMAND_TYPE := ( reg_address => UDA1380_REG_AGC,
                                                   command_first_byte => x"00",
                                                   command_second_byte => x"00"
                                                   );

constant INIT_DISABLE_ALL_CLOCKS : I2C_COMMAND_TYPE := (reg_address => UDA1380_REG_EVALCLK,
                                                        command_first_byte => x"00",
							command_second_byte => x"32");
constant INIT_DISABLE_POWER_TO_INPUT : I2C_COMMAND_TYPE := (reg_address => UDA1380_REG_PWRCTRL,
                                                        command_first_byte => x"A5",
							command_second_byte => x"C0");
constant INIT_END : I2C_COMMAND_TYPE := (reg_address => (others => '1'),
                                                        command_first_byte => x"FF",
							command_second_byte => x"FF");
end uda1380_control_definitions;

 -- package body uda1380_control_definitions is
 -- 	function log2_float(val : positive) return natural is
 -- 	begin
 -- 		return integer(ceil(log2(real(val))));
 -- 	end function;
 -- end uda1380_control_definitions;
