# rv32_asm — tiny Python assembler for the tutorial RV32I subset

A from-scratch assembler that turns the integer/branch/jump subset of
RV32I — exactly what the upcoming tutorial CPU implements — into hex
words ready for `$readmemh` (Verilog) or VHDL `textio` `hread`. Plain
Python 3, no dependencies.

This is **not** a full RV32I assembler: byte/half memory ops, FENCE,
ECALL/EBREAK and the CSR instructions are **deliberately omitted**
because the tutorial CPU doesn't decode them — see [Scope](#scope)
below. A program written for the full RV32I base ISA would not
necessarily assemble here.

| File | Purpose |
| ---- | ------- |
| [`rv32_asm.py`](rv32_asm.py) | The assembler |
| [`test/test_rv32_asm.py`](test/test_rv32_asm.py) | Unit tests + golden-file checks |
| [`programs/*.S`](programs/) | Source assembly for the tutorial programs |
| [`programs/*.hex`](programs/) | Committed golden hex output (one word per line) |
| [`Makefile`](Makefile) | `make test` + `make golden` |

## Why have a custom assembler at all

The RISC-V Foundation publishes a full GNU toolchain
(`riscv32-unknown-elf-gcc`/`as`/`ld`), and it produces bit-perfect
encodings of the entire ISA. For a tutorial that fits inside the
existing `hdltools` container, though, three things make a tiny
in-repo assembler the better default:

1. **Zero new dependencies.** The container already has Python 3.
   Adding `riscv32-unknown-elf-as` means rebuilding and republishing
   the container image.
2. **Readable, auditable.** ~400 lines of Python — a learner can
   open `rv32_asm.py`, trace any instruction encoding through
   `enc_r`/`enc_i`/`enc_s`/`enc_b`/`enc_u`/`enc_j`, and confirm the
   spec by inspection.
3. **Same `.hex` format.** The output is one 32-bit word per line in
   ASCII hex — the format accepted by both `$readmemh` and VHDL
   `textio` `hread`. A user who later adds the real GNU toolchain
   can produce the same `.hex` from `.elf` via
   `objcopy -O verilog --reverse-bytes=4` (or similar) and the CPU
   testbench doesn't notice.

## Scope

The assembler covers the integer ALU + branch + jump + word
load/store subset of RV32I. The tutorial CPU implements exactly the
same set, so the assembler-CPU pair stays consistent — every
mnemonic the assembler accepts, the CPU executes, and vice versa.

**Deliberately omitted from RV32I base** (with reasoning):

| Class | Mnemonics | Why omitted |
| ----- | --------- | ----------- |
| Byte/half loads/stores | `LB`, `LH`, `LBU`, `LHU`, `SB`, `SH`           | The tutorial CPU's memory path is word-only. Adding these to the assembler without the matching CPU+memory work would let users write programs that don't run. They re-enter scope as a Phase D follow-on. |
| Memory-ordering hints  | `FENCE`, `FENCE.I`                              | No reordering memory subsystem to fence. |
| Environment / debug    | `ECALL`, `EBREAK`                               | No exception handler in the tutorial CPU. |
| Control/status regs    | `CSRRW`, `CSRRS`, `CSRRC`, `CSRRWI`, `CSRRSI`, `CSRRCI` | No CSR file in the tutorial CPU; CSRs land alongside interrupts in a future phase. |
| M extension            | `MUL`, `MULH`, `MULHU`, `MULHSU`, `DIV`, `DIVU`, `REM`, `REMU` | Separate ISA extension; warrants its own example with the Cyclone IV's hard multipliers. |

## Supported instructions

The RV32I subset the upcoming CPU implements:

| Class      | Mnemonics                                                       |
| ---------- | --------------------------------------------------------------- |
| R-type ALU | `ADD SUB AND OR XOR SLL SRL SRA SLT SLTU`                       |
| I-type ALU | `ADDI ANDI ORI XORI SLLI SRLI SRAI SLTI SLTIU`                  |
| Loads      | `LW`                                                            |
| Stores     | `SW`                                                            |
| Branches   | `BEQ BNE BLT BGE BLTU BGEU`                                     |
| Jumps      | `JAL JALR`                                                      |
| Upper      | `LUI AUIPC`                                                     |

Plus a small set of pseudo-instructions:

| Pseudo                | Expands to                                                                            |
| --------------------- | ------------------------------------------------------------------------------------- |
| `NOP`                 | `ADDI x0, x0, 0`                                                                      |
| `MV rd, rs`           | `ADDI rd, rs, 0`                                                                      |
| `NOT rd, rs`          | `XORI rd, rs, -1`                                                                     |
| `NEG rd, rs`          | `SUB rd, x0, rs`                                                                      |
| `LI rd, imm`          | `ADDI rd, x0, imm` (12-bit signed only — use `LUI`+`ADDI` for wider immediates)       |
| `J label`             | `JAL x0, label`                                                                       |
| `JR rs`               | `JALR x0, rs, 0`                                                                      |
| `RET`                 | `JALR x0, x1, 0`                                                                      |
| `BEQZ rs, label`      | `BEQ rs, x0, label`                                                                   |
| `BNEZ rs, label`      | `BNE rs, x0, label`                                                                   |
| `HALT`                | `JAL x0, .` — self-loop sentinel for the CPU testbenches (PC stuck at the same addr) |

Register names accepted: `x0..x31` plus the standard ABI aliases
(`zero ra sp gp tp t0..t6 s0..s11 a0..a7 fp`).

Directives: `.word <n>` emits a raw 32-bit constant; `#` and `//`
start a line comment.

## Numeric formats

Decimal (`100`), hex (`0x1A2B`), binary (`0b1010`), all with an
optional leading `-`. Out-of-range immediates raise a clear error
naming the field width and the value seen, so a typo doesn't
silently truncate.

## Output format

```
00100293
00228293
0000006F
```

One 32-bit word per line, uppercase hex, no `0x`, no width markers.
The same file is accepted by both:

- Verilog: `$readmemh("prog_addi.hex", imem)` where `imem` is a
  `reg [31:0] imem [0:DEPTH-1]`.
- VHDL: `ram_sync` (sibling building block) loads this format via
  its `INIT_FILE` generic using `std.textio` `hread`.

## Test strategy

`make test` runs two layers:

1. **Per-instruction encoding** — `EncodingTests` in
   `test/test_rv32_asm.py` asserts the assembler's output for
   hand-encoded RV32I instructions matches the reference encodings
   used elsewhere in the repo (specifically the
   [decoder_rv32 testbench](../../cpu/building_blocks/decoder_rv32/test/));
   a regression here lines up with a regression there.

2. **Whole-program golden files** — `GoldenFileTests` re-assembles
   each `programs/*.S` and diffs the output against the committed
   `.hex` sibling. The committed `.hex` is the canonical answer the
   CPU testbenches will load; if the assembler changes in a way
   that shifts the bytes, this is where you notice.

To regenerate the golden files after an intentional assembler
change, run `make golden` and review the resulting diff before
committing.

## Optional: using the real GNU toolchain instead

Nothing in the CPU stack depends on `rv32_asm.py` specifically — it
just produces the same hex format an `objcopy -O verilog` pass would.
A user who wants to use the upstream toolchain can:

```
# In a container that has riscv32-unknown-elf-* installed:
riscv32-unknown-elf-as  -march=rv32i -o prog.o prog.S
riscv32-unknown-elf-ld  -Ttext=0x0   -o prog.elf prog.o
riscv32-unknown-elf-objcopy -O verilog --reverse-bytes=4 prog.elf prog.hex
```

The resulting `prog.hex` drops in for the CPU testbench identically.
