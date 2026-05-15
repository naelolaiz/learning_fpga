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
--   2. Writes happen on the **falling edge** of the clock — the
--      textbook trick for single-cycle datapaths. A combinational
--      ALU that reads a register and writes back to the same
--      register in the same cycle (e.g. `addi t0, t0, 2`) would
--      otherwise need a write-then-read bypass mux on the read
--      port — and that mux closes a *combinational loop*
--      (rdata1 -> ALU -> wdata -> rdata1 when raddr1 = waddr and
--      we = 1). Falling-edge writes break the loop without needing
--      the mux: within the cycle, the read port returns the OLD
--      stored value; by the next rising edge the new value is
--      committed. Same trick scales to the pipelined CPU, where
--      the forwarding unit handles the tighter EX→EX and MEM→EX
--      hazards and WB→ID falls out for free from the falling-edge
--      write timing.

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity regfile_rv32 is
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

  -- Write on the FALLING clock edge — see the entity header.
  process (clk) is
  begin
    if falling_edge(clk) then
      if we = '1' and unsigned(waddr) /= 0 then
        regs(to_integer(unsigned(waddr))) <= wdata;
      end if;
    end if;
  end process;

  -- Combinational reads. x0 always reads as 0. No bypass mux: the
  -- falling-edge write keeps same-cycle reads "stale", which is
  -- exactly what the single-cycle datapath needs to avoid a
  -- combinational loop on rd-equals-rs1 instructions.
  rdata1 <= (others => '0') when unsigned(raddr1) = 0
       else regs(to_integer(unsigned(raddr1)));

  rdata2 <= (others => '0') when unsigned(raddr2) = 0
       else regs(to_integer(unsigned(raddr2)));

end architecture rtl;
