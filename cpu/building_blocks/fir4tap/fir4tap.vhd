-- fir4tap.vhd
--
-- 4-tap streaming FIR filter — the DSP-flavoured counterpart to
-- simd_alu. Pure structural composition: a 4-stage sample shift
-- register, four signed multipliers, an adder tree, and a result
-- register. The SoC integration in F1c hangs this behind a small
-- MMIO interface so the CPU streams audio samples via SW writes and
-- reads filter output via LW reads.
--
-- Data widths
-- -----------
--   sample_in     16-bit signed (typical audio)
--   coeff_<i>     9-bit signed  (Q1.8: 256 ≡ +1.0; range ≈ [-1, +1))
--                 9-bit chosen to match the Cyclone IV hard 9x9
--                 multiplier exactly — one DSP block per tap, no
--                 chained-multiplier overhead.
--   result        16-bit signed (upper 16 bits of the 27-bit MAC sum,
--                 sliced at bit 9 so a unity-gain filter — sum of
--                 coefficients ≈ 256 — maps sample → result with no
--                 rescaling)
--
-- Timing
-- ------
--   sample_valid pulse on cycle N
--     → cycle N+1: new sample is in samples[0], MAC computes combinatorially
--     → cycle N+2: result_reg latched, result_valid pulses
--
-- Two-cycle pipeline. result_valid is exactly one clock wide per
-- sample_valid pulse.

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity fir4tap is
  port (
    clk          : in  std_logic;
    rst          : in  std_logic;                       -- sync, active high

    -- Filter coefficients (runtime-writable from the SoC integration).
    coeff_0      : in  std_logic_vector(8 downto 0);
    coeff_1      : in  std_logic_vector(8 downto 0);
    coeff_2      : in  std_logic_vector(8 downto 0);
    coeff_3      : in  std_logic_vector(8 downto 0);

    -- Sample stream.
    sample_in    : in  std_logic_vector(15 downto 0);
    sample_valid : in  std_logic;

    -- Filtered output.
    result       : out std_logic_vector(15 downto 0);
    result_valid : out std_logic
  );
end entity fir4tap;

architecture rtl of fir4tap is

  type sample_array_t is array (0 to 3) of signed(15 downto 0);

  signal samples    : sample_array_t := (others => (others => '0'));
  signal mac_sum    : signed(26 downto 0);
  signal result_reg : std_logic_vector(15 downto 0) := (others => '0');
  signal valid_d1   : std_logic := '0';
  signal valid_d2   : std_logic := '0';

begin

  -- Sample shift register. On sample_valid, the new sample lands in
  -- samples(0) and the older samples shift one position deeper.
  -- valid_d1 / valid_d2 are the two-stage matching delay for
  -- result_valid: d1 corresponds to "samples are stable, MAC is
  -- computing"; d2 to "MAC has been latched into result_reg".
  shift_reg : process (clk) is
  begin
    if rising_edge(clk) then
      if rst = '1' then
        samples  <= (others => (others => '0'));
        valid_d1 <= '0';
        valid_d2 <= '0';
      else
        valid_d1 <= sample_valid;
        valid_d2 <= valid_d1;
        if sample_valid = '1' then
          samples(0) <= signed(sample_in);
          samples(1) <= samples(0);
          samples(2) <= samples(1);
          samples(3) <= samples(2);
        end if;
      end if;
    end if;
  end process;

  -- Combinational MAC: sum of four signed 16x9 products. Each
  -- product is 25-bit; the 4-term sum needs +2 bits of headroom →
  -- 27-bit signed accumulator.
  mac_sum <= resize(samples(0) * signed(coeff_0), 27)
           + resize(samples(1) * signed(coeff_1), 27)
           + resize(samples(2) * signed(coeff_2), 27)
           + resize(samples(3) * signed(coeff_3), 27);

  -- Result register: slice mac_sum[23:8] for the 16-bit output.
  -- Q1.8 coefficients mean coeff_value 256 ≡ +1.0, so the integer-
  -- domain output is (sample * coeff_int) / 256 = mac_sum >> 8.
  -- We take the lower 16 bits of that, so the user is responsible
  -- for keeping the running sum within ±32767 (typical for audio:
  -- sum of |coefficients| ≤ 256 keeps a full-scale 16-bit input
  -- from overflowing).
  reg_out : process (clk) is
  begin
    if rising_edge(clk) then
      if rst = '1' then
        result_reg <= (others => '0');
      elsif valid_d1 = '1' then
        result_reg <= std_logic_vector(mac_sum(23 downto 8));
      end if;
    end if;
  end process;

  result       <= result_reg;
  result_valid <= valid_d2;

end architecture rtl;
