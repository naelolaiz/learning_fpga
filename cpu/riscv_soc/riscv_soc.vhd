-- riscv_soc.vhd
--
-- Small SoC built around the single-cycle RV32I core: CPU + 4 KB
-- DMEM + memory-mapped UART (TX + RX) + two accelerators (the
-- packed-SIMD ALU and the 4-tap FIR from cpu/building_blocks/).
-- The IMEM is internal to the CPU; the DMEM, UART, and accelerators
-- share the CPU's external DMEM bus through an address decoder.
--
-- Address map (32-bit byte addresses)
-- ----------------------------------
--   0x0000_0000 .. 0x0000_0FFF   IMEM (internal to CPU, 4 KB,
--                                init from IMEM_INIT)
--   0x0001_0000 .. 0x0001_0FFF   DMEM (4 KB, R/W; addr[31]=0 only,
--                                addr[11:2] indexes the word array)
--
--   0x8000_0000   UART_TX_DATA   W: send byte; R: bit 0 = tx_busy
--   0x8000_0004   UART_RX_DATA   R: bits[7:0] = byte, bit 31 = ready
--
--   0x8000_0030   SIMD_OPERAND_A W
--   0x8000_0034   SIMD_OPERAND_B W
--   0x8000_0038   SIMD_OP        W (low 4 bits — see simd_alu README)
--   0x8000_003C   SIMD_RESULT    R
--   0x8000_0040   SIMD_FLAGS     R (low 4 bits, saturation per lane)
--
--   0x8000_0050   FIR_COEFFS_01  W (coeff_0 bits[8:0], coeff_1 bits[24:16])
--   0x8000_0054   FIR_COEFFS_23  W (coeff_2 bits[8:0], coeff_3 bits[24:16])
--   0x8000_0058   FIR_SAMPLE     W (write triggers sample_valid pulse;
--                                  the low 16 bits are the signed sample)
--   0x8000_005C   FIR_RESULT     R (most recent filter output)
--   0x8000_0060   FIR_STATUS     R (bit 0 = result_valid latch; the
--                                  CPU polls this to know a fresh
--                                  result is ready)
--
-- Decoder: addr[31]=1 selects MMIO; within MMIO, addr[7:2] picks
-- which 32-bit register slot. Crude but enough for the tutorial
-- peripheral set.

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity riscv_soc is
  generic (
    -- Override CLKS_PER_BIT for fast simulation (default 5208 =
    -- 50 MHz / 9600 baud, for board synthesis).
    CLKS_PER_BIT : integer := 5208;
    IMEM_INIT    : string  := ""
  );
  port (
    clk_50mhz   : in  std_logic;
    rst_n       : in  std_logic;          -- active-low (board buttons are active-low)
    uart_rx_in  : in  std_logic := '1';   -- idle-high; default safe value
    uart_tx_out : out std_logic;

    -- Debug bus surfaced for the testbench; safe to leave dangling.
    dbg_pc        : out std_logic_vector(31 downto 0);
    dbg_instr     : out std_logic_vector(31 downto 0);
    dbg_reg_we    : out std_logic;
    dbg_reg_waddr : out std_logic_vector(4  downto 0);
    dbg_reg_wdata : out std_logic_vector(31 downto 0)
  );
end entity riscv_soc;

architecture rtl of riscv_soc is

  signal rst : std_logic;

  -- CPU's external DMEM bus
  signal cpu_dmem_addr  : std_logic_vector(31 downto 0);
  signal cpu_dmem_wdata : std_logic_vector(31 downto 0);
  signal cpu_dmem_we    : std_logic;
  signal cpu_dmem_re    : std_logic;
  signal cpu_dmem_rdata : std_logic_vector(31 downto 0);

  -- DMEM (4 KB = 1024 32-bit words). Sync write, async read.
  constant DMEM_DEPTH : integer := 1024;
  type dmem_t is array (0 to DMEM_DEPTH-1) of std_logic_vector(31 downto 0);
  signal dmem       : dmem_t := (others => (others => '0'));
  signal dmem_rdata : std_logic_vector(31 downto 0) := (others => '0');

  -- Address decode: addr[31] picks MMIO vs DMEM; within MMIO,
  -- addr[7:2] is the 6-bit word offset.
  signal is_mmio    : std_logic;
  signal dmem_we_q  : std_logic;
  signal mmio_we    : std_logic;
  signal mmio_word  : std_logic_vector(5 downto 0);

  -- UART_TX wrapper
  signal uart_tx_busy  : std_logic;
  signal uart_tx_start : std_logic := '0';
  signal uart_tx_data  : std_logic_vector(7 downto 0) := (others => '0');

  -- UART_RX wrapper
  signal uart_rx_data   : std_logic_vector(7 downto 0);
  signal uart_rx_valid  : std_logic;
  signal rx_byte_latch  : std_logic_vector(7 downto 0) := (others => '0');
  signal rx_ready_latch : std_logic                    := '0';
  signal rx_read_pulse  : std_logic;

  -- SIMD accelerator registers (combinational result/flags
  -- computed straight from the latched operand+op regs).
  signal simd_a      : std_logic_vector(31 downto 0) := (others => '0');
  signal simd_b      : std_logic_vector(31 downto 0) := (others => '0');
  signal simd_op     : std_logic_vector(3 downto 0)  := (others => '0');
  signal simd_result : std_logic_vector(31 downto 0);
  signal simd_flags  : std_logic_vector(3 downto 0);

  -- FIR accelerator registers
  signal fir_coeff_0     : std_logic_vector(8 downto 0)  := (others => '0');
  signal fir_coeff_1     : std_logic_vector(8 downto 0)  := (others => '0');
  signal fir_coeff_2     : std_logic_vector(8 downto 0)  := (others => '0');
  signal fir_coeff_3     : std_logic_vector(8 downto 0)  := (others => '0');
  signal fir_sample_data : std_logic_vector(15 downto 0) := (others => '0');
  signal fir_sample_pulse: std_logic := '0';
  signal fir_result      : std_logic_vector(15 downto 0);
  signal fir_result_valid: std_logic;
  signal fir_result_latch: std_logic_vector(15 downto 0) := (others => '0');
  signal fir_ready_latch : std_logic := '0';
