-- tb_rom_lut.vhd
--
-- Drives tl_rom_lut and asserts properties of the registered ROM output:
--   * nibble=0 yields zero for every angle (multiplying by 0 is 0).
--   * angle=0 yields zero for every nibble (sin(0)=0).
--   * Mirror around PI/2: out(31, n) == out(32, n) for every n.
--   * Anti-symmetry across PI: out(k, n) == -out(k+64, n).
--   * Peak magnitude in upper half: out(32, 15) = +464 (9x"1d0").
--   * Peak magnitude in lower half: out(96, 15) = -464.
--
-- Two register stages between input and output (one in tl_rom_lut, one in
-- single_clock_rom), so each drive waits two full clock periods before
-- sampling sReadByte.

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity tb_rom_lut is
end entity tb_rom_lut;

architecture testbench of tb_rom_lut is
  constant CLK_PERIOD : time    := 4 ns;
  constant LATENCY    : time    := 2 * CLK_PERIOD;

  signal sClock            : std_logic                    := '0';
  signal sAngleIdx         : std_logic_vector(6 downto 0) := (others => '0');
  signal sNibbleProductIdx : std_logic_vector(3 downto 0) := (others => '0');
  signal sReadByte         : std_logic_vector(9 downto 0) := (others => '0');
  signal sTestRunning      : boolean                      := true;
begin

  sClock <= not sClock after CLK_PERIOD / 2 when sTestRunning;

  dut : entity work.tl_rom_lut(logic)
    port map (inClock50Mhz       => sClock,
              inAngleIdxToRead   => sAngleIdx,
              inNibbleProductIdx => sNibbleProductIdx,
              outReadMemory      => sReadByte);

  driver : process
    -- Drive (a, n) and wait for the registered output to settle. Caller
    -- reads sReadByte right after this returns.
    procedure drive_and_settle (a : integer; n : integer) is
    begin
      sAngleIdx         <= std_logic_vector(to_unsigned(a, 7));
      sNibbleProductIdx <= std_logic_vector(to_unsigned(n, 4));
      wait for LATENCY;
    end procedure;

    function img (v : std_logic_vector) return string is
    begin
      return integer'image(to_integer(signed(v)));
    end function;

    variable v_first : integer;
  begin
    -- Synchronise to a falling edge so the first drive doesn't race
    -- with the very first rising edge of the clock.
    wait until falling_edge(sClock);

    -- 1) nibble=0 always yields zero, regardless of angle.
    for a in 0 to 127 loop
      drive_and_settle(a, 0);
      assert to_integer(signed(sReadByte)) = 0
        report "nibble=0 should yield 0; got " & img(sReadByte) &
               " at angle=" & integer'image(a)
        severity error;
    end loop;

    -- 2) angle=0 always yields zero, regardless of nibble (sin(0)=0).
    for n in 0 to 15 loop
      drive_and_settle(0, n);
      assert to_integer(signed(sReadByte)) = 0
        report "angle=0 should yield 0; got " & img(sReadByte) &
               " at nibble=" & integer'image(n)
        severity error;
    end loop;

    -- 3) Peak positive: angle index 32 maps (via the bit5 mirror) onto
    --    row 31 with the upper-half sign, nibble 15 -> 9x"1d0" = 464.
    drive_and_settle(32, 15);
    assert to_integer(signed(sReadByte)) = 464
      report "peak positive expected 464, got " & img(sReadByte)
      severity error;

    -- 4) Peak negative: angle index 96 maps onto row 31 with the
    --    lower-half sign, nibble 15 -> -464.
    drive_and_settle(96, 15);
    assert to_integer(signed(sReadByte)) = -464
      report "peak negative expected -464, got " & img(sReadByte)
      severity error;

    -- 5) Mirror around PI/2: out(31, n) == out(32, n).
    for n in 1 to 15 loop
      drive_and_settle(31, n);
      v_first := to_integer(signed(sReadByte));
      drive_and_settle(32, n);
      assert to_integer(signed(sReadByte)) = v_first
        report "mirror PI/2 broken at nibble=" & integer'image(n) &
               ": out(31,n)=" & integer'image(v_first) &
               " vs out(32,n)=" & img(sReadByte)
        severity error;
    end loop;

    -- 6) Anti-symmetry across PI: out(k, 15) == -out(k+64, 15) for k in 0..63.
    for k in 0 to 63 loop
      drive_and_settle(k, 15);
      v_first := to_integer(signed(sReadByte));
      drive_and_settle(k + 64, 15);
      assert to_integer(signed(sReadByte)) = -v_first
        report "antisymmetry broken at k=" & integer'image(k) &
               ": out(k,15)=" & integer'image(v_first) &
               " vs out(k+64,15)=" & img(sReadByte)
        severity error;
    end loop;

    report "tb_rom_lut: all assertions passed" severity note;
    sTestRunning <= false;
    wait;
  end process;

end architecture testbench;
