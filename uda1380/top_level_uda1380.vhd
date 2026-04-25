library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.uda1380_control_definitions.all;

entity top_level_uda1380 is
  generic(
    sys_clk_freq     : integer := 50_000_000;                      --input clock speed from user logic in Hz
    temp_sensor_addr : std_logic_vector(6 downto 0) := "1001011"); --I2C address of the temp sensor pmod
  port(
    iClk               : in    std_logic;                           --system clock
    iNoReset           : in    std_logic;                           --asynchronous active-low reset
    i2cIOScl           : inout std_logic;                           --I2C serial clock
    i2cIOSda           : inout std_logic;                           --I2C serial data
    oTxMasterClock     : out std_logic;                             -- tx master clock
    oTxWordSelectClock : out std_logic;                             -- tx word (left/right) select
    oTxBitClock        : out std_logic;                             -- tx serial bit clock
    oTxSerialData      : out std_logic;                             -- tx serial data output
    oRxMasterClock     : out std_logic;                             -- rx master clock
    oRxWordSelectClock : out std_logic;                             -- rx word (left/right) select
    oRxBitClock        : out std_logic;                             -- rx serial bit clock
    oRxSerialData      : out std_logic);                            -- rx serial data output
end top_level_uda1380;

architecture behavior OF top_level_uda1380 is
begin
end behavior;

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity uda1380_i2c_driver is
  generic(
    sys_clk_freq     : integer := 50_000_000;                      --input clock speed from user logic in Hz
    temp_sensor_addr : std_logic_vector(6 downto 0) := "1001011"); --I2C address of the temp sensor pmod
  port(
    clk         : in    std_logic;                                 --system clock
    reset_n     : in    std_logic;                                 --asynchronous active-low reset
    scl         : inout std_logic;                                 --I2C serial clock
    sda         : inout std_logic;                                 --I2C serial data
    i2c_ack_err : out   std_logic;                                 --I2C slave acknowledge error flag
    temperature : out   std_logic_vector(15 downto 0));            --temperature value obtained
end uda1380_i2c_driver ;

architecture behavior OF uda1380_i2c_driver is
  type machine is(start, set_resolution, pause, read_data, output_result); --needed states

  signal state       : machine;                       --state machine
  signal i2c_ena     : std_logic;                     --i2c enable signal
  signal i2c_addr    : std_logic_vector(6 downto 0);  --i2c address signal
  signal i2c_rw      : std_logic;                     --i2c read/write command signal
  signal i2c_data_wr : std_logic_vector(7 downto 0);  --i2c write data
  signal i2c_data_rd : std_logic_vector(7 downto 0);  --i2c read data
  signal i2c_busy    : std_logic;                     --i2c busy signal
  signal busy_prev   : std_logic;                     --previous value of i2c busy signal
  signal temp_data   : std_logic_vector(15 downto 0); --temperature data buffer

  component i2c_master is
    generic(
     input_clk : integer;  --input clock speed from user logic in Hz
     bus_clk   : integer); --speed the i2c bus (scl) will run at in Hz
    port(
     clk       : in     std_logic;                    --system clock
     reset_n   : in     std_logic;                    --active low reset
     ena       : in     std_logic;                    --latch in command
     addr      : in     std_logic_vector(6 downto 0); --address of target slave
     rw        : in     std_logic;                    --'0' is write, '1' is read
     data_wr   : in     std_logic_vector(7 downto 0); --data to write to slave
     busy      : out    std_logic;                    --indicates transaction in progress
     data_rd   : out    std_logic_vector(7 downto 0); --data read from slave
     ack_error : buffer std_logic;                    --flag if improper acknowledge from slave
     sda       : inout  std_logic;                    --serial data output of i2c bus
     scl       : inout  std_logic);                   --serial clock output of i2c bus
  end component;

