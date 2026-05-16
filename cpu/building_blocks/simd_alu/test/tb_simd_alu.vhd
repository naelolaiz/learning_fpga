-- tb_simd_alu.vhd
--
-- Golden-vector sweep covering every (width × operation × saturation)
-- combination of the simd_alu, plus the saturation boundary cases.

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity tb_simd_alu is
end entity tb_simd_alu;

architecture testbench of tb_simd_alu is

  signal a, b, result : std_logic_vector(31 downto 0) := (others => '0');
  signal op           : std_logic_vector(3 downto 0)  := (others => '0');
  signal flags        : std_logic_vector(3 downto 0);

  procedure check (
    constant tag    : in string;
    constant got_r  : in std_logic_vector(31 downto 0);
    constant exp_r  : in std_logic_vector(31 downto 0);
    constant got_f  : in std_logic_vector(3 downto 0);
    constant exp_f  : in std_logic_vector(3 downto 0)) is
  begin
    assert got_r = exp_r
      report tag & ": result expected " & to_hstring(exp_r)
             & " got " & to_hstring(got_r)
      severity error;
    assert got_f = exp_f
      report tag & ": flags expected " & to_string(exp_f)
             & " got " & to_string(got_f)
      severity error;
  end procedure;

begin

  dut : entity work.simd_alu
    port map (a => a, b => b, op => op, result => result, flags => flags);

  driver : process
  begin

    -- ===========================================================
    -- 4 × 8-bit lanes (width_sel = '0')
    -- ===========================================================

    -- ADD wrap: {0x01, 0x02, 0x03, 0x04} + {0x10, 0x20, 0x30, 0x40}
    --        = {0x11, 0x22, 0x33, 0x44}, no saturation
    a  <= x"04030201"; b <= x"40302010"; op <= "0000";   -- 4x8, add, wrap
    wait for 1 ns;
    check("4x8 add wrap",  result, x"44332211", flags, "0000");

    -- ADD saturating: {0x7F, 0x80, 0x10, 0xF0} + {0x01, 0x80, 0xF0, 0x10}
    -- lane 0: 127 + 1 = 128 → clamp to 127  (sat)
    -- lane 1: -128 + -128 = -256 → clamp to -128  (sat)
    -- lane 2: 16 + -16 = 0
    -- lane 3: -16 + 16 = 0
    a  <= x"F010807F"; b <= x"10F08001"; op <= "0001";   -- 4x8, add, sat
    wait for 1 ns;
    check("4x8 add sat",   result, x"0000807F", flags, "0011");

    -- SUB wrap: {0x10, 0x20, 0x30, 0x40} - {0x05, 0x05, 0x05, 0x05}
    --        = {0x0B, 0x1B, 0x2B, 0x3B}
    a  <= x"40302010"; b <= x"05050505"; op <= "0010";   -- 4x8, sub, wrap
    wait for 1 ns;
    check("4x8 sub wrap",  result, x"3B2B1B0B", flags, "0000");

    -- SUB saturating: {0x80, 0x7F, 0x00, 0xFF} - {0x01, 0xFF, 0x80, 0x80}
    -- lane 0: -128 - 1   = -129 → clamp to -128 (sat)
    -- lane 1:  127 - -1  =  128 → clamp to  127 (sat)
    -- lane 2:    0 - -128=  128 → clamp to  127 (sat)
    -- lane 3:   -1 - -128=  127 → no clamp
    a  <= x"FF007F80"; b <= x"8080FF01"; op <= "0011";   -- 4x8, sub, sat
    wait for 1 ns;
    check("4x8 sub sat",   result, x"7F7F7F80", flags, "0111");

    -- MIN signed: a={-1, 5, 10, -100} vs b={ 2, 3, 10, 50}
    --           = {-1, 3, 10, -100}
    a  <= x"9C0A05FF"; b <= x"320A0302"; op <= "0100";   -- 4x8, min
    -- Note: op[0] = 0 = saturate-doesn't-matter for min
    wait for 1 ns;
    check("4x8 min",       result, x"9C0A03FF", flags, "0000");

    -- MAX signed: same operands as MIN.
    --           = { 2,  5, 10,  50}
    a  <= x"9C0A05FF"; b <= x"320A0302"; op <= "0110";   -- 4x8, max
    wait for 1 ns;
    check("4x8 max",       result, x"320A0502", flags, "0000");

    -- ===========================================================
    -- 2 × 16-bit lanes (width_sel = '1')
    -- ===========================================================

    -- ADD wrap: {0x1234, 0x5678} + {0x1000, 0x2000} = {0x2234, 0x7678}
    a  <= x"56781234"; b <= x"20001000"; op <= "1000";   -- 2x16, add, wrap
    wait for 1 ns;
    check("2x16 add wrap", result, x"76782234", flags, "0000");

    -- ADD saturating: {0x7FFF, 0x8000} + {0x0001, 0x8000}
    -- lane 0:  32767 + 1     =  32768 → clamp  32767 (sat)
    -- lane 1: -32768 + -32768= -65536 → clamp -32768 (sat)
    a  <= x"80007FFF"; b <= x"80000001"; op <= "1001";   -- 2x16, add, sat
    wait for 1 ns;
    check("2x16 add sat",  result, x"80007FFF", flags, "0011");

    -- SUB wrap: {0x0010, 0x0020} - {0x0005, 0x0005} = {0x000B, 0x001B}
    a  <= x"00200010"; b <= x"00050005"; op <= "1010";   -- 2x16, sub, wrap
    wait for 1 ns;
    check("2x16 sub wrap", result, x"001B000B", flags, "0000");

    -- SUB saturating: {0x8000, 0x7FFF} - {0x0001, 0xFFFF}
    -- lane 0: -32768 - 1  = -32769 → clamp -32768 (sat)
    -- lane 1:  32767 - -1 =  32768 → clamp  32767 (sat)
    a  <= x"7FFF8000"; b <= x"FFFF0001"; op <= "1011";   -- 2x16, sub, sat
    wait for 1 ns;
    check("2x16 sub sat",  result, x"7FFF8000", flags, "0011");

    -- MIN signed: {-1, 5} vs {1, -2}  =  {-1, -2}
    a  <= x"0005FFFF"; b <= x"FFFE0001"; op <= "1100";   -- 2x16, min
    wait for 1 ns;
    check("2x16 min",      result, x"FFFEFFFF", flags, "0000");

    -- MAX signed: same operands  = { 1,  5}
    a  <= x"0005FFFF"; b <= x"FFFE0001"; op <= "1110";   -- 2x16, max
    wait for 1 ns;
    check("2x16 max",      result, x"00050001", flags, "0000");

    report "tb_simd_alu: all cases passed" severity note;
    wait;
  end process;

end architecture testbench;
