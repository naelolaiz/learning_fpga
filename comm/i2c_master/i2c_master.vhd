-- i2c_master.vhd
--
-- Single-master I2C byte engine. Each accepted command puts one byte
-- slot on the bus: eight data bits MSB first, then the acknowledge
-- bit. Two flags frame the slot: `cmd_start` sends a START (or a
-- repeated START) before it and `cmd_stop` sends a STOP after it. The
-- address is not special — it is simply the first byte written after
-- a START, as `address & R/W`.
--
-- A three-byte register write is therefore four commands:
--
--   cmd_start=1  cmd_wdata = address & '0'
--                cmd_wdata = register
--                cmd_wdata = data high
--   cmd_stop=1   cmd_wdata = data low
--
-- The pins are open-drain and split: `*_oe = '1'` pulls the line low,
-- `*_oe = '0'` lets the pull-up raise it, and `*_i` reads the line
-- back. The board top turns each pair into one `inout` pin; keeping
-- them split here lets the same block be simulated with plain '0' /
-- '1' levels and rendered by netlistsvg.
--
-- Timing comes from CLKS_PER_QUARTER, the number of `clk` cycles in a
-- quarter of an SCL period: 50 MHz / (4 * 100 kHz) = 125. Within a bit
-- the four quarters are
--
--   0  SCL low,  SDA still holds the previous bit (hold time)
--   1  SCL low,  SDA carries this bit              (setup time)
--   2  SCL high, sampled at the end of the quarter (middle of high)
--   3  SCL high
--
-- so SDA only ever changes while SCL is low, except for the START and
-- STOP conditions, which are exactly an SDA edge while SCL is high.
--
-- Whenever this master has released SCL but the line still reads low,
-- the quarter timer waits. That is how a slave stretches the clock,
-- and it is also why SCL is read back through a synchroniser instead
-- of being assumed: the two flip-flops add two clocks to every SCL
-- high time, so the bus runs slightly slower than nominal, never
-- faster.

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity i2c_master is
  generic (
    CLKS_PER_QUARTER : integer := 125
  );
  port (
    clk       : in  std_logic;
    rst       : in  std_logic;                     -- synchronous, active high
    -- Command: accepted on a rising edge with cmd_valid = cmd_ready = '1'.
    cmd_valid : in  std_logic;
    cmd_start : in  std_logic;                     -- (repeated) START before the byte
    cmd_stop  : in  std_logic;                     -- STOP after the acknowledge bit
    cmd_read  : in  std_logic;                     -- '0' write cmd_wdata, '1' read a byte
    cmd_nack  : in  std_logic;                     -- read only: answer NACK (last byte)
    cmd_wdata : in  std_logic_vector(7 downto 0);
    cmd_ready : out std_logic;
    -- Response: one-clock pulse when the byte slot has finished.
    rsp_valid : out std_logic;
    rsp_rdata : out std_logic_vector(7 downto 0);  -- the eight bits as seen on SDA
    rsp_nack  : out std_logic;                     -- acknowledge bit: '1' = not acknowledged
    busy      : out std_logic;                     -- high from START until the STOP completes
    -- Open-drain bus, split into drive-low enables and read-backs.
    scl_oe    : out std_logic;
    scl_i     : in  std_logic;
    sda_oe    : out std_logic;
    sda_i     : in  std_logic
  );
end entity i2c_master;

