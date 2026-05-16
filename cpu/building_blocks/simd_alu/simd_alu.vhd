-- simd_alu.vhd
--
-- Packed SIMD ALU — one of two accelerator blocks that hang off the
-- SoC's address map (the other is fir4tap). Pure combinational; the
-- SoC wraps it in MMIO registers so the CPU writes operands + opcode
-- via SW and reads the result back via LW.
--
-- Lane shape (selected by op[3])
-- ------------------------------
--   op[3] = '0' : four signed 8-bit lanes  in a 32-bit word
--   op[3] = '1' : two signed 16-bit lanes  in a 32-bit word
--
-- Operations (op[2:1])
-- --------------------
--   00 add   : lane-wise a + b   (saturates if op[0]=1)
--   01 sub   : lane-wise a - b   (saturates if op[0]=1)
--   10 min   : lane-wise signed min(a, b)
--   11 max   : lane-wise signed max(a, b)
--
-- Saturation (op[0])
-- ------------------
--   0 = wrap        : silently truncates to lane width, signed
--                     overflow flips sign
--   1 = saturating  : clamps to [-2^(W-1), 2^(W-1)-1] where W is
--                     the lane width
--
-- Flags
-- -----
-- flags(i) = '1' if lane i saturated during this operation. For
-- 4×8-bit mode all four bits are valid; for 2×16-bit mode only
-- flags(1 downto 0) are valid, upper bits are zero. min/max never
-- saturate (they pick an input that already fits the lane).
--
-- Design intent
-- -------------
-- Two-instruction width selection (`op[3]` picks lane size) is the
-- one architectural choice that distinguishes a SIMD ALU from a
-- plain ALU. Everything else falls out of doing the same primitive
-- operation per lane in parallel.

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity simd_alu is
  port (
    a       : in  std_logic_vector(31 downto 0);
    b       : in  std_logic_vector(31 downto 0);
    op      : in  std_logic_vector(3 downto 0);
    result  : out std_logic_vector(31 downto 0);
    flags   : out std_logic_vector(3 downto 0)
  );
end entity simd_alu;

architecture rtl of simd_alu is

  -- Saturating add/sub for an N-bit signed lane. Computes in (N+1)
  -- bits, clamps to the signed N-bit range, returns the lane result
  -- and a saturated flag.
  function sat_addsub_8 (
    constant av : signed(7 downto 0);
    constant bv : signed(7 downto 0);
    constant is_sub : boolean;
    constant do_sat : boolean
  ) return std_logic_vector is
    variable wide : signed(8 downto 0);
    variable clamped : signed(7 downto 0);
    variable was_sat : std_logic := '0';
  begin
    if is_sub then
      wide := resize(av, 9) - resize(bv, 9);
    else
      wide := resize(av, 9) + resize(bv, 9);
    end if;
    -- Range check: signed 8-bit is [-128, 127].
    if do_sat and wide > 127 then
      clamped := to_signed(127, 8);
      was_sat := '1';
    elsif do_sat and wide < -128 then
      clamped := to_signed(-128, 8);
      was_sat := '1';
    else
      clamped := resize(wide, 8);   -- wrap on truncation
    end if;
    return std_logic_vector(clamped) & was_sat;
  end function;

  function sat_addsub_16 (
    constant av : signed(15 downto 0);
    constant bv : signed(15 downto 0);
    constant is_sub : boolean;
    constant do_sat : boolean
  ) return std_logic_vector is
    variable wide : signed(16 downto 0);
    variable clamped : signed(15 downto 0);
    variable was_sat : std_logic := '0';
  begin
    if is_sub then
      wide := resize(av, 17) - resize(bv, 17);
    else
      wide := resize(av, 17) + resize(bv, 17);
    end if;
    if do_sat and wide > 32767 then
      clamped := to_signed(32767, 16);
      was_sat := '1';
    elsif do_sat and wide < -32768 then
      clamped := to_signed(-32768, 16);
      was_sat := '1';
    else
      clamped := resize(wide, 16);
    end if;
    return std_logic_vector(clamped) & was_sat;
  end function;

  signal r       : std_logic_vector(31 downto 0);
  signal f       : std_logic_vector(3 downto 0);

  alias  width_sel : std_logic                    is op(3);
  alias  op_sel    : std_logic_vector(1 downto 0) is op(2 downto 1);
  alias  saturate  : std_logic                    is op(0);

begin

  process (a, b, op, width_sel, op_sel, saturate) is
    variable a8  : signed(7 downto 0);
    variable b8  : signed(7 downto 0);
    variable a16 : signed(15 downto 0);
    variable b16 : signed(15 downto 0);
    variable lane8  : std_logic_vector(8 downto 0);    -- 8 bits + sat
    variable lane16 : std_logic_vector(16 downto 0);   -- 16 bits + sat
    variable do_sat : boolean;
    variable is_sub : boolean;
  begin
    r       <= (others => '0');
    f       <= (others => '0');
    do_sat  := (saturate = '1');
    is_sub  := (op_sel = "01");

    if width_sel = '0' then
      -- 4 × 8-bit lanes
      for lane in 0 to 3 loop
        a8 := signed(a(lane*8+7 downto lane*8));
        b8 := signed(b(lane*8+7 downto lane*8));
        case op_sel is
          when "00" | "01" =>
            lane8 := sat_addsub_8(a8, b8, is_sub, do_sat);
            r(lane*8+7 downto lane*8) <= lane8(8 downto 1);
            f(lane) <= lane8(0);
          when "10" =>
            -- signed min: never saturates
            if a8 < b8 then
              r(lane*8+7 downto lane*8) <= std_logic_vector(a8);
            else
              r(lane*8+7 downto lane*8) <= std_logic_vector(b8);
            end if;
          when others => -- "11", max
            if a8 > b8 then
              r(lane*8+7 downto lane*8) <= std_logic_vector(a8);
            else
              r(lane*8+7 downto lane*8) <= std_logic_vector(b8);
            end if;
        end case;
      end loop;
    else
      -- 2 × 16-bit lanes
      for lane in 0 to 1 loop
        a16 := signed(a(lane*16+15 downto lane*16));
        b16 := signed(b(lane*16+15 downto lane*16));
        case op_sel is
          when "00" | "01" =>
            lane16 := sat_addsub_16(a16, b16, is_sub, do_sat);
            r(lane*16+15 downto lane*16) <= lane16(16 downto 1);
            f(lane) <= lane16(0);
          when "10" =>
            if a16 < b16 then
              r(lane*16+15 downto lane*16) <= std_logic_vector(a16);
            else
              r(lane*16+15 downto lane*16) <= std_logic_vector(b16);
            end if;
          when others =>
            if a16 > b16 then
              r(lane*16+15 downto lane*16) <= std_logic_vector(a16);
            else
              r(lane*16+15 downto lane*16) <= std_logic_vector(b16);
            end if;
        end case;
      end loop;
    end if;
  end process;

  result <= r;
  flags  <= f;

end architecture rtl;
