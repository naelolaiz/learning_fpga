# alu_rv32 — RV32I integer ALU

A 32-bit ALU covering every integer operation the RV32I base ISA
needs: ten arithmetic / logic / shift / compare ops plus a `zero`
flag for branch resolution. Pure combinational. The upcoming
single-cycle CPU drives this directly between the regfile read ports
and the writeback mux; the pipelined CPU places it in the EX stage
and feeds it via the forwarding muxes.

| File | Purpose |
| ---- | ------- |
| [`alu_rv32.vhd`](alu_rv32.vhd) | VHDL design |
| [`alu_rv32.v`](alu_rv32.v) | Verilog mirror |
| [`test/tb_alu_rv32.vhd`](test/tb_alu_rv32.vhd), [`test/tb_alu_rv32.v`](test/tb_alu_rv32.v) | Self-checking testbenches |

## Op encoding

The 4-bit `op` input picks one of ten operations. The codes are
**internal** — the decoder maps RISC-V `funct3`/`funct7` bit fields
to these constants, so consumers reference them by name rather than
spreading 4-bit literals across the codebase:

| `op` | Mnemonic | Operation |
| ---- | -------- | --------- |
| `0000` | `ALU_ADD`  | `result = a + b` |
| `0001` | `ALU_SUB`  | `result = a - b` |
| `0010` | `ALU_AND`  | `result = a and b` |
| `0011` | `ALU_OR`   | `result = a or  b` |
| `0100` | `ALU_XOR`  | `result = a xor b` |
| `0101` | `ALU_SLL`  | `result = a sll b(4:0)` |
| `0110` | `ALU_SRL`  | `result = a srl b(4:0)` (logical, zero-fill) |
| `0111` | `ALU_SRA`  | `result = a sra b(4:0)` (arithmetic, sign-fill) |
| `1000` | `ALU_SLT`  | `result = (signed(a) < signed(b)) ? 1 : 0` |
| `1001` | `ALU_SLTU` | `result = (a < b) ? 1 : 0` (unsigned) |
| other  | (illegal)  | `result = 0` |

The `zero` flag mirrors `result == 0`. The branch unit consults it
directly for `BEQ`/`BNE`; for `BLT`/`BGE`/`BLTU`/`BGEU` the decoder
issues `SLT`/`SLTU` and reads `result(0)`.

## Design notes

**No `abs()`.** The repo's [toolchain-quirks
note](../../mk/) flags an `abs(to_integer(signed(...)))` interaction
that trips `yosys+ghdl-plugin`. We never use `abs()` here — `SRA`
shifts the operand as `signed`, `shift_right(signed(a), shamt)` does
the sign extension natively, and the result casts back to
`std_logic_vector`. Both flows synthesise without complaint.

**Symmetric VHDL/Verilog.** The two implementations match bit-for-bit
on the same vectors. The testbench's golden table covers boundary
cases known to bite hand-written ALUs:

- ADD wrap (`0xFFFFFFFF + 1 = 0`) — checks the carry isn't surfaced
  on the result bus and that the `zero` flag fires.
- SUB negative wrap (`0 - 1 = 0xFFFFFFFF`) — checks two's-complement.
- Shifts by 0 (identity) and by 31 (max).
- `SRL` by 31 of `0xFFFFFFFF` → `0x00000001` (logical, zero-fill).
- `SRA` by 31 of `0xFFFFFFFF` → `0xFFFFFFFF` (arithmetic, sign-fill).
- `SRA -8 by 1` → `-4` (proves sign extension on a normal-magnitude
  operand, not just the all-ones edge case).
- `SLT -1 < 1` → 1; `SLTU 1 < 0xFFFFFFFF` → 1 (signed-vs-unsigned
  split for a value that's negative as signed but huge as unsigned).
- An illegal `op` code falls through to `result = 0` and the `zero`
  flag fires — keeps the output deterministic if the decoder ever
  issues a bogus op without independently squashing the regfile write.

## A subtle gotcha caught in the testbench

The original `check` procedure declared its result-port parameter as
`signal r : inout std_logic_vector`. That added a **second driver** to
`sR` (the actual ALU output), and since the procedure never wrote to
it, the unwritten driver defaulted to `'U'`. `std_logic` resolution
between the ALU's real `'0'`/`'1'` driver and the procedure's `'U'`
driver produced `'U'` (rendered `'X'` in `to_hstring`) on every bit.
The fix was to declare `r` as `signal in` (read-only access, no
driver added) and switch the stimulus signals to `signal out`.

This is the kind of bug that *only* surfaces with multiple drivers
on a resolved type — Verilog's mirror testbench, which uses a `task`
with an `input` parameter, was unaffected. The procedure header in
the VHDL testbench now explains why each parameter has the mode it
does, so the next person editing this file doesn't re-introduce the
bug.
