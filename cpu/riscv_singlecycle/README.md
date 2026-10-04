# riscv_singlecycle — single-cycle RV32I CPU

The textbook flat-datapath organisation from Patterson & Hennessy,
composed structurally from the RV32 building blocks. One
instruction completes every clock; no FSM, no pipeline registers.
Runs the RV32I subset the assembler in
[`tools/rv32_asm`](../../tools/rv32_asm/) emits.

| File | Purpose |
| ---- | ------- |
| [`riscv_singlecycle.vhd`](riscv_singlecycle.vhd) | Top-level CPU |
| [`../building_blocks/regfile_rv32`](../building_blocks/regfile_rv32/), [`alu_rv32`](../building_blocks/alu_rv32/), [`immgen_rv32`](../building_blocks/immgen_rv32/), [`decoder_rv32`](../building_blocks/decoder_rv32/), [`../../building_blocks/ram_sync`](../../building_blocks/ram_sync/) | RV32 building blocks pulled in via the Makefile's `SRC_FILES` (no local copies — single source of truth) |
| [`test/tb_riscv_singlecycle_addi.vhd`](test/tb_riscv_singlecycle_addi.vhd) | Minimal ADDI sanity test |
| [`test/tb_riscv_singlecycle_loop.vhd`](test/tb_riscv_singlecycle_loop.vhd) | Counted decrement loop |
| [`test/tb_riscv_singlecycle_branches.vhd`](test/tb_riscv_singlecycle_branches.vhd) | Every conditional branch flavour |
| [`test/tb_riscv_singlecycle_jalr.vhd`](test/tb_riscv_singlecycle_jalr.vhd) | JALR overlapping operands, links, target masking, and memory commits |

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

The CPU instantiates four RV32 building blocks. The generic memory lesson
is a precursor rather than an instantiated component:

| Block | Role |
| ----- | ---- |
| `ram_sync` | separate synchronous-memory lesson; the CPU uses internal async-read IMEM/DMEM |
| `regfile_rv32` | 32 × 32 register file, x0=0, rising-edge writes (`WRITE_FALLING_EDGE=false`) |
| `alu_rv32` | 32-bit ALU |
| `immgen_rv32` | sign-extends one of five RISC-V immediate formats |
| `decoder_rv32` | produces every control signal the muxes need |

Two pieces are **not** generic building blocks because they're
CPU-specific: the **branch comparator** (six-way `funct3` →
taken/not-taken; kept separate from the ALU so the ALU is free to
compute branch targets or JALR sums) and the **next-PC selector**.

## Why the memories are internal and async

A *true* single-cycle CPU needs combinational instruction and data
memory: both the fetch (IMEM) and any load/store (DMEM) have to land
in the same clock as the rest of the pipeline. A
synchronous-read BRAM would delay IMEM read by one cycle and turn
the design into something closer to a 2-stage pipeline.

Async memories keep the cycle model simple, but can consume many logic
elements. Check fitted resource and timing reports for your board;
mapping to synchronous BRAM requires handling its read latency.
The [SoC variant](../riscv_soc/) replaces the internal
DMEM with a memory bus so MMIO peripherals can sit in the data
address space.

`IMEM_ADDR_W` and `DMEM_ADDR_W` size the internal arrays
(depth = 2^addr_w). `IMEM_INIT` is a hex file path consumed at
elaboration via VHDL `textio` — the same format
[`tools/rv32_asm`](../../tools/rv32_asm/) emits.

## One instruction, one commit edge

PC, register writes, and memory writes commit together on the rising
edge, using source values from before that edge. The register file has
combinational reads of stored data and no write bypass. For
`addi t0,t0,2`, the ALU computes from the old `t0`; the edge writes the
result and advances PC together.

This also matters for `jalr t0,t0,0`: the jump uses the old `t0`, while
the same edge writes `PC+4` to `t0`. Writing the link on an earlier
falling edge would change the jump target before PC captures it.
The shared register file retains falling-edge writes by default for
the pipelined CPU; this core selects `WRITE_FALLING_EDGE=false`.
While `rst` is high, PC is held at zero and register/memory writes are
disabled. Register and data-memory contents retain their values.

## Test strategy

Each testbench loads one of the [`tools/rv32_asm`
golden programs](../../tools/rv32_asm/programs/) into IMEM via the
`IMEM_INIT` generic, runs the CPU until the **HALT sentinel**
instruction (`jal x0, .` = `0x0000006F`, a self-loop) appears on the
debug-bus instruction port, then asserts the final architectural
state.

The testbench keeps a *shadow* register file mirroring every
`dbg_reg_we / dbg_reg_waddr / dbg_reg_wdata` commit. Sample it on the
**rising edge**, before VHDL signal updates or Verilog nonblocking
assignments take effect. At that instant the bus describes the
instruction committing. After the updates settle, PC and the bus
describe the next instruction. A falling-edge sample belongs to that
next instruction and cannot identify the previous commit.

The four programs:

| Program | What it exercises | Final state |
| ------- | ----------------- | ----------- |
| `prog_addi.S`     | ADDI + halt sentinel        | `t0 = 3` |
| `prog_loop.S`     | counted decrement with BNE, J | `t0 = 0`, `t1 = 5` |
| `prog_branches.S` | every conditional branch + counter | `s0 = 4` |
| `prog_jalr.S` | overlapping/distinct JALR operands, negative immediate, odd target masking, link values, store/load, skipped stores | `s0=4`, `s1=16`, `s2=44`, `s3=76`, `s4=42`, `s5=43`, `s6=0` |

A "halt-or-timeout" loop in each driver process bounds simulation
time: if PC doesn't reach the sentinel within `MAX_CYCLES` clocks
the test reports a timeout (so a regression in the next-PC logic
that locks PC at 0 fails fast instead of running forever).

## Out of scope (intentional)

This single-cycle CPU is the v1 — it implements the RV32I subset
exactly:

- LW / SW only (byte/half loads + stores deferred — no
  byte-addressable memory path yet)
- No exceptions, no CSRs, no interrupts (the decoder reports
  `illegal=1` but the CPU just ignores it)
- No M-extension (multiply/divide)
- Async, internal memories (the [SoC variant](../riscv_soc/) moves
  DMEM external for MMIO)

The [pipelined CPU](../riscv_pipelined/) swaps the same datapath
into a 5-stage IF/ID/EX/MEM/WB organisation with a forwarding unit
and load-use hazard detection.
