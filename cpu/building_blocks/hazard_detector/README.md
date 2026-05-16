Hazard controller for the 5-stage RV32I pipeline.

Pure-combinational decision unit that handles the two structural
problems forwarding alone can't fix. Used by
[`cpu/riscv_pipelined`](../../riscv_pipelined/).

### Hazards covered

| Output | Trigger | Pipeline response |
|---|---|---|
| `stall` | Load-use RAW: instruction in EX is a load, AND its `rd` matches either source register of the instruction in ID. | Freeze PC + IF/ID, insert a NOP into ID/EX. One-cycle bubble. The next cycle, forwarding handles the now-resolved RAW. |
| `flush` | Branch resolves taken in EX. | Replace IF and ID with NOPs on the next cycle. Two instructions wasted per taken branch — the cost of resolving in EX. |

### Edge cases the unit handles correctly

- **`rd = x0`** never triggers a load-use stall, because writes to
  x0 are dropped at the regfile and the consumer reading x0 always
  gets zero regardless of forwarding.
- **ALU `rd` match without `mem_read`** does not stall — forwarding
  alone covers it.
- **Load-use AND taken-branch in the same cycle** asserts both
  outputs. The pipeline's normal behaviour ("flush wins" — the
  stalled-then-bubbled instruction would have been flushed anyway)
  produces the right result without any further logic in this
  unit.

### Test coverage

`tb_hazard_detector` exercises seven cases: `no-hazard`,
`load-use-rs1`, `load-use-rs2`, `alu-rd-match-noload`,
`load-into-x0`, `branch-taken`, `load-use-and-branch`.
