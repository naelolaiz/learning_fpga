-- riscv_soc.vhd
--
-- Small SoC built around the single-cycle RV32I core: CPU + 4 KB
-- DMEM + memory-mapped UART (TX + RX). The IMEM is internal to the
-- CPU (pre-loaded from a hex file via IMEM_INIT). The DMEM and the
-- MMIO peripherals live here in the SoC top and share the CPU's
-- DMEM bus through a simple address decoder.
--
-- Address map (32-bit byte addresses)
-- ----------------------------------
--   0x0000_0000 .. 0x0000_0FFF   IMEM (internal to CPU, 4 KB,
--                                init from IMEM_INIT hex file)
--   0x0001_0000 .. 0x0001_0FFF   DMEM (4 KB, R/W; in this SoC,
--                                the address decoder uses bit 31
--                                only — so any non-MMIO address
--                                actually maps modulo 4 KB into
--                                DMEM. The plan's higher base
--                                address is honoured by the
--                                linker / assembler — programs
--                                that write to 0x0001_xxxx land
--                                in the same DMEM. For a tutorial
--                                CPU this is fine; a real SoC
--                                would decode finer.)
--
--   0x8000_0000                   UART_TX_DATA (W: send byte;
--                                R: bit 0 = tx_busy)
--   0x8000_0004                   UART_RX_DATA (R: bits[7:0] =
--                                received byte, bit 31 = rx_ready;
--                                reading drains the latch)
--
-- The decoder is just one bit (`dmem_addr[31]`): high = MMIO,
-- low = DMEM. Inside MMIO, `dmem_addr[2]` picks between TX (0)
-- and RX (4). Crude but sufficient for the tutorial peripheral set.

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

  -- Address decode
  signal is_mmio   : std_logic;
  signal dmem_we_q : std_logic;
  signal mmio_we   : std_logic;

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
  is_mmio   <= cpu_dmem_addr(31);
  dmem_we_q <= cpu_dmem_we and not is_mmio;
  mmio_we   <= cpu_dmem_we and is_mmio;

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
  -- UART TX peripheral: write to 0x8000_0000 sends the LSB byte
  -- ---------------------------------------------------------------
  process (clk_50mhz) is
  begin
    if rising_edge(clk_50mhz) then
      uart_tx_start <= '0';        -- default; one-clock pulse
      if rst = '1' then
        uart_tx_data <= (others => '0');
      elsif mmio_we = '1' and cpu_dmem_addr(2) = '0' and uart_tx_busy = '0' then
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
                                              and cpu_dmem_addr(2) = '1'
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
  -- Read mux: which side of the bus answers the CPU's load?
  -- ---------------------------------------------------------------
  cpu_dmem_rdata <=
       (0  => uart_tx_busy, others => '0')
              when (is_mmio = '1' and cpu_dmem_addr(2) = '0')
  else (31 => rx_ready_latch,
        7 downto 0 => rx_byte_latch, others => '0')
              when (is_mmio = '1' and cpu_dmem_addr(2) = '1')
  else dmem_rdata;

end architecture rtl;
