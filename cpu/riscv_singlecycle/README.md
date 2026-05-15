# riscv_singlecycle — single-cycle RV32I CPU

The textbook flat-datapath organisation from Patterson & Hennessy,
composed structurally from the Phase A building blocks. One
instruction completes every clock; no FSM, no pipeline registers.
The first integrated example in the
[plan](../../../.claude/plans/can-you-check-what-fuzzy-avalanche.md) — runs the
RV32I subset the assembler in [`tools/rv32_asm`](../../tools/rv32_asm/)
emits.

| File | Purpose |
| ---- | ------- |
| [`riscv_singlecycle.vhd`](riscv_singlecycle.vhd) | Top-level CPU |
| [`ram_sync.vhd`](ram_sync.vhd), [`regfile_rv32.vhd`](regfile_rv32.vhd), [`alu_rv32.vhd`](alu_rv32.vhd), [`immgen_rv32.vhd`](immgen_rv32.vhd), [`decoder_rv32.vhd`](decoder_rv32.vhd) | Local copies of the Phase A building blocks (one copy per project, matching `comm/uda1380`'s convention) |
| [`test/tb_riscv_singlecycle_addi.vhd`](test/tb_riscv_singlecycle_addi.vhd) | Minimal ADDI sanity test |
| [`test/tb_riscv_singlecycle_loop.vhd`](test/tb_riscv_singlecycle_loop.vhd) | Counted decrement loop |
| [`test/tb_riscv_singlecycle_branches.vhd`](test/tb_riscv_singlecycle_branches.vhd) | Every conditional branch flavour |

## Datapath

```
   IF :  PC drives IMEM            → imem_rdata = instr at PC
   ID :  decoder + immgen + regfile read on instr's rs1/rs2 fields
   EX :  ALU(alu_a, alu_b)
           alu_a = alu_src_a ? PC : rs1
           alu_b = alu_src_b ? imm : rs2
         branch_taken = branch_cmp(funct3, rs1, rs2)
   MEM:  if mem_read  : dmem[alu_result] → dmem_rdata
         if mem_write : dmem[alu_result] ← rs2
   WB :  rd ← {alu_result | dmem_rdata | PC+4 | imm}
                 gated by reg_write

   next_PC = JALR                 ? (alu_result with bit 0 cleared)
           : (JAL or taken branch) ? (PC + imm)
           : PC + 4
```

The five Phase A blocks compose like this in the source:

| Block | Role |
| ----- | ---- |
| `ram_sync` | (Phase A1) — used as the IMEM template; the CPU has its own internal IMEM/DMEM |
| `regfile_rv32` | (Phase A2) — 32 × 32 register file, x0=0, falling-edge writes |
| `alu_rv32` | (Phase A3) — 32-bit ALU |
| `immgen_rv32` | (Phase A4) — sign-extends one of five RISC-V immediate formats |
| `decoder_rv32` | (Phase A5) — produces every control signal the muxes need |

Two pieces are **not** Phase A blocks because they're CPU-specific: the
**branch comparator** (six-way `funct3` → taken/not-taken; kept
separate from the ALU so the ALU is free to compute branch targets
or JALR sums) and the **next-PC selector**.

## Why the memories are internal and async

A *true* single-cycle CPU needs combinational instruction and data
memory: both the fetch (IMEM) and any load/store (DMEM) have to land
in the same clock as the rest of the pipeline. A
synchronous-read BRAM would delay IMEM read by one cycle and turn
the design into something closer to a 2-stage pipeline.

For tutorial-sized programs (a few hundred instructions, a few hundred
words of data), the LE cost of async memories is negligible on the
Cyclone IV. The SoC build (Phase D) replaces the internal DMEM with
a memory bus so MMIO peripherals can sit in the data address space.

`IMEM_ADDR_W` and `DMEM_ADDR_W` size the internal arrays
(depth = 2^addr_w). `IMEM_INIT` is a hex file path consumed at
elaboration via VHDL `textio` — the same format
[`tools/rv32_asm`](../../tools/rv32_asm/) emits.

## Why the regfile writes on the falling edge

Reading a register and writing the same register in the same cycle —
e.g. `addi t0, t0, 2` — would close a combinational loop with a
write-then-read bypass mux:
`rdata1 → ALU → wdata → rdata1 (when raddr1 = waddr ∧ we = 1)`. The
falling-edge write breaks the loop without needing the bypass: within
the same cycle the read returns the OLD stored value, the new value
commits at the falling edge, the next rising edge sees the update.
This is the textbook single-cycle organisation; the same trick scales
to the pipelined CPU where the forwarding unit handles the tighter
EX→EX and MEM→EX hazards.

## Test strategy

Each testbench loads one of the [`tools/rv32_asm`
golden programs](../../tools/rv32_asm/programs/) into IMEM via the
`IMEM_INIT` generic, runs the CPU until the **HALT sentinel**
instruction (`jal x0, .` = `0x0000006F`, a self-loop) appears on the
debug-bus instruction port, then asserts the final architectural
state.

A subtle testbench gotcha worth flagging (caught during
verification): the testbench keeps a *shadow* register file
mirroring every `dbg_reg_we / dbg_reg_waddr / dbg_reg_wdata` commit.
The shadow MUST sample on the **falling edge** — same edge the CPU's
regfile commits on. Sampling on the rising edge would catch
`dbg_reg_wdata` *after* the regfile already updated, when the
combinational chain has re-evaluated with the new register state and
the writeback bus carries a stale "what-if" value (e.g.
`addi t0, t0, 2` writes 3 at the falling edge, then the
combinational chain recomputes with the new t0=3 and shows
wb_data=5 — that's *not* what hit storage). The CPU itself is
correct either way; only the observation is timing-sensitive.

The three programs:

| Program | What it exercises | Final state |
| ------- | ----------------- | ----------- |
| `prog_addi.S`     | ADDI + halt sentinel        | `t0 = 3` |
| `prog_loop.S`     | counted decrement with BNE, J | `t0 = 0`, `t1 = 5` |
| `prog_branches.S` | every conditional branch + counter | `s0 = 4` |

A "halt-or-timeout" loop in each driver process bounds simulation
time: if PC doesn't reach the sentinel within `MAX_CYCLES` clocks
the test reports a timeout (so a regression in the next-PC logic
that locks PC at 0 fails fast instead of running forever).

## Out of scope (intentional)

This single-cycle CPU is the v1 — it implements the Phase A subset
of RV32I exactly:

- LW / SW only (byte/half loads + stores deferred — no
  byte-addressable memory path yet)
- No exceptions, no CSRs, no interrupts (the decoder reports
  `illegal=1` but the CPU just ignores it)
- No M-extension (multiply/divide)
- Async, internal memories (the SoC build in Phase D moves DMEM
  external for MMIO)

The pipelined version in Phase E swaps the same datapath into a
5-stage IF/ID/EX/MEM/WB organisation with a forwarding unit and
load-use hazard detection.
