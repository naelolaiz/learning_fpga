# regfile_rv32 — RV32I register file

The 32-register integer file mandated by the RV32I base ISA: registers
`x0..x31`, each 32 bits wide, two combinational read ports feeding the
ALU operands, one synchronous write port driven by the writeback
stage. Used by both the upcoming single-cycle and pipelined CPUs.

| File | Purpose |
| ---- | ------- |
| [`regfile_rv32.vhd`](regfile_rv32.vhd) | VHDL design |
| [`regfile_rv32.v`](regfile_rv32.v) | Verilog mirror |
| [`test/tb_regfile_rv32.vhd`](test/tb_regfile_rv32.vhd), [`test/tb_regfile_rv32.v`](test/tb_regfile_rv32.v) | Self-checking testbenches |

## Ports

| Direction | Name | Width | Purpose |
| --------- | ---- | ----- | ------- |
| in  | `clk`    | 1  | Rising-edge write clock |
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

**Falling-edge writes, no combinational bypass.** Writes happen on
the **falling edge** of `clk`. Reads are combinational and return
the **stored** value — there's no write-then-read bypass mux on the
read port. Two consequences worth knowing:

- A combinational ALU that reads register `R` and writes register
  `R` in the same cycle (e.g. `addi t0, t0, 2`) does NOT close a
  combinational loop. A bypass mux on `rdata` would have:
  `rdata1 → ALU → wdata → rdata1 (when raddr1 = waddr ∧ we=1)`
  — an infinite delta-cycle loop. The textbook single-cycle
  organisation avoids this by writing on the falling edge: within
  the same cycle the read returns the OLD stored value, and the
  new value commits at the falling edge so the *next* rising edge
  sees it.
- The same trick scales to the pipelined CPU: the forwarding unit
  handles the tighter EX→EX and MEM→EX hazards, and WB→ID falls
  out for free from the falling-edge write timing (the new value
  is already in storage by the time the next instruction's ID
  stage reads it).

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

The testbench re-aligns to a falling clock edge between phases —
the 32 iterations of `wait for 1 ns` in the read-everything loop
leave the simulation mid-cycle, and re-aligning before each write
makes the falling-edge write timing unambiguous in the assertion
that follows.
