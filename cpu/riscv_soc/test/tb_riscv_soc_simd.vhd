-- tb_riscv_soc_simd.vhd
--
-- End-to-end test of the SIMD accelerator behind the SoC's MMIO
-- map. Boots the SoC with prog_simd.hex (a tiny RV32I program that
-- writes operands+op to the SIMD MMIO regs, reads the result, and
-- streams the 4 result bytes LSB-first over the UART). The TB
-- samples each byte and asserts they match the expected
-- 0x44332211 → {0x11, 0x22, 0x33, 0x44}.
--
-- Sampler / halt-detector / CLKS_PER_BIT = 8 — same scaffolding as
-- tb_riscv_soc, just with a 4-byte expected sequence instead of the
-- "Hello, RV32!" greeting.

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity tb_riscv_soc_simd is
end entity tb_riscv_soc_simd;

architecture testbench of tb_riscv_soc_simd is
  constant CLK_PERIOD   : time    := 20 ns;
  constant CLKS_PER_BIT : integer := 8;
  constant BIT_TIME     : time    := CLK_PERIOD * CLKS_PER_BIT;
  constant HALT_INSTR   : std_logic_vector(31 downto 0) := x"0000006F";

  type byte_array_t is array (natural range <>) of std_logic_vector(7 downto 0);
  -- prog_simd.S computes 4x8-add of 0x04030201 + 0x40302010 = 0x44332211
  -- and streams it LSB first.
  constant EXPECTED : byte_array_t := (
    x"11", x"22", x"33", x"44"
  );

  signal sClk   : std_logic := '0';
  signal sRstN  : std_logic := '0';
  signal sUartTx : std_logic;
  signal sSimulationActive : boolean := true;

  signal sPc, sInstr, sRegWdata : std_logic_vector(31 downto 0);
  signal sRegWe : std_logic;
  signal sRegWaddr : std_logic_vector(4 downto 0);
  signal halted : std_logic := '0';

  signal captured_count : integer := 0;
begin

  dut : entity work.riscv_soc
    generic map (
      CLKS_PER_BIT => CLKS_PER_BIT,
      IMEM_INIT    => "programs/prog_simd.hex"
    )
    port map (
      clk_50mhz     => sClk,
      rst_n         => sRstN,
      uart_rx_in    => '1',
      uart_tx_out   => sUartTx,
      dbg_pc        => sPc,
      dbg_instr     => sInstr,
      dbg_reg_we    => sRegWe,
      dbg_reg_waddr => sRegWaddr,
      dbg_reg_wdata => sRegWdata
    );

  sClk <= not sClk after CLK_PERIOD/2 when sSimulationActive;

  halt_watcher : process (sClk) is
  begin
    if falling_edge(sClk) then
      if sInstr = HALT_INSTR then
        halted <= '1';
      end if;
    end if;
  end process;

  -- UART sampler: same start-bit / 8-data-bits / stop-bit protocol
  -- as tb_riscv_soc; checks each captured byte against EXPECTED.
  uart_sampler : process is
    variable bit_idx : integer := 0;
    variable byte_v  : std_logic_vector(7 downto 0) := (others => '0');
  begin
    wait until sRstN = '1';
    wait for 2 * CLK_PERIOD;

    while captured_count < EXPECTED'length loop
      wait until falling_edge(sUartTx);
      wait for BIT_TIME + BIT_TIME/2;
      bit_idx := 0;
      while bit_idx < 8 loop
        byte_v(bit_idx) := sUartTx;
        wait for BIT_TIME;
        bit_idx := bit_idx + 1;
      end loop;

      assert byte_v = EXPECTED(captured_count)
        report "SIMD UART byte " & integer'image(captured_count)
             & ": expected " & to_hstring(EXPECTED(captured_count))
             & ", got " & to_hstring(byte_v)
        severity error;
      captured_count <= captured_count + 1;
    end loop;
    wait;
  end process;

  driver : process is
    variable cycle_count : integer := 0;
    constant MAX_CYCLES  : integer := 5000;
  begin
    wait for 2 * CLK_PERIOD;
    sRstN <= '1';

    while (halted = '0' or captured_count < EXPECTED'length)
          and cycle_count < MAX_CYCLES loop
      wait until rising_edge(sClk);
      cycle_count := cycle_count + 1;
    end loop;

    assert halted = '1'
      report "Timeout: CPU did not halt within "
           & integer'image(MAX_CYCLES) & " cycles"
      severity failure;

    assert captured_count = EXPECTED'length
      report "Captured only " & integer'image(captured_count)
           & " of " & integer'image(EXPECTED'length)
           & " expected bytes"
      severity error;

    report "tb_riscv_soc_simd simulation done!" severity note;
    sSimulationActive <= false;
    wait;
  end process;

end architecture testbench;
