-- uda1380_init_fsm.vhd
--
-- Walks a hard-coded boot sequence of UDA1380 register writes through
-- the Digi-Key i2c_master interface (ena / addr / rw / data_wr,
-- busy / ack_error). Each entry in INIT_TABLE is a 3-byte transaction:
--
--   start | DEVICE_ADDR<<1 | reg_address | data_high | data_low | stop
--
-- The FSM watches busy rising edges to step through the three data
-- bytes (the i2c_master latches the next data_wr on every busy^=1
-- while ena stays high), then drops ena and waits for busy to fall
-- before moving to the next table entry.
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
    -- To i2c_master
    i2c_ena     : out std_logic;
    i2c_addr    : out std_logic_vector(6 downto 0);
    i2c_rw      : out std_logic;
    i2c_data_wr : out std_logic_vector(7 downto 0);
    -- From i2c_master
    i2c_busy    : in  std_logic;
    i2c_ack_err : in  std_logic;
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

  type fsm_state_type is (st_power_up_wait, st_send_register, st_done);
  signal state : fsm_state_type := st_power_up_wait;

  -- Index into INIT_TABLE.
  signal table_idx : integer range 0 to INIT_TABLE'length-1 := 0;

  -- Counts the busy rising edges within a single 3-byte transaction.
  -- 0 = waiting to assert first byte, 1 = first latched (drive 2nd
  -- byte), 2 = second latched (drive 3rd byte), 3 = third latched
  -- (deassert ena and wait for busy to fall).
  signal busy_cnt  : integer range 0 to 3 := 0;
  signal busy_prev : std_logic := '0';

  signal delay_counter : integer range 0 to INIT_DELAY_CYCLES-1 := 0;
begin

  process (clk, reset)
  begin
    if reset = '1' then
      state         <= st_power_up_wait;
      table_idx     <= 0;
      busy_cnt      <= 0;
      busy_prev     <= '0';
      delay_counter <= 0;
      i2c_ena       <= '0';
      i2c_addr      <= (others => '0');
      i2c_rw        <= '0';
      i2c_data_wr   <= (others => '0');
      init_done     <= '0';
    elsif rising_edge(clk) then
      busy_prev <= i2c_busy;

      case state is

        when st_power_up_wait =>
          if delay_counter = INIT_DELAY_CYCLES - 1 then
            delay_counter <= 0;
            state         <= st_send_register;
          else
            delay_counter <= delay_counter + 1;
          end if;

        when st_send_register =>
          -- Detect each 0->1 transition on busy.
          if busy_prev = '0' and i2c_busy = '1' then
            busy_cnt <= busy_cnt + 1;
          end if;

          case busy_cnt is
            when 0 =>
              -- First byte: register address (7 bits, padded MSB to 8).
              i2c_ena     <= '1';
              i2c_addr    <= DEVICE_ADDR;
              i2c_rw      <= '0';
              i2c_data_wr <= '0' & INIT_TABLE(table_idx).reg_address;

            when 1 =>
              -- Second byte: high data byte.
              i2c_data_wr <= INIT_TABLE(table_idx).command_first_byte;

            when 2 =>
              -- Third byte: low data byte.
              i2c_data_wr <= INIT_TABLE(table_idx).command_second_byte;

            when 3 =>
              -- Drop ena and wait for the master to finish (busy=0).
              i2c_ena <= '0';
              if i2c_busy = '0' then
                busy_cnt <= 0;
                if table_idx = INIT_TABLE'length - 1 then
                  state <= st_done;
                else
                  table_idx <= table_idx + 1;
                end if;
              end if;
          end case;

        when st_done =>
          i2c_ena   <= '0';
          init_done <= '1';
      end case;
    end if;
  end process;

end architecture rtl;
