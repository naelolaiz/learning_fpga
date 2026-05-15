-- ram_sync.vhd
--
-- Single-port synchronous RAM with optional hex-file initialisation.
-- Both writes and reads are clocked: on every rising edge the addressed
-- word is latched into `rdata`, and if `we` is asserted on the same
-- edge the word at `addr` is overwritten with `wdata`. The result is
-- read-before-write semantics on a same-cycle write+read — `rdata`
-- carries the value that was at `addr` *before* this clock edge.
--
-- This is the BRAM-friendly pattern: Quartus and yosys both infer a
-- block RAM for this shape. Two important details mirror
-- ROM_LUT.vhd's hard-won quirk: the storage is a `signal` (not a
-- `constant`) because Quartus refuses to map a `constant` array to a
-- BRAM, and the read register is inside the same clocked process so
-- the synthesiser sees a single sync read port.
--
-- Sizing: pass the address width via the `ADDR_W` generic; depth is
-- always a power of two (DEPTH = 2**ADDR_W). This matches the BRAM's
-- native shape and keeps the entity port list independent of any
-- elaboration-time math (no ieee.math_real, no clog2 at the entity
-- boundary — both have subtle cross-tool quirks the rest of the
-- repo avoids).
--
-- Generic INIT_FILE accepts a path to a hex file (one word per line,
-- ASCII hex digits). Empty string means "start at all zeros". The
-- file is loaded once at elaboration via textio — at runtime the RAM
-- is fully writable from then on.

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.textio.all;

entity ram_sync is
  generic (
    WIDTH     : integer := 32;
    ADDR_W    : integer := 10;          -- DEPTH = 2**ADDR_W (1024 by default)
    INIT_FILE : string  := ""
  );
  port (
    clk   : in  std_logic;
    we    : in  std_logic;
    addr  : in  std_logic_vector(ADDR_W-1 downto 0);
    wdata : in  std_logic_vector(WIDTH-1  downto 0);
    rdata : out std_logic_vector(WIDTH-1  downto 0)
  );
end entity ram_sync;

architecture rtl of ram_sync is
  constant DEPTH : integer := 2**ADDR_W;
  type ram_t is array (0 to DEPTH-1) of std_logic_vector(WIDTH-1 downto 0);

  -- Loads the hex file into the array; returns all-zeros when no file
  -- name was supplied. `impure` because file_open touches host state.
  impure function init_ram(filename : string) return ram_t is
    file     f      : text;
    variable l      : line;
    variable v      : std_logic_vector(WIDTH-1 downto 0);
    variable result : ram_t := (others => (others => '0'));
  begin
    if filename = "" then
      return result;
    end if;
    file_open(f, filename, read_mode);
    for i in 0 to DEPTH-1 loop
      exit when endfile(f);
      readline(f, l);
      hread(l, v);
      result(i) := v;
    end loop;
    file_close(f);
    return result;
  end function;

  -- IMPORTANT: storage is a `signal`, not a `constant`. The
  -- ROM_LUT.vhd note applies here too — Quartus emits the array as
  -- logic elements when it's `constant`, and only collapses it to a
  -- BRAM when it's a `signal` initialised inline.
  signal mem : ram_t := init_ram(INIT_FILE);
begin

  process (clk)
  begin
    if rising_edge(clk) then
      if we = '1' then
        mem(to_integer(unsigned(addr))) <= wdata;
      end if;
      rdata <= mem(to_integer(unsigned(addr)));
    end if;
  end process;

end architecture rtl;
