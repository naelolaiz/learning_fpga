Forwarding unit for the 5-stage RV32I pipeline.

A pure-combinational decision block that watches what's about to
commit in MEM and WB and decides whether the ALU operand in EX
should come from the regfile or be intercepted from a later-stage
result. Used by [`cpu/riscv_pipelined`](../../riscv_pipelined/) to
resolve RAW data hazards without inserting bubbles.

### Forwarding sources, in priority order

| `fwd_a` / `fwd_b` | Meaning |
|---|---|
| `"10"` | Forward from MEM stage (one instruction ahead of EX) |
| `"01"` | Forward from WB  stage (two instructions ahead of EX) |
| `"00"` | No forward — use the regfile's read port value |

MEM wins over WB when both target the same destination register,
because MEM is the more recently computed value.

### The x0 invariant

x0 is hardwired to zero in RV32I: writes to it are dropped at the
regfile. The forwarding unit must preserve that invariant — a
reader of x0 must always see zero, never a junk value from some
later instruction that happened to land in MEM or WB with rd=x0.
The `_rd /= "00000"` guards in the source enforce this.

### Test coverage

`tb_forwarding_unit` exercises seven cases, named in the report
output:

1. `no-hazard` — neither MEM nor WB matches; both fwds = `"00"`.
2. `mem-to-a` — MEM matches `ex_rs1`; `fwd_a = "10"`.
3. `wb-to-b` — WB matches `ex_rs2`; `fwd_b = "01"`.
4. `mem-wins-over-wb` — both stages target the same reg; MEM wins.
5. `x0-never-forwards` — every input set to x0; both fwds stay `"00"`.
6. `we-low-blocks` — write-enable low blocks forwarding even when
   `rd` matches.
7. `mem-a-wb-b` — different stages forward to different operands
   simultaneously.
