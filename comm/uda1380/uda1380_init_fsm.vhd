-- uda1380_init_fsm.vhd
--
-- Walks a hard-coded boot sequence of UDA1380 register writes through
-- the command interface of comm/i2c_master. Each entry in INIT_TABLE
-- becomes one transaction of four bytes on the bus:
--
--   START | DEVICE_ADDR & '0' | reg_address | data_high | data_low | STOP
--
-- The master takes one command per byte, so the FSM is a small
-- valid/ready source: it offers the current byte (with cmd_start on
-- the first and cmd_stop on the last) and steps to the next one on
-- every clock where the master is ready to accept it.
--
-- INIT_DELAY_CYCLES gates the first register write behind a power-up
-- delay so the codec has time to come out of reset. It is a generic
-- so the testbench can collapse it to a few cycles.

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.uda1380_control_definitions.all;

entity uda1380_init_fsm is
  generic (
    -- 100 ms at 50 MHz; override in sim.
    INIT_DELAY_CYCLES : integer := 5_000_000
  );
  port (
    clk         : in  std_logic;
    reset       : in  std_logic;                          -- active-high
    -- To i2c_master (write-only, so cmd_read / cmd_nack stay '0').
    cmd_valid   : out std_logic;
    cmd_start   : out std_logic;
    cmd_stop    : out std_logic;
    cmd_wdata   : out std_logic_vector(7 downto 0);
    -- From i2c_master
    cmd_ready   : in  std_logic;
    i2c_busy    : in  std_logic;
    -- Status
    init_done   : out std_logic
  );
end entity uda1380_init_fsm;

architecture rtl of uda1380_init_fsm is

  type init_table_type is array (natural range <>) of I2C_COMMAND_TYPE;
  -- The boot sequence — order matters. Power on first, set clocks,
  -- configure I2S, then volumes / mutes / mixer / mic-AGC paths.
  -- Constants come from work.uda1380_control_definitions.
  constant INIT_TABLE : init_table_type := (
    INIT_RESET_L3_SETTINGS,
    INIT_ENABLE_ALL_POWER,
    INIT_WSPLL_ALL_CLOCKS_ENABLED,
    INIT_I2S_CONFIGURATION_I2S_DIGITALMIXER_BCK0_SLAVE,
    INIT_MIXER_INPUT_GAIN_CONFIGURATION,
    INIT_ENABLE_HEADPHONE_SHORT_CIRCUIT_PROTECTION,
    INIT_FULL_MASTER_VOLUME,
    INIT_FULL_MIXER_VOLUME_BOTH_CHANNELS,
    INIT_FLAT_TREBLE_AND_BOOST,
    INIT_DISABLE_MUTE_AND_DEEMPHASIS,
    INIT_MIXER_OFF_OTHER_OFF,
    INIT_ADC_DECIMATOR_VOLUME_MAX,
    INIT_NO_PGA_MUTE_FULL_GAIN,
    INIT_SELECT_LINE_IN_AND_MIC_MAX_MIC_GAIN,
    INIT_AGC_SETTINGS
  );

  type fsm_state_type is (st_power_up_wait, st_send_register,
                          st_wait_bus_free, st_done);
  signal state : fsm_state_type := st_power_up_wait;

  -- Index into INIT_TABLE.
  signal table_idx : integer range 0 to INIT_TABLE'length-1 := 0;

  -- Which byte of the current transaction is on offer:
  -- 0 = device address, 1 = register, 2 = data high, 3 = data low.
  signal byte_idx  : integer range 0 to 3 := 0;

  signal delay_counter : integer range 0 to INIT_DELAY_CYCLES-1 := 0;
begin

  -- The command is a pure function of where we are in the table, so
  -- the byte on offer always matches the index that advances when it
  -- is accepted.
  cmd_valid <= '1' when state = st_send_register else '0';
  cmd_start <= '1' when byte_idx = 0 else '0';
  cmd_stop  <= '1' when byte_idx = 3 else '0';

  with byte_idx select cmd_wdata <=
    DEVICE_ADDR & '0'                          when 0,   -- address, write
    '0' & INIT_TABLE(table_idx).reg_address    when 1,   -- 7 bits, padded to 8
    INIT_TABLE(table_idx).command_first_byte   when 2,
    INIT_TABLE(table_idx).command_second_byte  when others;

  process (clk, reset)
  begin
    if reset = '1' then
      state         <= st_power_up_wait;
      table_idx     <= 0;
      byte_idx      <= 0;
      delay_counter <= 0;
      init_done     <= '0';
    elsif rising_edge(clk) then
      case state is

        when st_power_up_wait =>
          if delay_counter = INIT_DELAY_CYCLES - 1 then
            delay_counter <= 0;
            state         <= st_send_register;
          else
            delay_counter <= delay_counter + 1;
          end if;

        when st_send_register =>
          -- cmd_valid is high throughout this state, so a ready
          -- master means the byte on offer was accepted on this edge.
          if cmd_ready = '1' then
            if byte_idx = 3 then
              byte_idx <= 0;
              if table_idx = INIT_TABLE'length - 1 then
                state <= st_wait_bus_free;
              else
                table_idx <= table_idx + 1;
              end if;
            else
              byte_idx <= byte_idx + 1;
            end if;
          end if;

        when st_wait_bus_free =>
          -- The last byte and its STOP are still on the wire.
          if i2c_busy = '0' then
            state <= st_done;
          end if;

        when st_done =>
          init_done <= '1';
      end case;
    end if;
  end process;

end architecture rtl;
