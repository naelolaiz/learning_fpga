-- fifo_sync.vhd
--
-- Single-clock (synchronous) FIFO with separate read/write enables and
-- empty/full status flags. Stored entries live in a small block of
-- registers indexed by binary read/write pointers; the comparison
-- between them produces the empty/full flags.
--
-- Generic over data width and depth; depth must be a power of two so
-- the wrap-around on the pointers is free.

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity fifo_sync is
  generic (
    DATA_WIDTH : integer := 8;
    DEPTH      : integer := 16    -- must be a power of two
  );
  port (
    clk   : in  std_logic;
    rst   : in  std_logic;        -- synchronous, active high
    wr_en : in  std_logic;
    wr_data : in  std_logic_vector(DATA_WIDTH-1 downto 0);
    rd_en : in  std_logic;
    rd_data : out std_logic_vector(DATA_WIDTH-1 downto 0);
    empty : out std_logic;
    full  : out std_logic
  );
end entity fifo_sync;

architecture rtl of fifo_sync is
  -- One extra MSB on each pointer so wrap+occupancy comparisons are
  -- unambiguous (classic Cummings pattern).
  function clog2(n : integer) return integer is
    variable v : integer := n - 1;
    variable r : integer := 0;
  begin
    while v > 0 loop
      r := r + 1;
      v := v / 2;
    end loop;
    return r;
  end function;

  constant ADDR_W : integer := clog2(DEPTH);

  type ram_t is array (0 to DEPTH-1) of std_logic_vector(DATA_WIDTH-1 downto 0);
  signal ram : ram_t := (others => (others => '0'));

  signal wr_ptr : unsigned(ADDR_W downto 0) := (others => '0');
  signal rd_ptr : unsigned(ADDR_W downto 0) := (others => '0');
  signal rd_reg : std_logic_vector(DATA_WIDTH-1 downto 0) := (others => '0');

  signal s_empty : std_logic;
  signal s_full  : std_logic;
begin

  s_empty <= '1' when wr_ptr = rd_ptr else '0';
  s_full  <= '1' when (wr_ptr(ADDR_W) /= rd_ptr(ADDR_W))
                  and (wr_ptr(ADDR_W-1 downto 0) = rd_ptr(ADDR_W-1 downto 0))
              else '0';

  process (clk)
  begin
    if rising_edge(clk) then
      if rst = '1' then
        wr_ptr <= (others => '0');
        rd_ptr <= (others => '0');
      else
        if wr_en = '1' and s_full = '0' then
          ram(to_integer(wr_ptr(ADDR_W-1 downto 0))) <= wr_data;
          wr_ptr <= wr_ptr + 1;
        end if;
        if rd_en = '1' and s_empty = '0' then
          rd_reg <= ram(to_integer(rd_ptr(ADDR_W-1 downto 0)));
          rd_ptr <= rd_ptr + 1;
        end if;
      end if;
    end if;
  end process;

  rd_data <= rd_reg;
  empty   <= s_empty;
  full    <= s_full;

end architecture rtl;
