-- uart_tx.vhd
--
-- Minimal 8N1 UART transmitter. Holds the line high (idle), drops it
-- low for one bit-time as the start bit, shifts out 8 data bits LSB
-- first, then drives one stop bit. Asserting `tx_start` while `tx_busy`
-- is low latches `tx_data` and begins the frame.
--
-- The bit time comes from CLKS_PER_BIT — at a 50 MHz clock and a
-- 115 200-baud target, that's 50_000_000 / 115_200 = 434 (round to
-- nearest). The default below picks 50 MHz / 9600 = 5208 because it's
-- the friendliest for first-time inspection of the simulated waveform.

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity uart_tx is
  generic (
    CLKS_PER_BIT : integer := 5208
  );
  port (
    clk      : in  std_logic;
    tx_start : in  std_logic;
    tx_data  : in  std_logic_vector(7 downto 0);
    tx       : out std_logic;
    tx_busy  : out std_logic
  );
end entity uart_tx;

architecture rtl of uart_tx is
  type state_t is (S_IDLE, S_START, S_DATA, S_STOP);
  signal state     : state_t                       := S_IDLE;
  signal tick      : integer range 0 to CLKS_PER_BIT-1 := 0;
  signal bit_idx   : integer range 0 to 7          := 0;
  signal shifter   : std_logic_vector(7 downto 0)  := (others => '0');
  signal tx_reg    : std_logic                     := '1';
begin

  process (clk)
  begin
    if rising_edge(clk) then
      case state is
        when S_IDLE =>
          tx_reg <= '1';
          tick   <= 0;
          if tx_start = '1' then
            shifter <= tx_data;
            state   <= S_START;
          end if;

        when S_START =>
          tx_reg <= '0';
          if tick = CLKS_PER_BIT-1 then
            tick    <= 0;
            bit_idx <= 0;
            state   <= S_DATA;
          else
            tick <= tick + 1;
          end if;

        when S_DATA =>
          tx_reg <= shifter(0);
          if tick = CLKS_PER_BIT-1 then
            tick    <= 0;
            shifter <= '0' & shifter(7 downto 1);
            if bit_idx = 7 then
              state <= S_STOP;
            else
              bit_idx <= bit_idx + 1;
            end if;
          else
            tick <= tick + 1;
          end if;

        when S_STOP =>
          tx_reg <= '1';
          if tick = CLKS_PER_BIT-1 then
            tick  <= 0;
            state <= S_IDLE;
          else
            tick <= tick + 1;
          end if;
      end case;
    end if;
  end process;

  tx      <= tx_reg;
  tx_busy <= '0' when state = S_IDLE else '1';

end architecture rtl;
