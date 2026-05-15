# decoder_rv32 — RV32I instruction decoder

Combinational. Takes the 32-bit fetched instruction and produces
every control signal the CPU top-level needs to wire its datapath:
register addresses, immediate-format selector, ALU op, source muxes,
memory & writeback gating, and branch/jump flags. The largest of the
"Phase A" building blocks, but still pure combinational — its body
is one big case-on-opcode with default-then-override.

| File | Purpose |
| ---- | ------- |
| [`decoder_rv32.vhd`](decoder_rv32.vhd) | VHDL design |
| [`decoder_rv32.v`](decoder_rv32.v) | Verilog mirror |
| [`test/tb_decoder_rv32.vhd`](test/tb_decoder_rv32.vhd), [`test/tb_decoder_rv32.v`](test/tb_decoder_rv32.v) | Golden-vector testbenches |

## Outputs

| Name | Width | Meaning |
| ---- | ----- | ------- |
| `rs1`, `rs2`, `rd` | 5 | Raw register-address fields extracted from `instr[19:15]`, `instr[24:20]`, `instr[11:7]` |
| `imm_fmt` | 3 | Immediate format selector (matches [`immgen_rv32`](../immgen_rv32/)) |
| `alu_op` | 4 | ALU operation (matches [`alu_rv32`](../alu_rv32/) `ALU_*` constants) |
| `alu_src_a` | 1 | ALU A-input mux: `0` = rs1, `1` = PC (for AUIPC) |
| `alu_src_b` | 1 | ALU B-input mux: `0` = rs2, `1` = imm |
| `mem_read`, `mem_write` | 1 ea. | Gate the data-memory port |
| `reg_write` | 1 | Gate the regfile write port |
| `wb_src` | 2 | Writeback source: `00` = ALU, `01` = MEM, `10` = PC+4, `11` = imm (LUI passthrough) |
| `is_branch` | 1 | Set for BEQ/BNE/BLT/BGE/BLTU/BGEU |
| `is_jal` | 1 | Set for JAL |
| `is_jalr` | 1 | Set for JALR |
| `illegal` | 1 | Opcode wasn't in the supported subset |

## Supported instructions

The standard RV32I integer subset:

- **R-type ALU**: ADD, SUB, AND, OR, XOR, SLL, SRL, SRA, SLT, SLTU
- **I-type ALU**: ADDI, ANDI, ORI, XORI, SLTI, SLTIU, SLLI, SRLI, SRAI
- **Loads/stores**: LW, SW (word-only; LB/LH/SB/SH report `illegal=1`)
- **Branches**: BEQ, BNE, BLT, BGE, BLTU, BGEU
- **Jumps**: JAL, JALR
- **Upper**: LUI, AUIPC

Everything else (FENCE, ECALL/EBREAK, CSR\*, the M/A/F/D extensions)
sets `illegal=1`. The CPU top-level decides what to do with that
(squash, trap, ignore) — the decoder only reports it.

## Three design notes worth knowing

**`rs1`/`rs2`/`rd` are raw field extractions.** The decoder doesn't
try to be smart about which fields are "really" registers for a
given opcode. For example, in `ADDI x3, x1, 100` the
`instr[24:20] = 4` bits are part of the 12-bit I-immediate, but the
decoder still emits `rs2 = 5'b00100`. The CPU top-level gates that
signal at the regfile-read or ALU-mux boundary using
`alu_src_b` / `is_branch` / `mem_write` etc. — the decoder doesn't
need to know.

**LUI bypasses the ALU.** Rather than playing tricks with `rs1=x0`
or expanding `alu_src_a` to three values, LUI uses `wb_src = "11"`
(imm-passthrough). The top-level's writeback mux selects the
immediate directly, and the ALU isn't consulted at all. This keeps
the decoder uniform and the LUI encoding clean.

**Funct3+funct7 fold cleanly.** For R-type ADD/SUB, the same
`funct3=000` distinguishes them via `instr[30]` (the only bit that
matters in `funct7`). Same for SRL/SRA at `funct3=101`. The
I-type ALU group reuses the same `funct3` map, with `instr[30]`
only consulted when `funct3=101` (SRLI vs SRAI) — all other
I-type ALU instructions ignore it (the assembler is supposed to
set it to 0 anyway). The decoder honours both cases without ever
inspecting more `funct7` bits than necessary.

## Test strategy

The testbench walks every supported instruction class through the
decoder using hand-encoded RV32I instructions (real encodings the
assembler would emit) and asserts the **full control vector**
matches the hand-computed golden value:

```
  R-type:   ADD/SUB/AND/SRA/SRL/SLT
  I-type:   ADDI, SRAI, SRLI
  LOAD:     LW (valid) + LB (illegal)
  STORE:    SW (valid) + SH (illegal)
  BRANCH:   BEQ, BLT
  JAL, JALR
  LUI, AUIPC
  Custom-0 opcode → illegal
```

In the VHDL flow, outputs are bundled into a `decoded_t` record so
each assertion compares one whole vector at once — a mismatch dumps
both the expected and actual records on adjacent lines, so the
failing field is the one that differs. Verilog uses a `task` with
per-field `$fatal` checks for the same effect.

## A practical Makefile note

Same Node-stack bump as [`immgen_rv32`](../immgen_rv32/): the
synthesised decoder is a wide shallow combinational tree that trips
netlistsvg's recursive `gather` on the default JS stack. The
Makefile invokes netlistsvg via `node --stack-size=8000` so the
diagram renders.
