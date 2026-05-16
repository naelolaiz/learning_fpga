5-stage pipelined RV32I CPU.

The classic textbook IF / ID / EX / MEM / WB organisation, composed
from the same building blocks the single-cycle CPU uses
([`alu_rv32`](../building_blocks/alu_rv32/),
[`decoder_rv32`](../building_blocks/decoder_rv32/),
[`immgen_rv32`](../building_blocks/immgen_rv32/),
[`regfile_rv32`](../building_blocks/regfile_rv32/),
[`ram_sync`](../../building_blocks/ram_sync/))
plus two pipeline-specific helpers
([`forwarding_unit`](../building_blocks/forwarding_unit/),
[`hazard_detector`](../building_blocks/hazard_detector/)).

The pedagogical payoff: same hex programs as
[`cpu/riscv_singlecycle`](../riscv_singlecycle/) run unchanged on
this CPU. Reading the two side-by-side shows what changes when you
add pipeline registers, forwarding, and hazard handling — and what
doesn't.

### Pipeline shape

| Stage | What happens | Pipeline register at output |
|---|---|---|
| **IF**  | PC drives IMEM → `instr`. PC++ unless a branch from EX redirects it. | `IF/ID`  ← {pc, pc+4, instr} |
| **ID**  | Decoder + immgen + regfile read on `instr.rs1/rs2`. | `ID/EX`  ← {decoded ctrl, rs1/rs2 vals, imm, rd, …} |
| **EX**  | Forwarding muxes → ALU. Branch comparator decides taken/not-taken. | `EX/MEM` ← {alu_result, store data, rd, ctrl} |
| **MEM** | DMEM access (sync write, async read). | `MEM/WB` ← {alu_result, mem_data, rd, ctrl} |
| **WB**  | Writeback mux → regfile write port. | (commits to architectural state) |

### Hazard handling

Three things forwarding alone can't fix: the pipeline needs to
detect them and respond.

| Hazard | Detector | Response |
|---|---|---|
| **RAW (back-to-back)** | `forwarding_unit` sees MEM or WB about to write a register the EX instruction is reading | Forwarding mux picks EX/MEM or MEM/WB result instead of the stale regfile read. No bubble. |
| **Load-use RAW** | `hazard_detector` sees a load in EX whose `rd` matches the ID source registers | Freeze PC + IF/ID, insert NOP into ID/EX. One-cycle bubble; forwarding handles the RAW on the next cycle. |
| **Taken branch / jump** | `hazard_detector` sees `branch_taken` or `is_jal/is_jalr` in EX | Force IF/ID + ID/EX to NOP on next clock. Two-instruction penalty per redirect — the cost of resolving in EX. |

### Drop-in replacement for the single-cycle CPU

Same entity port shape (clk, rst, dbg_*). To swap the pipelined CPU
into the SoC, change one line in `cpu/riscv_soc/riscv_soc.vhd`:

```vhdl
cpu : entity work.riscv_pipelined  -- was: work.riscv_singlecycle
```

…and update `SRC_FILES` in `cpu/riscv_soc/Makefile` to point at this
file. Programs run identically; the only observable difference is
clock speed (higher, since the longest combinational path is shorter
now) or cycle count (fewer or more, depending on the program's
branch + load-use density).

### Memories

Same model as the single-cycle CPU: internal async-read IMEM
initialised from a hex file, internal sync-write/async-read DMEM.
The pipelined version still works with async-read memories (IF and
MEM are different stages, so reads and writes don't fight), but a
BRAM-friendly build would convert IMEM to sync-read which adds one
more cycle of fetch latency — orthogonal to pipelining itself, a
separate refactor.

### Tests

Three testbenches reuse the same hex programs from
[`tools/rv32_asm/programs/`](../../tools/rv32_asm/programs/) that
the single-cycle CPU runs:

- `tb_riscv_pipelined_addi` — basic R-type + I-type with back-to-back
  RAW (`addi t0,x0,1 ; addi t0,t0,2`) — exercises MEM→EX forwarding.
  Also enables `DEBUG_TRACE` on the DUT so the simulator emits the
  per-cycle pipeline trace (CI surfaces it in the run summary).
- `tb_riscv_pipelined_loop` — counted decrement loop with back-edge
  branch — every iteration is a taken-branch flush.
- `tb_riscv_pipelined_branches` — every conditional branch flavour
  (BEQ/BNE/BLT/BGE/BLTU/BGEU) with taken AND not-taken paths.
- `tb_riscv_pipelined_load_use` — back-to-back `lw`-then-use pairs
  that the `hazard_detector` resolves with a one-cycle stall before
  forwarding fills in the loaded value. The same source program runs
  unchanged on the single-cycle CPU (where no stall is needed) and
  reaches the same final architectural state.

All four pass the same final-state assertion style the single-cycle
TBs use. The shadow-regfile scheme (snoop the debug bus, mirror
commits, check at halt) is identical because both CPUs expose the
same debug bus — the testbenches port across CPU implementations
with just a `riscv_singlecycle` → `riscv_pipelined` rename.

### Debug bus

`dbg_*` reports the WB-stage commit — the instruction that **retired**
this cycle, post-pipeline. A reader sees exactly the side effects
the program has committed so far, no matter how many bubbles or
flushes happened earlier in the pipeline.

### Run

    make            # build, simulate, render waveform + netlist
    make simulate   # GHDL only
    make waveform   # FST → PNG
    make diagram    # synthesised netlist → SVG