architecture rtl of i2c_master is
  -- Encoded state vector (same idiom as uart_tx) so GHDL and the
  -- Verilog twin produce the same waveform signal set.
  constant S_IDLE     : std_logic_vector(3 downto 0) := "0000";  -- bus free
  constant S_START    : std_logic_vector(3 downto 0) := "0001";  -- SDA low, SCL high
  constant S_BIT      : std_logic_vector(3 downto 0) := "0010";  -- nine bits, four quarters each
  constant S_HOLD     : std_logic_vector(3 downto 0) := "0011";  -- between bytes, SCL held low
  constant S_RSTART_A : std_logic_vector(3 downto 0) := "0100";  -- SCL low,  SDA released
  constant S_RSTART_B : std_logic_vector(3 downto 0) := "0101";  -- SCL high, SDA high
  constant S_STOP_A   : std_logic_vector(3 downto 0) := "0110";  -- SCL low,  SDA unchanged
  constant S_STOP_B   : std_logic_vector(3 downto 0) := "0111";  -- SCL low,  SDA low
  constant S_STOP_C   : std_logic_vector(3 downto 0) := "1000";  -- SCL high, SDA low
  constant S_STOP_D   : std_logic_vector(3 downto 0) := "1001";  -- SDA high: bus free time

  signal state    : std_logic_vector(3 downto 0) := S_IDLE;
  signal tick_cnt : integer range 0 to CLKS_PER_QUARTER-1 := 0;
  signal phase    : integer range 0 to 3 := 0;   -- quarter index inside the state
  signal bit_cnt  : integer range 0 to 8 := 0;   -- 0..7 data bits, 8 acknowledge bit
  signal shreg    : std_logic_vector(7 downto 0) := (others => '0');
  signal ack_bit  : std_logic := '0';

  -- Flags of the command being executed.
  signal c_read   : std_logic := '0';
  signal c_stop   : std_logic := '0';
  signal c_nack   : std_logic := '0';

  signal scl_oe_r : std_logic := '0';
  signal sda_oe_r : std_logic := '0';

  -- Two-stage synchronisers, initialised to the idle (high) level.
  signal scl_s1, scl_s2 : std_logic := '1';
  signal sda_s1, sda_s2 : std_logic := '1';

  signal rsp_valid_r : std_logic := '0';
  signal rsp_rdata_r : std_logic_vector(7 downto 0) := (others => '0');
  signal rsp_nack_r  : std_logic := '0';

  signal stretching   : std_logic;
  signal quarter_done : std_logic;
  signal ready_i      : std_logic;
