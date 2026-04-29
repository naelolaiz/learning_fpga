-- ROM_LUT_hex.vhd
--
-- Storage method B: load the same sin(angle)*nibble table from an
-- external hex file at elaboration time. Drop-in replacement for
-- single_clock_rom (method A); same I/O, same quadrant logic — only
-- the table-population strategy differs.
--
-- Method B is simulation-friendly (file I/O happens once during
-- elaboration via an impure function) and avoids carrying the table
-- literally in the source. Whether the hex-loaded form synthesises
-- depends on the toolchain — we don't make it the project's diagram
-- TOP. The multi-method testbench drives this entity alongside method
-- A and asserts bit-identical outputs.

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.std_logic_textio.all;

library std;
use std.textio.all;

entity single_clock_rom_hex is
  generic (
    ARRAY_SIZE          : integer := 32;
    ELEMENTS_BITS_COUNT : integer := 9;
    HEX_FILE            : string  := "rom_lut.hex"
  );
  port (
    clock              : in  std_logic;
    read_angle_idx     : in  std_logic_vector(6 downto 0);
    nibble_product_idx : in  std_logic_vector(3 downto 0);
    output             : out std_logic_vector(ELEMENTS_BITS_COUNT downto 0)
  );
end entity single_clock_rom_hex;

architecture rtl of single_clock_rom_hex is

  type HexMultiplicationTableType is
    array (0 to 15) of std_logic_vector(ELEMENTS_BITS_COUNT-1 downto 0);
  type TableOfTablesType is
    array (0 to ARRAY_SIZE-1) of HexMultiplicationTableType;

  -- Read the hex file once at elaboration. The file format is shared
  -- with Verilog $readmemh, which recognises `//` line comments;
  -- VHDL hread() doesn't, so we filter those out here. Each data
  -- line carries 16 hex tokens (3 chars = 12 bits each); we keep
  -- the lower 9 bits of every token.
  impure function load_rom_from_hex (filename : string) return TableOfTablesType is
    file     fhandle : text open read_mode is filename;
    variable lbuf    : line;
    variable token   : std_logic_vector(11 downto 0);
    variable rom_var : TableOfTablesType;
    variable row_idx : integer := 0;
  begin
    while row_idx < ARRAY_SIZE loop
      exit when endfile(fhandle);
      readline(fhandle, lbuf);
      -- Skip blank lines and `//` comment lines without short-
      -- circuiting in a condition: GHDL rejects `and then` here for
      -- the line-buffer attribute access, so split into nested ifs.
      if lbuf'length > 0 then
        if lbuf.all(lbuf.all'low) /= '/' then
          for col in 0 to 15 loop
            hread(lbuf, token);
            rom_var(row_idx)(col) := token(ELEMENTS_BITS_COUNT-1 downto 0);
          end loop;
          row_idx := row_idx + 1;
        end if;
      end if;
    end loop;
    return rom_var;
  end function;

  signal rom : TableOfTablesType := load_rom_from_hex(HEX_FILE);

begin

  process (clock)
    variable tableOfTablesIdx        : unsigned(4 downto 0) := (others => '0');
    alias    secondOrFourthQuadrant  : std_logic            is read_angle_idx(5);
    alias    thirdOrFourthQuadrant   : std_logic            is read_angle_idx(6);
    alias    firstQuadrantTableIndex : std_logic_vector(4 downto 0) is read_angle_idx(4 downto 0);
  begin
    if rising_edge(clock) then
      case secondOrFourthQuadrant is
        when '1'    => tableOfTablesIdx := 31 - unsigned(firstQuadrantTableIndex);
        when '0'    => tableOfTablesIdx := unsigned(firstQuadrantTableIndex);
        when others =>
      end case;

      case thirdOrFourthQuadrant is
        when '1'    =>
          output <= std_logic_vector(
                      0 - to_signed(
                            to_integer(unsigned(rom(to_integer(tableOfTablesIdx))
                                                  (to_integer(unsigned(nibble_product_idx))))),
                            ELEMENTS_BITS_COUNT+1));
        when '0'    =>
          output <= "0" & rom(to_integer(tableOfTablesIdx))
                            (to_integer(unsigned(nibble_product_idx)));
        when others =>
      end case;
    end if;
  end process;

end architecture rtl;
