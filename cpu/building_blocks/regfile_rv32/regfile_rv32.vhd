-- regfile_rv32.vhd
--
-- RV32I register file: 32 architectural registers x0..x31, each 32
-- bits wide. Two combinational read ports (`rdata1`, `rdata2`) feed
-- the ALU operands; one synchronous write port (`we`, `waddr`,
-- `wdata`) is driven by the writeback stage.
--
-- The two RISC-V quirks:
--
--   1. x0 is hardwired to zero. Reads from address 0 always return
--      0x00000000; writes to address 0 are silently dropped. The
--      assembler relies on this to encode `nop`, `mv`, `not`, etc.
--
--   2. WRITE_FALLING_EDGE defaults to true for the pipelined CPU:
--      WB writes before the next rising-edge ID capture. Single-cycle
--      CPUs select false so PC, regfile, and memory side effects
--      commit on the same rising edge, using the old source values.
--      Combinational reads return stored data with no write bypass.

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity regfile_rv32 is
  generic (WRITE_FALLING_EDGE : boolean := true);
  port (
    clk    : in  std_logic;
    we     : in  std_logic;
    waddr  : in  std_logic_vector(4 downto 0);
    wdata  : in  std_logic_vector(31 downto 0);
    raddr1 : in  std_logic_vector(4 downto 0);
    rdata1 : out std_logic_vector(31 downto 0);
    raddr2 : in  std_logic_vector(4 downto 0);
    rdata2 : out std_logic_vector(31 downto 0)
  );
end entity regfile_rv32;

architecture rtl of regfile_rv32 is
  type regs_t is array (0 to 31) of std_logic_vector(31 downto 0);
  signal regs : regs_t := (others => (others => '0'));
begin

  falling_write : if WRITE_FALLING_EDGE generate
    process (clk) is
    begin
      if falling_edge(clk) then
        if we = '1' and unsigned(waddr) /= 0 then
          regs(to_integer(unsigned(waddr))) <= wdata;
        end if;
      end if;
    end process;
  end generate;
  rising_write : if not WRITE_FALLING_EDGE generate
    process (clk) is
    begin
      if rising_edge(clk) then
        if we = '1' and unsigned(waddr) /= 0 then
          regs(to_integer(unsigned(waddr))) <= wdata;
        end if;
      end if;
    end process;
  end generate;

  -- Combinational reads. x0 always reads as 0. No bypass mux: a
  -- source retains its old value until the selected write edge.
  rdata1 <= (others => '0') when unsigned(raddr1) = 0
       else regs(to_integer(unsigned(raddr1)));

  rdata2 <= (others => '0') when unsigned(raddr2) = 0
       else regs(to_integer(unsigned(raddr2)));

end architecture rtl;
