-- ROM_LUT_func.vhd
--
-- Storage method C: build the same sin(angle)*nibble table by *computing*
-- every entry from IEEE.MATH_REAL at elaboration time. No hex literal in
-- the source, no external file, no Python preprocessing — the formula
-- itself is the source of truth.
--
-- The formula matches generate_tables.py:
--     entry(row, col) = round( sin(row * pi/2 / 32) * col * (2^5 - 1) )
-- where 2^5 - 1 = 31 is the unsigned magnitude budget left after
-- factoring out the 4-bit nibble. The result fits in 9 bits.
--
-- Like method B this is the simulation-friendly form (math_real is a
-- standard library but synthesizers vary on supporting it). The
-- multi-method testbench asserts bit-identical outputs across A/B/C.

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;

entity single_clock_rom_func is
  generic (
    ARRAY_SIZE          : integer := 32;
    ELEMENTS_BITS_COUNT : integer := 9
  );
  port (
    clock              : in  std_logic;
    read_angle_idx     : in  std_logic_vector(6 downto 0);
    nibble_product_idx : in  std_logic_vector(3 downto 0);
    output             : out std_logic_vector(ELEMENTS_BITS_COUNT downto 0)
  );
end entity single_clock_rom_func;

architecture rtl of single_clock_rom_func is

  type HexMultiplicationTableType is
    array (0 to 15) of std_logic_vector(ELEMENTS_BITS_COUNT-1 downto 0);
  type TableOfTablesType is
    array (0 to ARRAY_SIZE-1) of HexMultiplicationTableType;

  function compute_rom return TableOfTablesType is
    constant MAGNITUDE  : real := 2.0 ** (ELEMENTS_BITS_COUNT - 4) - 1.0;  -- 31.0
    variable rom_var    : TableOfTablesType;
    variable angle      : real;
    variable val        : integer;
  begin
    for row in 0 to ARRAY_SIZE-1 loop
      angle := MATH_PI_OVER_2 * real(row) / real(ARRAY_SIZE);
      for col in 0 to 15 loop
        val := integer(round(SIN(angle) * real(col) * MAGNITUDE));
        rom_var(row)(col) := std_logic_vector(to_unsigned(val, ELEMENTS_BITS_COUNT));
      end loop;
    end loop;
    return rom_var;
  end function;

  signal rom : TableOfTablesType := compute_rom;

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