begin

  rst <= not rst_n;

  -- ---------------------------------------------------------------
  -- CPU
  -- ---------------------------------------------------------------
  cpu : entity work.riscv_singlecycle
    generic map (
      IMEM_ADDR_W => 10,                 -- 4 KB IMEM
      IMEM_INIT   => IMEM_INIT
    )
    port map (
      clk           => clk_50mhz,
      rst           => rst,
      dmem_addr     => cpu_dmem_addr,
      dmem_wdata    => cpu_dmem_wdata,
      dmem_we       => cpu_dmem_we,
      dmem_re       => cpu_dmem_re,
      dmem_rdata    => cpu_dmem_rdata,
      dbg_pc        => dbg_pc,
      dbg_instr     => dbg_instr,
      dbg_reg_we    => dbg_reg_we,
      dbg_reg_waddr => dbg_reg_waddr,
      dbg_reg_wdata => dbg_reg_wdata
    );

  -- ---------------------------------------------------------------
  -- Address decoder
  -- ---------------------------------------------------------------
  is_mmio    <= cpu_dmem_addr(31);
  dmem_we_q  <= cpu_dmem_we and not is_mmio;
  mmio_we    <= cpu_dmem_we and is_mmio;
  mmio_word  <= cpu_dmem_addr(7 downto 2);

  -- ---------------------------------------------------------------
  -- DMEM — sync write, async read
  -- ---------------------------------------------------------------
  process (clk_50mhz) is
  begin
    if rising_edge(clk_50mhz) then
      if dmem_we_q = '1' then
        dmem(to_integer(unsigned(cpu_dmem_addr(11 downto 2)))) <= cpu_dmem_wdata;
      end if;
    end if;
  end process;

  dmem_rdata <= dmem(to_integer(unsigned(cpu_dmem_addr(11 downto 2))));

  -- ---------------------------------------------------------------
  -- UART TX peripheral: write to UART_TX_DATA (word 0) sends LSB byte
  -- ---------------------------------------------------------------
  process (clk_50mhz) is
  begin
    if rising_edge(clk_50mhz) then
      uart_tx_start <= '0';        -- default; one-clock pulse
      if rst = '1' then
        uart_tx_data <= (others => '0');
      elsif mmio_we = '1' and mmio_word = "000000" and uart_tx_busy = '0' then
        uart_tx_data  <= cpu_dmem_wdata(7 downto 0);
        uart_tx_start <= '1';
      end if;
    end if;
  end process;

  tx : entity work.uart_tx
    generic map (CLKS_PER_BIT => CLKS_PER_BIT)
    port map (
      clk      => clk_50mhz,
      tx_start => uart_tx_start,
      tx_data  => uart_tx_data,
      tx       => uart_tx_out,
      tx_busy  => uart_tx_busy
    );

  -- ---------------------------------------------------------------
  -- UART RX peripheral: latches each received byte until the CPU
  -- reads it from 0x8000_0004; the read drains the latch.
  -- ---------------------------------------------------------------
  rx : entity work.uart_rx
    generic map (CLKS_PER_BIT => CLKS_PER_BIT)
    port map (
      clk      => clk_50mhz,
      rx       => uart_rx_in,
      rx_data  => uart_rx_data,
      rx_valid => uart_rx_valid
    );

  rx_read_pulse <= '1' when cpu_dmem_re = '1' and is_mmio = '1'
                                              and mmio_word = "000001"
              else '0';

  process (clk_50mhz) is
  begin
    if rising_edge(clk_50mhz) then
      if rst = '1' then
        rx_byte_latch  <= (others => '0');
        rx_ready_latch <= '0';
      elsif uart_rx_valid = '1' then
        -- New byte from the receiver — overwrite the latch even if
        -- the previous byte hasn't been read yet (single-entry
        -- buffer; the tutorial CPU polls fast enough at 9600 baud).
        rx_byte_latch  <= uart_rx_data;
        rx_ready_latch <= '1';
      elsif rx_read_pulse = '1' then
        rx_ready_latch <= '0';
      end if;
    end if;
  end process;

  -- ---------------------------------------------------------------
  -- SIMD accelerator (pure combinational) + its write path
  -- ---------------------------------------------------------------
  simd : entity work.simd_alu
    port map (
      a      => simd_a,
      b      => simd_b,
      op     => simd_op,
      result => simd_result,
      flags  => simd_flags
    );

  simd_write : process (clk_50mhz) is
  begin
    if rising_edge(clk_50mhz) then
      if rst = '1' then
        simd_a  <= (others => '0');
        simd_b  <= (others => '0');
        simd_op <= (others => '0');
      elsif mmio_we = '1' then
        case mmio_word is
          when "001100" => simd_a  <= cpu_dmem_wdata;                    -- 0x30
          when "001101" => simd_b  <= cpu_dmem_wdata;                    -- 0x34
          when "001110" => simd_op <= cpu_dmem_wdata(3 downto 0);        -- 0x38
          when others   => null;
        end case;
      end if;
    end if;
  end process;

  -- ---------------------------------------------------------------
  -- FIR accelerator + its write path + result latch
  -- ---------------------------------------------------------------
  fir : entity work.fir4tap
    port map (
      clk          => clk_50mhz,
      rst          => rst,
      coeff_0      => fir_coeff_0,
      coeff_1      => fir_coeff_1,
      coeff_2      => fir_coeff_2,
      coeff_3      => fir_coeff_3,
      sample_in    => fir_sample_data,
      sample_valid => fir_sample_pulse,
      result       => fir_result,
      result_valid => fir_result_valid
    );

  fir_write : process (clk_50mhz) is
  begin
    if rising_edge(clk_50mhz) then
      fir_sample_pulse <= '0';   -- one-clock pulse default
      if rst = '1' then
        fir_coeff_0     <= (others => '0');
        fir_coeff_1     <= (others => '0');
        fir_coeff_2     <= (others => '0');
        fir_coeff_3     <= (others => '0');
        fir_sample_data <= (others => '0');
      elsif mmio_we = '1' then
        case mmio_word is
          when "010100" =>                                               -- 0x50 coeffs 0,1
            fir_coeff_0 <= cpu_dmem_wdata(8 downto 0);
            fir_coeff_1 <= cpu_dmem_wdata(24 downto 16);
          when "010101" =>                                               -- 0x54 coeffs 2,3
            fir_coeff_2 <= cpu_dmem_wdata(8 downto 0);
            fir_coeff_3 <= cpu_dmem_wdata(24 downto 16);
          when "010110" =>                                               -- 0x58 sample
            fir_sample_data  <= cpu_dmem_wdata(15 downto 0);
            fir_sample_pulse <= '1';
          when others => null;
        end case;
      end if;
    end if;
  end process;

  -- FIR result latch: capture each result_valid pulse so the CPU
  -- can poll FIR_STATUS without missing edges. ready stays high
  -- until the CPU reads FIR_RESULT (which drains the latch).
  fir_latch : process (clk_50mhz) is
    variable read_result : boolean;
  begin
    if rising_edge(clk_50mhz) then
      read_result := (cpu_dmem_re = '1' and is_mmio = '1' and mmio_word = "010111");
      if rst = '1' then
        fir_result_latch <= (others => '0');
        fir_ready_latch  <= '0';
      elsif fir_result_valid = '1' then
        fir_result_latch <= fir_result;
        fir_ready_latch  <= '1';
      elsif read_result then
        fir_ready_latch  <= '0';
      end if;
    end if;
  end process;

  -- ---------------------------------------------------------------
  -- Read mux: which peripheral answers the CPU's load?
  -- ---------------------------------------------------------------
  cpu_dmem_rdata <=
       (0  => uart_tx_busy, others => '0')
              when (is_mmio = '1' and mmio_word = "000000")              -- 0x00 UART_TX
  else (31 => rx_ready_latch,
        7 downto 0 => rx_byte_latch, others => '0')
              when (is_mmio = '1' and mmio_word = "000001")              -- 0x04 UART_RX
  else simd_result
              when (is_mmio = '1' and mmio_word = "001111")              -- 0x3C SIMD_RESULT
  else std_logic_vector(resize(unsigned(simd_flags), 32))
              when (is_mmio = '1' and mmio_word = "010000")              -- 0x40 SIMD_FLAGS
  else std_logic_vector(resize(signed(fir_result_latch), 32))
              when (is_mmio = '1' and mmio_word = "010111")              -- 0x5C FIR_RESULT
  else (0 => fir_ready_latch, others => '0')
              when (is_mmio = '1' and mmio_word = "011000")              -- 0x60 FIR_STATUS
  else dmem_rdata;

end architecture rtl;
