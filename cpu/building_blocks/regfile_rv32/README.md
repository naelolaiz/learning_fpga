# regfile_rv32 — RV32I register file

The 32-register integer file mandated by the RV32I base ISA: registers
`x0..x31`, each 32 bits wide, two combinational read ports feeding the
ALU operands, one synchronous write port driven by the writeback
stage. Used by both the single-cycle and pipelined CPUs.

| File | Purpose |
| ---- | ------- |
| [`regfile_rv32.vhd`](regfile_rv32.vhd) | VHDL design |
| [`regfile_rv32.v`](regfile_rv32.v) | Verilog mirror |
| [`test/tb_regfile_rv32.vhd`](test/tb_regfile_rv32.vhd), [`test/tb_regfile_rv32.v`](test/tb_regfile_rv32.v) | Self-checking testbenches |

## Ports

| Direction | Name | Width | Purpose |
| --------- | ---- | ----- | ------- |
| in  | `clk`    | 1  | Write clock; edge selected by `WRITE_FALLING_EDGE` |
| in  | `we`     | 1  | Write-enable |
| in  | `waddr`  | 5  | Write address (`x0..x31`) |
| in  | `wdata`  | 32 | Write data |
| in  | `raddr1` | 5  | Read-port 1 address |
| out | `rdata1` | 32 | Read-port 1 data (combinational) |
| in  | `raddr2` | 5  | Read-port 2 address |
| out | `rdata2` | 32 | Read-port 2 data (combinational) |

## Two RV32I-specific quirks live here

**`x0` is hardwired to zero.** Reads from address 0 always return
`0x00000000`; writes to address 0 are silently dropped. The RISC-V
assembler relies on this to encode `nop` (`addi x0,x0,0`), `mv`
(`addi rd,rs,0`), `not` (`xori rd,rs,-1`), and a handful of other
synthetic instructions.

**Selectable write edge, no combinational bypass.**
`WRITE_FALLING_EDGE` defaults to `true` in VHDL / `1` in Verilog.
Reads return stored data until the selected clock edge commits a
write. The single-cycle CPU overrides this generic/parameter to
`false` / `0`; the pipeline uses the default.

- In the single-cycle CPU, PC, registers, and memory all commit on
  the rising edge using old source values. `jalr t0,t0,0` must use
  the old `t0` as its destination before overwriting it with `PC+4`.
- In the pipeline, falling-edge writes let WB update storage before
  the next rising-edge ID capture. The forwarding unit handles
  EX→EX and MEM→EX dependencies.

A write bypass from `wdata` to a matching read port would form a
combinational loop in a flat single-cycle ALU (`rdata → ALU → wdata
→ rdata`). Returning stored data avoids that loop with either edge.

## Test strategy

[`tb_regfile_rv32.vhd`](test/tb_regfile_rv32.vhd) and its Verilog twin
walk four behaviours, each with its own assert message so a regression
points at the exact line:

1. **Initial state** — every register reads as zero on both ports.
2. **Write propagation** — write `0xDEADBEEF` to `x5`, read it back
   on both read ports the next cycle.
3. **`x0` invariance** — try writing `0xFFFFFFFF` to `x0`, then read
   `x0` and assert it's still zero.
4. **Same-cycle read of being-written register** — assert `we`
   writing `0x0000CAFE` to `x7` while the same cycle's `raddr1 = 7`.
   The read returns the **old** stored value (0) — there's no
   combinational bypass. After the falling edge commits the write,
   a follow-up read returns the new value (0xCAFE).

The block testbench exercises the default falling-edge mode. The
single-cycle and SoC integration tests exercise rising-edge mode,
including JALR with `rd=rs1` and dependent arithmetic/load results.

The block testbench re-aligns to a falling clock edge between phases —
the 32 iterations of `wait for 1 ns` in the read-everything loop
leave the simulation mid-cycle, and re-aligning before each write
makes the falling-edge write timing unambiguous in the assertion
that follows.
