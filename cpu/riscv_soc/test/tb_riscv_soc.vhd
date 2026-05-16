-- tb_riscv_soc.vhd
--
-- Boots the SoC with prog_hello.hex in IMEM, samples the UART_TX
-- pin at each bit-center, captures the LSB-first byte, and asserts
-- the running output equals the expected "Hello, RV32!\n" greeting.
--
-- CLKS_PER_BIT is set very small (8) for this testbench so the
-- simulation finishes in microseconds rather than the milliseconds
-- a real 9600-baud setup would take. The DUT exposes that as a
-- generic precisely to make the testbench fast — the board build
-- uses the default 5208 (50 MHz / 9600).
--
-- The UART sampler is bit-banged inline rather than instantiating
-- uart_rx, so the testbench has no extra dependency and the bit
-- semantics are visible in the code: start bit → 8 data bits LSB
-- first → stop bit.

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity tb_riscv_soc is
end entity tb_riscv_soc;

architecture testbench of tb_riscv_soc is
  constant CLK_PERIOD   : time    := 20 ns;
  constant CLKS_PER_BIT : integer := 8;
  constant BIT_TIME     : time    := CLK_PERIOD * CLKS_PER_BIT;
  constant HALT_INSTR   : std_logic_vector(31 downto 0) := x"0000006F";

  -- The greeting string the program should send.
  -- ASCII for "Hello, RV32!\n" — 13 bytes.
  type byte_array_t is array (natural range <>) of std_logic_vector(7 downto 0);
  constant EXPECTED : byte_array_t := (
    x"48", x"65", x"6C", x"6C", x"6F",  -- "Hello"
    x"2C", x"20",                        -- ", "
    x"52", x"56", x"33", x"32",          -- "RV32"
    x"21", x"0A"                         -- "!\n"
  );

  signal sClk : std_logic := '0';
  signal sRstN : std_logic := '0';
  signal sUartTx : std_logic;
  signal sSimulationActive : boolean := true;

  -- Debug bus + halt detection
  signal sPc, sInstr, sRegWdata : std_logic_vector(31 downto 0);
  signal sRegWe : std_logic;
  signal sRegWaddr : std_logic_vector(4 downto 0);
  signal halted : std_logic := '0';

  -- Captured UART bytes (the sampler appends; the checker compares
  -- the running prefix on every new byte).
  signal captured_count : integer                       := 0;
  signal captured_match : std_logic                     := '1';
  signal captured_last  : std_logic_vector(7 downto 0)  := (others => '0');
begin

  dut : entity work.riscv_soc
    generic map (
      CLKS_PER_BIT => CLKS_PER_BIT,
      IMEM_INIT    => "programs/prog_hello.hex"
    )
    port map (
      clk_50mhz     => sClk,
      rst_n         => sRstN,
      uart_rx_in    => '1',                -- idle high; we don't drive RX
      uart_tx_out   => sUartTx,
      dbg_pc        => sPc,
      dbg_instr     => sInstr,
      dbg_reg_we    => sRegWe,
      dbg_reg_waddr => sRegWaddr,
      dbg_reg_wdata => sRegWdata
    );

  sClk <= not sClk after CLK_PERIOD/2 when sSimulationActive;

  -- Halt detector (snoops debug bus). Falling edge to match the
  -- CPU's regfile commit timing — same idiom as the single-cycle
  -- testbench.
  halt_watcher : process (sClk) is
  begin
    if falling_edge(sClk) then
      if sInstr = HALT_INSTR then
        halted <= '1';
      end if;
    end if;
  end process;

  -- UART sampler — waits for the falling start-bit edge, then
  -- samples each data bit at its centre and stitches the byte back
  -- together. Checks against EXPECTED as it goes.
  uart_sampler : process is
    variable bit_idx : integer := 0;
    variable byte_v  : std_logic_vector(7 downto 0) := (others => '0');
  begin
    -- Wait until reset releases AND the line is idle-high.
    wait until sRstN = '1';
    wait for 2 * CLK_PERIOD;

    while captured_count < EXPECTED'length loop
      -- Wait for the start-bit falling edge. The CPU's HALT
      -- instruction fires ~5 cycles after the last SW that triggers
      -- UART transmission — but the UART itself takes ~80 cycles
      -- per byte at CLKS_PER_BIT=8 to finish framing. Exiting the
      -- sampler on halt would drop the last byte mid-flight, so we
      -- let it run until all expected bytes are captured and let
      -- the driver process bound the overall simulation time.
      wait until falling_edge(sUartTx);

      -- Skip past start bit + half a bit so we land at the centre
      -- of bit 0.
      wait for BIT_TIME + BIT_TIME/2;

      -- Sample 8 data bits LSB first.
      bit_idx := 0;
      while bit_idx < 8 loop
        byte_v(bit_idx) := sUartTx;
        wait for BIT_TIME;
        bit_idx := bit_idx + 1;
      end loop;

      -- byte_v is the captured byte. Check it.
      captured_last  <= byte_v;
      assert byte_v = EXPECTED(captured_count)
        report "UART byte " & integer'image(captured_count)
             & ": expected " & to_hstring(EXPECTED(captured_count))
             & ", got " & to_hstring(byte_v)
        severity error;
      captured_count <= captured_count + 1;
    end loop;
    wait;
  end process;

  -- Driver: release reset, run until either halt + full string captured
  -- OR a generous timeout.
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

    report "tb_riscv_soc simulation done!" severity note;
    sSimulationActive <= false;
    wait;
  end process;

end architecture testbench;
