-- shift_register.vhd
--
-- Parameterised shift register with synchronous load. When `load = '1'`
-- the register captures `load_data`; otherwise on every rising clock
-- edge it shifts toward the MSB and admits `serial_in` at the LSB.
--
-- One of the workhorses of digital design — the same block backs LFSRs,
-- delay lines, parallel-in-serial-out converters and many test pattern
-- generators.

library ieee;
use ieee.std_logic_1164.all;

entity shift_register is
  generic (
    WIDTH : integer := 8
  );
  port (
    clk         : in  std_logic;
    load        : in  std_logic;
    load_data   : in  std_logic_vector(WIDTH-1 downto 0);
    serial_in   : in  std_logic;
    parallel_out: out std_logic_vector(WIDTH-1 downto 0);
    serial_out  : out std_logic
  );
end entity shift_register;

architecture rtl of shift_register is
  signal sreg : std_logic_vector(WIDTH-1 downto 0) := (others => '0');
begin
  process (clk)
  begin
    if rising_edge(clk) then
      if load = '1' then
        sreg <= load_data;
      else
        sreg <= sreg(WIDTH-2 downto 0) & serial_in;
      end if;
    end if;
  end process;

  parallel_out <= sreg;
  serial_out   <= sreg(WIDTH-1);
end architecture rtl;
