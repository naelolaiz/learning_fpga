-- uart_rx.vhd
--
-- 8N1 UART receiver, complementing comm/uart_tx. Holds the line in
-- expected-idle state and watches for a falling edge that marks a
-- start bit. From there, samples the eight data bits at their
-- centres and asserts `rx_valid` for one clock when the byte has
-- been captured (and the stop bit checked out).
--
-- Two robustness details worth knowing:
--
--   1. Two-stage synchroniser on `rx`. The line is asynchronous to
--      `clk` — without re-clocking it through two flip-flops first
--      we'd be sampling a metastable signal directly into the FSM,
--      and the synthesiser's hold-time on the start-bit edge would
--      occasionally land in the metastable window. The synchroniser
--      adds two clocks of latency, which at 50 MHz / 9600 baud is
--      ~0.04 % of a bit time — invisible in practice.
--
--   2. Three-tap majority sampler at each bit centre. We keep a
--      three-deep rolling window of the synchronised line, and at
--      the centre of each bit we take the majority of those three
--      samples. A single noise glitch ±1 clock from the centre
--      can't flip the captured bit. The vote is computed by `maj3`
--      below — three two-input ANDs OR-tied, the standard
--      majority-of-three circuit.
--
-- Bit time comes from the same CLKS_PER_BIT generic as uart_tx; the
-- default 5208 = 50 MHz / 9600 keeps both ends in sync for a
-- tutorial-paced waveform.
--
-- If the line isn't high at the middle of the stop-bit window
-- (framing error), the FSM returns to idle WITHOUT pulsing
-- `rx_valid` — the byte is silently dropped. A future revision
-- could add an explicit `framing_err` output if a particular
-- consumer cares.

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity uart_rx is
  generic (
    CLKS_PER_BIT : integer := 5208
  );
  port (
    clk      : in  std_logic;
    rx       : in  std_logic;
    rx_data  : out std_logic_vector(7 downto 0);
    rx_valid : out std_logic
  );
end entity uart_rx;

architecture rtl of uart_rx is
  -- Encoded state vector (same idiom as uart_tx) so GHDL and the
  -- Verilog twin produce the same waveform signal set.
  constant S_IDLE  : std_logic_vector(1 downto 0) := "00";
  constant S_START : std_logic_vector(1 downto 0) := "01";
  constant S_DATA  : std_logic_vector(1 downto 0) := "10";
  constant S_STOP  : std_logic_vector(1 downto 0) := "11";

  -- Two-stage synchroniser. Initialised to '1' (line-idle) so the
  -- FSM doesn't see a spurious start-bit edge during the first few
  -- cycles after reset.
  signal rx_sync1 : std_logic := '1';
  signal rx_sync2 : std_logic := '1';

  -- Three-deep rolling sample window of the *synchronised* line.
  -- Newest sample at bit 0, oldest at bit 2.
  signal samples  : std_logic_vector(2 downto 0) := "111";

  signal state    : std_logic_vector(1 downto 0) := S_IDLE;
  signal tick     : integer range 0 to CLKS_PER_BIT-1 := 0;
  signal bit_idx  : integer range 0 to 7            := 0;
  signal data_reg : std_logic_vector(7 downto 0)    := (others => '0');
  signal valid_r  : std_logic                       := '0';

  -- Majority of three bits — standard "two-of-three" decoder.
  function maj3 (v : std_logic_vector(2 downto 0)) return std_logic is
  begin
    return (v(0) and v(1)) or (v(0) and v(2)) or (v(1) and v(2));
  end function;
begin

  process (clk)
  begin
    if rising_edge(clk) then
      -- Always: clock the synchroniser and roll the sample window.
      rx_sync1 <= rx;
      rx_sync2 <= rx_sync1;
      samples  <= samples(1 downto 0) & rx_sync2;

      -- Default: rx_valid is a one-clock pulse, so de-assert it
      -- every cycle except when the FSM explicitly raises it below.
      valid_r <= '0';

      case state is
        when S_IDLE =>
          tick    <= 0;
          bit_idx <= 0;
          if rx_sync2 = '0' then
            state <= S_START;
          end if;

        when S_START =>
          -- Wait half a bit time, then confirm the line is still low
          -- using the majority vote. A glitch that briefly looked
          -- like a start bit but doesn't hold gets rejected here.
          if tick = (CLKS_PER_BIT/2) - 1 then
            tick <= 0;
            if maj3(samples) = '0' then
              state <= S_DATA;
            else
              state <= S_IDLE;
            end if;
          else
            tick <= tick + 1;
          end if;

        when S_DATA =>
          -- After half a bit + N full bits we're at the centre of
          -- data bit N. Take the majority vote there.
          if tick = CLKS_PER_BIT - 1 then
            tick                 <= 0;
            data_reg(bit_idx)    <= maj3(samples);
            if bit_idx = 7 then
              state <= S_STOP;
            else
              bit_idx <= bit_idx + 1;
            end if;
          else
            tick <= tick + 1;
          end if;

        when S_STOP =>
          if tick = CLKS_PER_BIT - 1 then
            tick  <= 0;
            -- Framing check: the stop bit must be high. If not,
            -- drop the byte silently.
            if maj3(samples) = '1' then
              valid_r <= '1';
            end if;
            state <= S_IDLE;
          else
            tick <= tick + 1;
          end if;

        when others =>
          state <= S_IDLE;
      end case;
    end if;
  end process;

  rx_data  <= data_reg;
  rx_valid <= valid_r;

end architecture rtl;
