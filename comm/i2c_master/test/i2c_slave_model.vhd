-- i2c_slave_model.vhd
--
-- Behavioural I2C slave for testbenches (not synthesisable). It has no
-- clock of its own: like a real slave it reacts to the bus wires.
--
--   SDA edge while SCL is high   START (falling) or STOP (rising)
--   SCL rising edge              sample SDA
--   SCL falling edge             change what it drives on SDA
--
-- Behaviour, modelled on a small serial memory:
--
--   * Answers only to ADDR. Any other address is left unacknowledged
--     and the rest of that transfer is ignored.
--   * Write: the first data byte sets a pointer, each further byte is
--     stored at the pointer, which then advances. Every byte is
--     acknowledged.
--   * Read: returns the byte at the pointer and advances it for as
--     long as the master acknowledges; a NACK ends the read.
--   * With `stretch` high it holds SCL low for STRETCH_TIME before
--     every acknowledge bit, the way a slow slave buys time.
--
-- `starts`, `stops`, `rx_count` and `rx_data` are taps for the
-- testbench: they count the conditions seen on the bus and expose
-- each data byte received (pointer byte included).

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity i2c_slave_model is
  generic (
    ADDR         : std_logic_vector(6 downto 0) := "1010000";
    STRETCH_TIME : time := 0 ns
  );
  port (
    scl      : in  std_logic;            -- bus level, after the wired-AND
    sda      : in  std_logic;
    stretch  : in  std_logic;
    scl_oe   : out std_logic := '0';     -- '1' pulls SCL low
    sda_oe   : out std_logic := '0';     -- '1' pulls SDA low
    starts   : out integer := 0;         -- START conditions, repeated ones included
    stops    : out integer := 0;         -- STOP conditions that ended a transfer
    rx_count : out integer := 0;         -- data bytes received
    rx_data  : out std_logic_vector(7 downto 0) := (others => '0')
  );
end entity i2c_slave_model;

architecture behaviour of i2c_slave_model is
  type mem_type is array (0 to 255) of std_logic_vector(7 downto 0);
begin

  bus_watch : process (scl, sda)
    variable mem        : mem_type := (others => (others => '0'));
    variable ptr        : integer range 0 to 255 := 0;
    variable active     : boolean := false;   -- between START and STOP
    variable got_addr   : boolean := false;   -- address byte already seen
    variable addressed  : boolean := false;   -- ...and it was ours
    variable reading    : boolean := false;   -- master reads, we transmit
    variable first_data : boolean := false;   -- next written byte is the pointer
    variable send_next  : boolean := false;   -- master acknowledged: send another byte
    variable bitn       : integer range 0 to 9 := 0;  -- SCL rising edges in this byte
    variable sh         : std_logic_vector(7 downto 0) := (others => '0');
    variable txb        : std_logic_vector(7 downto 0) := (others => '0');
    variable starts_v   : integer := 0;
    variable stops_v    : integer := 0;
    variable rx_count_v : integer := 0;
  begin
    if sda'event and not scl'event and scl = '1' then
      -- SDA moved while SCL stayed high: a START or a STOP.
      if sda = '0' then
        starts_v   := starts_v + 1;
        active     := true;
        got_addr   := false;
        addressed  := false;
        reading    := false;
        bitn       := 0;
        sda_oe     <= '0';
      elsif active then
        stops_v    := stops_v + 1;
        active     := false;
        addressed  := false;
        reading    := false;
        sda_oe     <= '0';
      end if;

    elsif scl'event and scl = '1' then
      if active then
        if bitn < 8 then
          sh   := sh(6 downto 0) & sda;
          bitn := bitn + 1;
        else
          -- Acknowledge bit. While we transmit it is the master's
          -- answer; after the address byte it is our own ACK, which
          -- reads low and so starts the first byte.
          send_next := (sda = '0');
          bitn      := 9;
        end if;
      end if;

    elsif scl'event and scl = '0' then
      if active then
        if bitn = 8 then
          -- Eight bits in: the acknowledge slot begins.
          if not got_addr then
            got_addr   := true;
            addressed  := (sh(7 downto 1) = ADDR);
            reading    := addressed and sh(0) = '1';
            first_data := true;
            if addressed then
              sda_oe <= '1';
            else
              sda_oe <= '0';
            end if;
          elsif addressed and not reading then
            rx_count_v := rx_count_v + 1;
            rx_data    <= sh;
            if first_data then
              ptr        := to_integer(unsigned(sh));
              first_data := false;
            else
              mem(ptr) := sh;
              ptr      := (ptr + 1) mod 256;
            end if;
            sda_oe <= '1';
          else
            sda_oe <= '0';               -- the master answers, or not ours
          end if;
          if addressed and stretch = '1' then
            scl_oe <= '1', '0' after STRETCH_TIME;
          end if;

        elsif bitn = 9 then
          -- Acknowledge slot over: next byte.
          bitn := 0;
          if addressed and reading and send_next then
            txb    := mem(ptr);
            ptr    := (ptr + 1) mod 256;
            sda_oe <= not txb(7);
          else
            reading := false;
            sda_oe  <= '0';
          end if;

        elsif addressed and reading then
          sda_oe <= not txb(7 - bitn);   -- next bit, MSB first

        else
          sda_oe <= '0';
        end if;
      end if;
    end if;

    starts   <= starts_v;
    stops    <= stops_v;
    rx_count <= rx_count_v;
  end process;

end architecture behaviour;
