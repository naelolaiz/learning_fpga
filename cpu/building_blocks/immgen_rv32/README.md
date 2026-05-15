# immgen_rv32 — RV32I immediate generator

Combinational. Takes the raw 32-bit instruction word plus a 3-bit
format selector and produces the sign-extended 32-bit immediate that
flows into the ALU's B input (or the PC adder, for branches and
jumps). One of the five small "fan-in" building blocks the
single-cycle and pipelined CPUs compose.

| File | Purpose |
| ---- | ------- |
| [`immgen_rv32.vhd`](immgen_rv32.vhd) | VHDL design |
| [`immgen_rv32.v`](immgen_rv32.v) | Verilog mirror |
| [`test/tb_immgen_rv32.vhd`](test/tb_immgen_rv32.vhd), [`test/tb_immgen_rv32.v`](test/tb_immgen_rv32.v) | Golden-vector testbenches |

## Why this exists as its own entity

The RV32I encoding deliberately scatters each immediate's bits
across the instruction word so that any given wire on the chip
always carries the same bit position of the immediate, no matter
which format is being decoded. (Patterson & Hennessy walk through
the encoding choice in the "designing a regular fetch path"
chapter.) Pulling that scatter-gather into a dedicated entity keeps
the decoder small and lets the immediate generator be tested in
isolation against the assembler's idea of "what immediate should
this instruction produce."

## Format codes

| `fmt` | Format | Used by | Width | Notes |
| ----- | ------ | ------- | ----- | ----- |
| `000` | I      | LW, ADDI, ANDI, …, JALR        | 12 | sign-extended |
| `001` | S      | SW                              | 12 | sign-extended, split across `instr[31:25]` + `instr[11:7]` |
| `010` | B      | BEQ, BNE, BLT, BGE, BLTU, BGEU  | 13 | sign-extended, LSB always 0 |
| `011` | U      | LUI, AUIPC                       | 20 | placed at `imm[31:12]`, no sign-extension |
| `100` | J      | JAL                              | 21 | sign-extended, LSB always 0 |
| else  | (illegal)                        |    | output is zero |

## Bit-extraction tables

These are exactly the bit shuffles in the design file — included
here as a side-by-side reference for anyone reading the source. The
column headers are the immediate's bit positions; the cell is the
instruction bit that drives it.

```
            imm bit  31..20      19..12      11        10..5         4..1         0
I-type      :        sgnext(instr[31])       instr[20]   instr[24:25]   instr[24:21]   instr[20]
                                                 ← instr[31:20] = 12 bits ↑
S-type      :        sgnext(instr[31])       instr[7]   instr[30:25]   instr[11:8]   instr[7]
                                                 ← instr[31:25] + instr[11:7] = 12 bits ↑
B-type      :        sgnext(instr[31])       instr[7]   instr[30:25]   instr[11:8]    0
                                                 ← 13 bits, LSB hardwired ↑
U-type      :        instr[31:12]            0          0              0              0
J-type      :        sgnext + instr[31]      instr[19:12] instr[20] instr[30:21]      0
```

(See `immgen_rv32.vhd` for the canonical concatenations.)

## Test strategy

Each testbench drives the DUT with **real instruction encodings**
the assembler would emit, and asserts the immediate matches what the
assembler would have computed. The same RV32I instructions chosen
both for the positive end and the most-negative end of every signed
format, plus one illegal-format scenario:

```
  ADDI x1, x0, -1        I  → 0xFFFFFFFF   all-ones sign extension
  ADDI x1, x0, +0x7FF    I  → 0x000007FF   largest positive 12-bit
  ADDI x1, x0, -0x800    I  → 0xFFFFF800   most negative 12-bit
  SW   x5, 16(x3)        S  → 0x00000010   positive split immediate
  SW   x5, -1(x3)        S  → 0xFFFFFFFF   all-ones sign extension
  BEQ  x1, x2, +12       B  → 0x0000000C   LSB=0 enforcement
  BEQ  x1, x2, -4        B  → 0xFFFFFFFC   negative
  LUI  x4, 0x12345       U  → 0x12345000   no sign-extension
  LUI  x4, 0xFFFFF       U  → 0xFFFFF000   MSB set, still no sign-extension
  JAL  x1, +8            J  → 0x00000008   positive
  JAL  x1, -8            J  → 0xFFFFFFF8   negative
  fmt = 111  (illegal)      → 0x00000000   fallthrough
```

If a regression breaks the bit-scatter for one format, the failing
line names the instruction so the cause is obvious.

## A practical Makefile note

The synthesised mux tree for immgen is wide and shallow, but
netlistsvg's recursive `gather` blows the default ~1 MB Node stack
rendering it (`RangeError: Maximum call stack size exceeded`). The
Makefile bumps the V8 stack via `node --stack-size=8000` when
invoking netlistsvg — synthesis itself is unaffected, the diagram
just needs more headroom.
