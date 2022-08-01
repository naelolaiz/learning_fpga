LIBRARY ieee;

USE ieee.std_logic_1164.ALL;
use ieee.numeric_std.ALL;

entity test is
   port (
         clock : in std_logic;
         inputButtons : in std_logic_vector(3 downto 0);
         sevenSegments : out std_logic_vector(6 downto 0);
         cableSelect : out std_logic_vector(3 downto 0);
         leds : out std_logic_vector(3 downto 0));
end test;

architecture behavior of test is
signal counterForCounter: integer range 0 to 3125000 := 0; -- ticks every 3.125E6 / 50E6 = 62.5 ms (0.0625*16 = 1, so the second digit increases every second)
signal counterForMux: integer range 0 to 100000 := 0; -- ticks every 100E3 / 50E6 = 2ms

signal numberToDisplay: std_logic_vector (15 downto 0);
signal enabledDigit: integer range 0 to 3:= 0;
signal currentDigitValue: std_logic_vector (3 downto 0);

  component neoTRNG
    generic (
      NUM_CELLS     : natural; -- total number of ring-oscillator cells
      NUM_INV_START : natural; -- number of inverters in first cell (short path), has to be odd
      NUM_INV_INC   : natural; -- number of additional inverters in next cell (short path), has to be even
      NUM_INV_DELAY : natural; -- additional inverters to form cell's long path, has to be even
      POST_PROC_EN  : boolean; -- implement post-processing for advanced whitening when true
      IS_SIM        : boolean  -- for simulation only!
    );
    port (
      clk_i    : in  std_ulogic; -- global clock line
      enable_i : in  std_ulogic; -- unit enable (high-active), reset unit when low
      data_o   : out std_ulogic_vector(7 downto 0); -- random data byte output
      valid_o  : out std_ulogic  -- data_o is valid when set
    );
  end component;
  signal sEnableRandom : std_logic := '1';
  signal sRndValid : std_logic := '0';
  signal sRndData : std_ulogic_vector (7 downto 0) := (others => '0');
  -- configuration --
  constant num_cells_c     : natural := 3;
  constant num_inv_start_c : natural := 5;
  constant num_inv_inc_c   : natural := 2;
  constant num_inv_delay_c : natural := 2;
  constant post_proc_en_c  : boolean := true;

  ---
  signal sClockForRandomGenerator : std_logic := '0';

begin

  TwoHzCounter : process(clock)
     variable counter : integer := 0;
  begin
     if rising_edge(clock) then
        if counter = 7000000 then
            counter := 0;
        else
           counter := counter + 1;
        end if;
        if counter < 1000 then
          sClockForRandomGenerator <= '1';
        else
          sClockForRandomGenerator <= '0';
        end if;
        -- sClockForRandomGenerator <= '1' when counter < 200 else '0';
     end if;
  end process;

  leds(0) <= sClockForRandomGenerator;

  neoTRNG_inst: neoTRNG
  generic map (
    NUM_CELLS     => num_cells_c,
    NUM_INV_START => num_inv_start_c,
    NUM_INV_INC   => num_inv_inc_c,
    NUM_INV_DELAY => num_inv_delay_c,
    POST_PROC_EN  => post_proc_en_c,
    IS_SIM        => false
  )
  port map (
    clk_i    => clock,
    enable_i => sClockForRandomGenerator,
    data_o   => sRndData,
    valid_o  => sRndValid
  );
  process(sRndData, sRndValid)
  begin
     if rising_edge(sRndValid) then
        numberToDisplay <=  std_logic_vector(sRndData) & numberToDisplay (15 downto 8);
     end if;
  end process;

   counter: process(clock)
   begin
      if clock'event and clock = '1' then

         if counterForMux = counterForMux'HIGH-1 then
            counterForMux <= 0;
				if enabledDigit = enabledDigit'HIGH then
				   enabledDigit <= 0;
				else
				   enabledDigit <= enabledDigit + 1;
				end if;
         else
            counterForMux <= counterForMux + 1;
         end if;
         
         if counterForCounter = counterForCounter'HIGH-1 then
            counterForCounter <= 0;
            --numberToDisplay <= std_logic_vector(unsigned(numberToDisplay) + 1);
         else
            counterForCounter <= counterForCounter + 1;
         end if;
      end if;
   end process;
   
   -- MUX to generate anode activating signals for 4 LEDs 
   process(enabledDigit)
	constant nibbleToShift: std_logic_vector(3 downto 0) := "0001";
   begin
       cableSelect <= not std_logic_vector(unsigned(nibbleToShift) sll enabledDigit);
		 currentDigitValue <= std_logic_vector(unsigned(numberToDisplay) srl (enabledDigit*4)) (3 downto 0);
   end process;

   sevenSegments <= "1000000" when currentDigitValue = "0000" else
        "1111001" when currentDigitValue =  "0001" else
        "0100100" when currentDigitValue =  "0010" else
        "0110000" when currentDigitValue =  "0011" else
        "0011001" when currentDigitValue =  "0100" else
        "0010010" when currentDigitValue =  "0101" else
        "0000010" when currentDigitValue =  "0110" else
        "1111000" when currentDigitValue =  "0111" else
        "0000000" when currentDigitValue =  "1000" else
        "0010000" when currentDigitValue =  "1001" else
        "0001000" when currentDigitValue =  "1010" else
        "0000011" when currentDigitValue =  "1011" else
        "1000110" when currentDigitValue =  "1100" else
        "0100001" when currentDigitValue =  "1101" else
        "0000110" when currentDigitValue =  "1110" else
        "0001110" ;
end behavior;