begin

  -- SCL released by us but still low: somebody else is holding it.
  stretching   <= '1' when scl_oe_r = '0' and scl_s2 = '0' else '0';
  quarter_done <= '1' when tick_cnt = CLKS_PER_QUARTER-1 and stretching = '0' else '0';
  ready_i      <= '1' when state = S_IDLE or state = S_HOLD else '0';

  process (clk)
  begin
    if rising_edge(clk) then
      scl_s1 <= scl_i;
      scl_s2 <= scl_s1;
      sda_s1 <= sda_i;
      sda_s2 <= sda_s1;

      -- rsp_valid is a one-clock pulse.
      rsp_valid_r <= '0';

      -- Quarter timer. It rests in the two states that wait for a
      -- command and pauses while the clock is being stretched.
      if ready_i = '1' or stretching = '1' or tick_cnt = CLKS_PER_QUARTER-1 then
        tick_cnt <= 0;
      else
        tick_cnt <= tick_cnt + 1;
      end if;

      if rst = '1' then
        state    <= S_IDLE;
        scl_oe_r <= '0';
        sda_oe_r <= '0';
        phase    <= 0;
        bit_cnt  <= 0;
      else
        case state is

          when S_IDLE =>
            scl_oe_r <= '0';
            sda_oe_r <= '0';
            if cmd_valid = '1' then
              shreg    <= cmd_wdata;
              c_read   <= cmd_read;
              c_stop   <= cmd_stop;
              c_nack   <= cmd_nack;
              -- From a free bus every transfer begins with a START:
              -- pull SDA low while SCL is still high.
              sda_oe_r <= '1';
              phase    <= 0;
              state    <= S_START;
            end if;

          when S_HOLD =>
            if cmd_valid = '1' then
              shreg  <= cmd_wdata;
              c_read <= cmd_read;
              c_stop <= cmd_stop;
              c_nack <= cmd_nack;
              phase  <= 0;
              if cmd_start = '1' then
                sda_oe_r <= '0';            -- let SDA rise while SCL is low
                state    <= S_RSTART_A;
              else
                bit_cnt <= 0;
                state   <= S_BIT;
              end if;
            end if;

          -- Repeated START, first half: SCL low with SDA released.
          when S_RSTART_A =>
            if quarter_done = '1' then
              if phase = 1 then
                scl_oe_r <= '0';
                phase    <= 0;
                state    <= S_RSTART_B;
              else
                phase <= phase + 1;
              end if;
            end if;

          -- Repeated START, second half: both lines high.
          when S_RSTART_B =>
            if quarter_done = '1' then
              if phase = 1 then
                sda_oe_r <= '1';            -- the START edge
                phase    <= 0;
                state    <= S_START;
              else
                phase <= phase + 1;
              end if;
            end if;

          -- START hold: SDA low, SCL high for half a period.
          when S_START =>
            if quarter_done = '1' then
              if phase = 1 then
                scl_oe_r <= '1';
                phase    <= 0;
                bit_cnt  <= 0;
                state    <= S_BIT;
              else
                phase <= phase + 1;
              end if;
            end if;

          when S_BIT =>
            if quarter_done = '1' then
              case phase is
                when 0 =>
                  -- Hold quarter over: put this bit on SDA.
                  if bit_cnt = 8 then
                    -- Acknowledge slot. Writing: release SDA and let
                    -- the slave answer. Reading: we answer.
                    sda_oe_r <= c_read and not c_nack;
                  else
                    -- Data bit. Open drain: pull low for a '0',
                    -- release for a '1' and whenever we are reading.
                    sda_oe_r <= not c_read and not shreg(7);
                  end if;
                  phase <= 1;
                when 1 =>
                  scl_oe_r <= '0';          -- SCL rises
                  phase    <= 2;
                when 2 =>
                  -- Middle of SCL high: sample. Shifting the sampled
                  -- bit in serves both directions — a write consumes
                  -- shreg from the top, a read fills it from the
                  -- bottom.
                  if bit_cnt = 8 then
                    ack_bit <= sda_s2;
                  else
                    shreg <= shreg(6 downto 0) & sda_s2;
                  end if;
                  phase <= 3;
                when others =>
                  scl_oe_r <= '1';          -- SCL falls
                  phase    <= 0;
                  if bit_cnt = 8 then
                    rsp_valid_r <= '1';
                    rsp_rdata_r <= shreg;
                    rsp_nack_r  <= ack_bit;
                    if c_stop = '1' then
                      state <= S_STOP_A;
                    else
                      state <= S_HOLD;
                    end if;
                  else
                    bit_cnt <= bit_cnt + 1;
                  end if;
              end case;
            end if;

          -- STOP. SDA must be low before SCL rises, and it may only
          -- move while SCL is low, so: wait a quarter, pull SDA low,
          -- release SCL, then release SDA — the STOP edge.
          when S_STOP_A =>
            if quarter_done = '1' then
              sda_oe_r <= '1';
              state    <= S_STOP_B;
            end if;

          when S_STOP_B =>
            if quarter_done = '1' then
              scl_oe_r <= '0';
              phase    <= 0;
              state    <= S_STOP_C;
            end if;

          when S_STOP_C =>
            if quarter_done = '1' then
              if phase = 1 then
                sda_oe_r <= '0';            -- the STOP edge
                phase    <= 0;
                state    <= S_STOP_D;
              else
                phase <= phase + 1;
              end if;
            end if;

          -- Bus free time before the next START may follow.
          when S_STOP_D =>
            if quarter_done = '1' then
              if phase = 1 then
                phase <= 0;
                state <= S_IDLE;
              else
                phase <= phase + 1;
              end if;
            end if;

          when others =>
            state <= S_IDLE;
        end case;
      end if;
    end if;
  end process;

  cmd_ready <= ready_i;
  rsp_valid <= rsp_valid_r;
  rsp_rdata <= rsp_rdata_r;
  rsp_nack  <= rsp_nack_r;
  busy      <= '0' when state = S_IDLE else '1';
  scl_oe    <= scl_oe_r;
  sda_oe    <= sda_oe_r;

end architecture rtl;
