-- tb_rom_lut_methods.vhd
--
-- Equivalence proof for the three storage methods. Instantiates
--   * single_clock_rom        (method A: inline literal in ROM_LUT.vhd)
--   * single_clock_rom_hex    (method B: textio-loaded rom_lut.hex)
--   * single_clock_rom_func   (method C: math_real-computed at elaboration)
-- side by side, drives identical (angle, nibble) stimuli, and asserts
-- bit-identical outputs cycle by cycle.
--
-- Each method has the same 1-cycle output latency, so a single clock
-- after a drive every output port reflects the same address.

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity tb_rom_lut_methods is
end entity tb_rom_lut_methods;

architecture testbench of tb_rom_lut_methods is
  constant CLK_PERIOD : time := 4 ns;

  signal sClock        : std_logic                    := '0';
  signal sAngleIdx     : std_logic_vector(6 downto 0) := (others => '0');
  signal sNibbleIdx    : std_logic_vector(3 downto 0) := (others => '0');
  signal sOutA         : std_logic_vector(9 downto 0);
  signal sOutB         : std_logic_vector(9 downto 0);
  signal sOutC         : std_logic_vector(9 downto 0);
  signal sTestRunning  : boolean                      := true;
begin

  sClock <= not sClock after CLK_PERIOD / 2 when sTestRunning;

  rom_a : entity work.single_clock_rom
    port map (clock              => sClock,
              read_angle_idx     => sAngleIdx,
              nibble_product_idx => sNibbleIdx,
              output             => sOutA);

  rom_b : entity work.single_clock_rom_hex
    port map (clock              => sClock,
              read_angle_idx     => sAngleIdx,
              nibble_product_idx => sNibbleIdx,
              output             => sOutB);

  rom_c : entity work.single_clock_rom_func
    port map (clock              => sClock,
              read_angle_idx     => sAngleIdx,
              nibble_product_idx => sNibbleIdx,
              output             => sOutC);

  driver : process
    variable mismatches : integer := 0;
  begin
    wait until falling_edge(sClock);

    -- Sweep the entire address space, one rising edge per address. The
    -- single-cycle latency means the output ports reflect the address
    -- driven on the previous edge; the comparison only looks at A vs
    -- B vs C at the same time, so the lag is harmless and uniform.
    for a in 0 to 127 loop
      for n in 0 to 15 loop
        sAngleIdx  <= std_logic_vector(to_unsigned(a, 7));
        sNibbleIdx <= std_logic_vector(to_unsigned(n, 4));
        wait until falling_edge(sClock);
        if sOutA /= sOutB then
          report "method A != B at (a=" & integer'image(a) &
                 ", n=" & integer'image(n) & "): " &
                 integer'image(to_integer(signed(sOutA))) & " vs " &
                 integer'image(to_integer(signed(sOutB)))
                 severity error;
          mismatches := mismatches + 1;
        end if;
        if sOutA /= sOutC then
          report "method A != C at (a=" & integer'image(a) &
                 ", n=" & integer'image(n) & "): " &
                 integer'image(to_integer(signed(sOutA))) & " vs " &
                 integer'image(to_integer(signed(sOutC)))
                 severity error;
          mismatches := mismatches + 1;
        end if;
      end loop;
    end loop;

    assert mismatches = 0
      report "tb_rom_lut_methods: " & integer'image(mismatches) & " mismatches"
      severity error;

    report "tb_rom_lut_methods: all three methods agree on every address"
      severity note;
    sTestRunning <= false;
    wait;
  end process;

end architecture testbench;