begin

  --instantiate the i2c master
  i2c_master_0:  i2c_master
    generic map(input_clk => sys_clk_freq, bus_clk => 400_000)
    port map(clk => clk, reset_n => reset_n, ena => i2c_ena, addr => i2c_addr,
             rw => i2c_rw, data_wr => i2c_data_wr, busy => i2c_busy,
             data_rd => i2c_data_rd, ack_error => i2c_ack_err, sda => sda,
             scl => scl);

  process(clk, reset_n)
    variable busy_cnt : integer range 0 to 3 := 0;               --counts the busy signal transistions during one transaction
    variable counter  : integer range 0 to sys_clk_freq/10 := 0; --counts 100ms to wait before communicating
  begin
    if(reset_n = '0') then               --reset activated
      counter := 0;                        --clear wait counter
      i2c_ena <= '0';                      --clear i2c enable
      busy_cnt := 0;                       --clear busy counter
      temperature <= (others => '0');      --clear temperature result output
      state <= start;                      --return to start state
    ELSif(clk'event and clk = '1') then  --rising edge of system clock
      case state is                        --state machine
      
        --give temp sensor 100ms to power up before communicating
        when start =>
          if(counter < sys_clk_freq/10) then   --100ms not yet reached
            counter := counter + 1;              --increment counter
          ELSE                                 --100ms reached
            counter := 0;                        --clear counter
            state <= set_resolution;             --advance to setting the resolution
          end if;
      
        --set the resolution of the temperature data to 16 bits
        when set_resolution =>            
          busy_prev <= i2c_busy;                       --capture the value of the previous i2c busy signal
          if(busy_prev = '0' and i2c_busy = '1') then  --i2c busy just went high
            busy_cnt := busy_cnt + 1;                    --counts the times busy has gone from low to high during transaction
          end if;
          case busy_cnt is                             --busy_cnt keeps track of which command we are on
            when 0 =>                                    --no command latched in yet
              i2c_ena <= '1';                              --initiate the transaction
              i2c_addr <= temp_sensor_addr;                --set the address of the temp sensor
              i2c_rw <= '0';                               --command 1 is a write
              i2c_data_wr <= "00000011";                   --send the address (x03) of the Configuration Register
            when 1 =>                                    --1st busy high: command 1 latched, okay to issue command 2
              i2c_data_wr <= "10000000";                   --write the new configuration value to the Configuration Register
            when 2 =>                                    --2nd busy high: command 2 latched
              i2c_ena <= '0';                              --deassert enable to stop transaction after command 2
              if(i2c_busy = '0') then                      --transaction complete
                busy_cnt := 0;                               --reset busy_cnt for next transaction
                state <= pause;                              --advance to setting the Register Pointer for data reads
              end if;
            when others => null;
          end case;
          
        --pause 1.3us between transactions
        when pause =>
          if(counter < sys_clk_freq/769_000) then  --1.3us not yet reached
            counter := counter + 1;                  --increment counter
          ELSE                                     --1.3us reached
            counter := 0;                            --clear counter
            state <= read_data;                      --reading temperature data
          end if;
          
        --read ambient temperature data
        when read_data =>
          busy_prev <= i2c_busy;                       --capture the value of the previous i2c busy signal
          if(busy_prev = '0' and i2c_busy = '1') then  --i2c busy just went high
            busy_cnt := busy_cnt + 1;                    --counts the times busy has gone from low to high during transaction
          end if;
          case busy_cnt is                             --busy_cnt keeps track of which command we are on
            when 0 =>                                    --no command latched in yet
              i2c_ena <= '1';                              --initiate the transaction
              i2c_addr <= temp_sensor_addr;                --set the address of the temp sensor
              i2c_rw <= '0';                               --command 1 is a write
              i2c_data_wr <= "00000000";                   --send the address (x00) of the Temperature Value MSB Register
            when 1 =>                                    --1st busy high: command 1 latched, okay to issue command 2
              i2c_rw <= '1';                               --command 2 is a read
            when 2 =>                                    --2nd busy high: command 2 latched, okay to issue command 3
              if(i2c_busy = '0') then                      --indicates data read in command 2 is ready
                temp_data(15 downto 8) <= i2c_data_rd;       --retrieve MSB data from command 2
              end if;
            when 3 =>                                    --3rd busy high: command 3 latched
              i2c_ena <= '0';                              --deassert enable to stop transaction after command 3
              if(i2c_busy = '0') then                      --indicates data read in command 3 is ready
                temp_data(7 downto 0) <= i2c_data_rd;        --retrieve LSB data from command 3
                busy_cnt := 0;                               --reset busy_cnt for next transaction
                state <= output_result;                      --advance to output the result
              end if;
            when others => null;
          end case;

        --output the temperature data
        when output_result =>
          temperature <= temp_data(15 downto 0);       --write temperature data to output
          state <= pause;                              --pause 1.3us before next transaction

        --default to start state
        when others =>
          state <= start;

      end case;
    end if;
  end process;   
end behavior;
