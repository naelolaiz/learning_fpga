-- ROM_LUT_func.vhd
--
-- Storage method C: build the sin(angle)*nibble table by *computing*
-- every entry from a small precomputed seed table at elaboration
-- time. No hex literal, no external file — a 32-entry Q15
-- fixed-point sine table plus an integer cross-product is enough
-- to reconstruct the full 32 × 16 ROM, bit-for-bit identical to
-- method A's inline literal and method B's hex file.
--
-- Formula (matches generate_tables.py):
--   rom(row, col) = round( sin(row * pi/64) * col * 31 )
--
-- Equivalent integer form (synthesisable):
--   rom(row, col) = ( SIN_FIXED_Q15(row) * col * 31 + 16384 ) / 32768
-- where SIN_FIXED_Q15(a) = round(sin(a * pi/64) * 2^15).
--
-- All elaboration-time arithmetic is integer; yosys and Quartus
-- both fold the function call into a constant ROM the same way they
-- would for method A's inline literal. The "lesson" of method C is
-- preserved (compute the cross-product table from a much smaller
-- seed at elab time), but the construction is fully synthesisable —
-- no IEEE.MATH_REAL, no `real` arithmetic.
--
-- For a comparison with the textbook IEEE.MATH_REAL.SIN form (which
-- is simulation-only and not synthesisable), see
-- `test/tb_rom_lut_func_realmath.vhd`.

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

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

  -- Q15 fixed-point sine table.
  --     SIN_FIXED_Q15(a) = round( sin(a * pi/64) * 32768 )
  -- 32 entries covering [0, pi/2); upper quadrants are mirrored by
  -- the read-side logic below.
  type sin_q15_t is array (0 to 31) of integer;
  constant SIN_FIXED_Q15 : sin_q15_t := (
       0,  1608,  3212,  4808,  6393,  7962,  9512, 11039,
   12540, 14010, 15446, 16846, 18204, 19519, 20787, 22005,
   23170, 24279, 25330, 26319, 27245, 28106, 28898, 29621,
   30273, 30853, 31357, 31785, 32138, 32413, 32610, 32729
  );

  -- Build the full 32 × 16 ROM at elaboration using only integer
  -- arithmetic. Synthesisable: yosys/Quartus see this function as
  -- a constant table once elaborated.
  function compute_rom return TableOfTablesType is
    variable rom_var : TableOfTablesType;
    variable prod    : integer;
  begin
    for row in 0 to ARRAY_SIZE-1 loop
      for col in 0 to 15 loop
        prod := SIN_FIXED_Q15(row) * col * 31 + 16384;
        rom_var(row)(col) := std_logic_vector(
                                to_unsigned(prod / 32768, ELEMENTS_BITS_COUNT));
      end loop;
    end loop;
    return rom_var;
  end function;

  constant rom : TableOfTablesType := compute_rom;

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
