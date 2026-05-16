#!/usr/bin/env python3
"""
rv32_asm.py — tiny RV32I assembler for the learning_fpga tutorial.

Accepts a small but useful subset of the RISC-V Unprivileged ISA:

  R-type ALU    ADD SUB AND OR XOR SLL SRL SRA SLT SLTU
  I-type ALU    ADDI ANDI ORI XORI SLLI SRLI SRAI SLTI SLTIU
  Loads/stores  LW SW
  Branches      BEQ BNE BLT BGE BLTU BGEU
  Jumps         JAL JALR
  Upper         LUI AUIPC

Plus pseudo-instructions:

  NOP                    -> ADDI x0, x0, 0
  MV rd, rs              -> ADDI rd, rs, 0
  NOT rd, rs             -> XORI rd, rs, -1
  NEG rd, rs             -> SUB  rd, x0, rs
  LI rd, imm             -> ADDI rd, x0, imm        (12-bit signed only)
  J  label               -> JAL  x0, label
  JR rs                  -> JALR x0, rs, 0
  RET                    -> JALR x0, x1, 0
  BEQZ rs, label         -> BEQ  rs, x0, label
  BNEZ rs, label         -> BNE  rs, x0, label
  HALT                   -> JAL  x0, .  (self-loop; sentinel for the
                            CPU testbenches — finishes a program by
                            staying put forever, so the TB can spot
                            it via PC stuck at the same address)

Directives:

  .word  N               emit a raw 32-bit word
  # ...                  comment to end of line
  // ...                 also accepted as comment
  label:                 declare a label at the current address

The output is a hex file accepted by both `$readmemh` (Verilog) and
VHDL `textio` `hread` (one 32-bit word per line, uppercase hex, no
prefix). Words are emitted in instruction order — line 0 holds the
word at address 0, line 1 the word at address 4, and so on.

Two-pass design:
  Pass 1: tokenise + build the symbol table (resolves labels to byte
          addresses).
  Pass 2: emit machine code, plugging in label-relative offsets
          where needed (branches, JAL).

Usage:
  rv32_asm.py [-o out.hex] input.S
"""

import argparse
import re
import sys
from dataclasses import dataclass
from pathlib import Path


# ABI register aliases.
REGS = {
    "zero": 0, "ra": 1, "sp": 2, "gp": 3, "tp": 4,
    "t0": 5, "t1": 6, "t2": 7,
    "s0": 8, "fp": 8, "s1": 9,
    "a0": 10, "a1": 11, "a2": 12, "a3": 13,
    "a4": 14, "a5": 15, "a6": 16, "a7": 17,
    "s2": 18, "s3": 19, "s4": 20, "s5": 21,
    "s6": 22, "s7": 23, "s8": 24, "s9": 25,
    "s10": 26, "s11": 27,
    "t3": 28, "t4": 29, "t5": 30, "t6": 31,
}
for i in range(32):
    REGS[f"x{i}"] = i


class AsmError(Exception):
    """Raised with a friendly message on any input error."""


@dataclass
class Source:
    """One source line, post-strip — kept around for error reporting."""
    line_no: int
    text: str


# ---------------------------------------------------------------------------
# Tokenising / parsing helpers
# ---------------------------------------------------------------------------

def strip_comment(line: str) -> str:
    """Remove # / // comments and trailing whitespace; keep label colons."""
    # Find earliest # or //
    cuts = []
    if "#" in line:
        cuts.append(line.index("#"))
    if "//" in line:
        cuts.append(line.index("//"))
    if cuts:
        line = line[: min(cuts)]
    return line.rstrip()


def parse_int(tok: str, line_no: int) -> int:
    """Parse a decimal / hex / binary integer; allow leading minus."""
    t = tok.strip()
    try:
        if t.startswith("-"):
            return -parse_int(t[1:], line_no)
        if t.startswith(("0x", "0X")):
            return int(t, 16)
        if t.startswith(("0b", "0B")):
            return int(t, 2)
        return int(t, 10)
    except ValueError as e:
        raise AsmError(f"line {line_no}: bad integer '{tok}'") from e


def parse_reg(tok: str, line_no: int) -> int:
    name = tok.strip().lower()
    if name not in REGS:
        raise AsmError(f"line {line_no}: unknown register '{tok}'")
    return REGS[name]


# ---------------------------------------------------------------------------
# Instruction encoding helpers
# ---------------------------------------------------------------------------

def chk_imm(value: int, bits: int, signed: bool, line_no: int, tag: str) -> int:
    """Range-check a value that's about to be stuffed into `bits` bits.
    Returns the value masked to `bits` bits."""
    if signed:
        lo, hi = -(1 << (bits - 1)), (1 << (bits - 1)) - 1
    else:
        lo, hi = 0, (1 << bits) - 1
    if not (lo <= value <= hi):
        raise AsmError(
            f"line {line_no}: {tag} immediate {value} out of range "
            f"[{lo}, {hi}] for {bits}-bit "
            f"{'signed' if signed else 'unsigned'} field"
        )
    return value & ((1 << bits) - 1)


def enc_r(funct7: int, rs2: int, rs1: int, funct3: int, rd: int, opcode: int) -> int:
    return ((funct7 & 0x7F) << 25) | ((rs2 & 0x1F) << 20) | ((rs1 & 0x1F) << 15) \
         | ((funct3 & 0x7) << 12) | ((rd & 0x1F) << 7)  | (opcode & 0x7F)


def enc_i(imm: int, rs1: int, funct3: int, rd: int, opcode: int) -> int:
    return ((imm & 0xFFF) << 20) | ((rs1 & 0x1F) << 15) | ((funct3 & 0x7) << 12) \
         | ((rd & 0x1F) << 7) | (opcode & 0x7F)


def enc_s(imm: int, rs2: int, rs1: int, funct3: int, opcode: int) -> int:
    imm12 = imm & 0xFFF
    return ((imm12 >> 5) << 25) | ((rs2 & 0x1F) << 20) | ((rs1 & 0x1F) << 15) \
         | ((funct3 & 0x7) << 12) | ((imm12 & 0x1F) << 7) | (opcode & 0x7F)


def enc_b(imm: int, rs2: int, rs1: int, funct3: int, opcode: int) -> int:
    # The branch immediate scatters its bits per RISC-V spec.
    # imm[12] -> instr[31], imm[10:5] -> instr[30:25],
    # imm[4:1] -> instr[11:8], imm[11] -> instr[7], imm[0] is always 0.
    i = imm & 0x1FFF
    return ((i >> 12) & 1) << 31 \
         | ((i >> 5)  & 0x3F) << 25 \
         | (rs2 & 0x1F) << 20 \
         | (rs1 & 0x1F) << 15 \
         | (funct3 & 0x7) << 12 \
         | ((i >> 1) & 0xF) << 8 \
         | ((i >> 11) & 1) << 7 \
         | (opcode & 0x7F)


def enc_u(imm: int, rd: int, opcode: int) -> int:
    # The U-type immediate is already at the upper end (imm[31:12]).
    return (imm & 0xFFFFF000) | ((rd & 0x1F) << 7) | (opcode & 0x7F)


def enc_j(imm: int, rd: int, opcode: int) -> int:
    # JAL's immediate is similarly scattered:
    # imm[20] -> instr[31], imm[10:1] -> instr[30:21],
    # imm[11] -> instr[20], imm[19:12] -> instr[19:12], imm[0] is 0.
    i = imm & 0x1FFFFF
    return ((i >> 20) & 1) << 31 \
         | ((i >> 1)  & 0x3FF) << 21 \
         | ((i >> 11) & 1) << 20 \
         | ((i >> 12) & 0xFF) << 12 \
         | (rd & 0x1F) << 7 \
         | (opcode & 0x7F)


# Opcode table. The value is either:
#   ("R", funct7, funct3)
#   ("I", funct3)
#   ("I_SHIFT", funct7, funct3)
#   ("L",  funct3)              -- loads (I-format, distinct opcode 0x03)
#   ("S",  funct3)
#   ("B",  funct3)
#   ("U",)                       -- LUI / AUIPC
#   ("J",)                       -- JAL only
#   ("JALR",)
#   ("PSEUDO", expansion_func)
INSTRS = {
    # R-type ALU (opcode 0x33)
    "add":   ("R", 0x00, 0x0),
    "sub":   ("R", 0x20, 0x0),
    "sll":   ("R", 0x00, 0x1),
    "slt":   ("R", 0x00, 0x2),
    "sltu":  ("R", 0x00, 0x3),
    "xor":   ("R", 0x00, 0x4),
    "srl":   ("R", 0x00, 0x5),
    "sra":   ("R", 0x20, 0x5),
    "or":    ("R", 0x00, 0x6),
    "and":   ("R", 0x00, 0x7),
    # I-type ALU (opcode 0x13)
    "addi":  ("I", 0x0),
    "slti":  ("I", 0x2),
    "sltiu": ("I", 0x3),
    "xori":  ("I", 0x4),
    "ori":   ("I", 0x6),
    "andi":  ("I", 0x7),
    "slli":  ("I_SHIFT", 0x00, 0x1),
    "srli":  ("I_SHIFT", 0x00, 0x5),
    "srai":  ("I_SHIFT", 0x20, 0x5),
    # Loads (opcode 0x03)
    "lw":    ("L", 0x2),
    # Stores (opcode 0x23)
    "sw":    ("S", 0x2),
    # Branches (opcode 0x63)
    "beq":   ("B", 0x0),
    "bne":   ("B", 0x1),
    "blt":   ("B", 0x4),
    "bge":   ("B", 0x5),
    "bltu":  ("B", 0x6),
    "bgeu":  ("B", 0x7),
    # Jumps
    "jal":   ("J",),
    "jalr":  ("JALR",),
    # Upper
    "lui":   ("U", 0x37),
    "auipc": ("U", 0x17),
}

OPC_R_ALU  = 0x33
OPC_I_ALU  = 0x13
OPC_LOAD   = 0x03
OPC_STORE  = 0x23
OPC_BRANCH = 0x63
OPC_JAL    = 0x6F
OPC_JALR   = 0x67


# ---------------------------------------------------------------------------
# Pseudo-instruction expansion
# ---------------------------------------------------------------------------

def expand_pseudo(mnem: str, args: list[str], line_no: int) -> list[tuple[str, list[str]]]:
    """Expand a pseudo to one or more real instructions. Returns a list of
    (real_mnem, real_args) tuples."""
    if mnem == "nop":
        return [("addi", ["x0", "x0", "0"])]
    if mnem == "mv":
        return [("addi", [args[0], args[1], "0"])]
    if mnem == "not":
        return [("xori", [args[0], args[1], "-1"])]
    if mnem == "neg":
        return [("sub", [args[0], "x0", args[1]])]
    if mnem == "li":
        return [("addi", [args[0], "x0", args[1]])]
    if mnem == "j":
        return [("jal", ["x0", args[0]])]
    if mnem == "jr":
        return [("jalr", ["x0", args[0], "0"])]
    if mnem == "ret":
        return [("jalr", ["x0", "x1", "0"])]
    if mnem == "beqz":
        return [("beq", [args[0], "x0", args[1]])]
    if mnem == "bnez":
        return [("bne", [args[0], "x0", args[1]])]
    if mnem == "halt":
        return [("jal", ["x0", "."])]
    return []


PSEUDO_MNEMS = {"nop", "mv", "not", "neg", "li", "j", "jr", "ret", "beqz", "bnez", "halt"}


# ---------------------------------------------------------------------------
# Pass 1 — tokenise, collect labels, count addresses
# ---------------------------------------------------------------------------

@dataclass
class Stmt:
    """A single emit-something statement after pseudo-expansion."""
    line_no: int
    addr: int
    mnem: str
    args: list[str]


def parse_args(rest: str) -> list[str]:
    """Split an operand list on commas, also handling `lw rd, imm(rs1)`
    which gets unfolded to ['rd', 'imm', 'rs1']."""
    if not rest:
        return []
    parts = [p.strip() for p in rest.split(",")]

    out = []
    for p in parts:
        m = re.match(r"^(-?\w+|-?0x[0-9a-fA-F]+|-?0b[01]+)\((\w+)\)$", p)
        if m:
            out.append(m.group(1))
            out.append(m.group(2))
        else:
            out.append(p)
    return out


def first_pass(source: str) -> tuple[list[Stmt], dict[str, int]]:
    stmts: list[Stmt] = []
    labels: dict[str, int] = {}
    addr = 0

    for line_no, raw in enumerate(source.splitlines(), start=1):
        line = strip_comment(raw).strip()
        if not line:
            continue

        # Pull off any number of "label:" prefixes from the front.
        while ":" in line:
            head, _, rest = line.partition(":")
            head = head.strip()
            if not re.match(r"^[A-Za-z_.][A-Za-z0-9_.]*$", head):
                # Not a valid label — leave the colon for the operand parser.
                break
            if head in labels:
                raise AsmError(f"line {line_no}: duplicate label '{head}'")
            labels[head] = addr
            line = rest.strip()
            if not line:
                break

        if not line:
            continue

        # Tokenise: first whitespace-delimited word is the mnemonic.
        m = re.match(r"^(\.\w+|\w+)\s*(.*)$", line)
        if not m:
            raise AsmError(f"line {line_no}: can't parse '{line}'")
        mnem = m.group(1).lower()
        rest = m.group(2)
        args = parse_args(rest)

        if mnem == ".word":
            if len(args) != 1:
                raise AsmError(f"line {line_no}: .word takes one argument")
            stmts.append(Stmt(line_no=line_no, addr=addr, mnem=".word", args=args))
            addr += 4
            continue

        if mnem in PSEUDO_MNEMS:
            for (real_mnem, real_args) in expand_pseudo(mnem, args, line_no):
                stmts.append(Stmt(line_no=line_no, addr=addr,
                                  mnem=real_mnem, args=real_args))
                addr += 4
            continue

        if mnem in INSTRS:
            stmts.append(Stmt(line_no=line_no, addr=addr, mnem=mnem, args=args))
            addr += 4
            continue

        raise AsmError(f"line {line_no}: unknown mnemonic '{mnem}'")

    return stmts, labels


# ---------------------------------------------------------------------------
# Pass 2 — emit machine code
# ---------------------------------------------------------------------------

def resolve_target(operand: str, current_addr: int, labels: dict[str, int],
                   line_no: int) -> int:
    """Return the PC-relative byte offset to a label (or a literal int)."""
    if operand == ".":
        return 0                                # branch-to-here pseudo
    if re.match(r"^-?(0x[0-9a-fA-F]+|0b[01]+|\d+)$", operand):
        return parse_int(operand, line_no)      # absolute byte offset literal
    if operand in labels:
        return labels[operand] - current_addr
    raise AsmError(f"line {line_no}: undefined label '{operand}'")


def emit(stmts: list[Stmt], labels: dict[str, int]) -> list[int]:
    out = []
    for s in stmts:
        if s.mnem == ".word":
            v = parse_int(s.args[0], s.line_no) & 0xFFFFFFFF
            out.append(v)
            continue

        info = INSTRS[s.mnem]
        kind = info[0]

        if kind == "R":
            if len(s.args) != 3:
                raise AsmError(f"line {s.line_no}: {s.mnem} expects 3 operands")
            funct7, funct3 = info[1], info[2]
            rd  = parse_reg(s.args[0], s.line_no)
            rs1 = parse_reg(s.args[1], s.line_no)
            rs2 = parse_reg(s.args[2], s.line_no)
            out.append(enc_r(funct7, rs2, rs1, funct3, rd, OPC_R_ALU))

        elif kind == "I":
            if len(s.args) != 3:
                raise AsmError(f"line {s.line_no}: {s.mnem} expects 3 operands")
            funct3 = info[1]
            rd  = parse_reg(s.args[0], s.line_no)
            rs1 = parse_reg(s.args[1], s.line_no)
            imm = parse_int(s.args[2], s.line_no)
            chk_imm(imm, 12, signed=True, line_no=s.line_no, tag=s.mnem)
            out.append(enc_i(imm, rs1, funct3, rd, OPC_I_ALU))

        elif kind == "I_SHIFT":
            if len(s.args) != 3:
                raise AsmError(f"line {s.line_no}: {s.mnem} expects 3 operands")
            funct7, funct3 = info[1], info[2]
            rd  = parse_reg(s.args[0], s.line_no)
            rs1 = parse_reg(s.args[1], s.line_no)
            shamt = parse_int(s.args[2], s.line_no)
            chk_imm(shamt, 5, signed=False, line_no=s.line_no, tag=s.mnem + " shamt")
            imm = (funct7 << 5) | (shamt & 0x1F)
            out.append(enc_i(imm, rs1, funct3, rd, OPC_I_ALU))

        elif kind == "L":
            # lw rd, imm(rs1)  — parse_args has already unfolded the
            # memory operand into [rd, imm, rs1].
            if len(s.args) != 3:
                raise AsmError(f"line {s.line_no}: {s.mnem} expects rd, imm(rs1)")
            funct3 = info[1]
            rd  = parse_reg(s.args[0], s.line_no)
            imm = parse_int(s.args[1], s.line_no)
            rs1 = parse_reg(s.args[2], s.line_no)
            chk_imm(imm, 12, signed=True, line_no=s.line_no, tag=s.mnem)
            out.append(enc_i(imm, rs1, funct3, rd, OPC_LOAD))

        elif kind == "S":
            # sw rs2, imm(rs1)  — parse_args has unfolded to [rs2, imm, rs1].
            if len(s.args) != 3:
                raise AsmError(f"line {s.line_no}: {s.mnem} expects rs2, imm(rs1)")
            funct3 = info[1]
            rs2 = parse_reg(s.args[0], s.line_no)
            imm = parse_int(s.args[1], s.line_no)
            rs1 = parse_reg(s.args[2], s.line_no)
            chk_imm(imm, 12, signed=True, line_no=s.line_no, tag=s.mnem)
            out.append(enc_s(imm, rs2, rs1, funct3, OPC_STORE))

        elif kind == "B":
            if len(s.args) != 3:
                raise AsmError(f"line {s.line_no}: {s.mnem} expects rs1, rs2, label")
            funct3 = info[1]
            rs1 = parse_reg(s.args[0], s.line_no)
            rs2 = parse_reg(s.args[1], s.line_no)
            offset = resolve_target(s.args[2], s.addr, labels, s.line_no)
            chk_imm(offset, 13, signed=True, line_no=s.line_no, tag=s.mnem + " offset")
            if offset & 1:
                raise AsmError(f"line {s.line_no}: branch offset must be even")
            out.append(enc_b(offset, rs2, rs1, funct3, OPC_BRANCH))

        elif kind == "J":
            if len(s.args) != 2:
                raise AsmError(f"line {s.line_no}: jal expects rd, label")
            rd = parse_reg(s.args[0], s.line_no)
            offset = resolve_target(s.args[1], s.addr, labels, s.line_no)
            chk_imm(offset, 21, signed=True, line_no=s.line_no, tag="jal offset")
            if offset & 1:
                raise AsmError(f"line {s.line_no}: jal offset must be even")
            out.append(enc_j(offset, rd, OPC_JAL))

        elif kind == "JALR":
            if len(s.args) != 3:
                raise AsmError(f"line {s.line_no}: jalr expects rd, rs1, imm")
            rd  = parse_reg(s.args[0], s.line_no)
            rs1 = parse_reg(s.args[1], s.line_no)
            imm = parse_int(s.args[2], s.line_no)
            chk_imm(imm, 12, signed=True, line_no=s.line_no, tag="jalr imm")
            out.append(enc_i(imm, rs1, 0, rd, OPC_JALR))

        elif kind == "U":
            if len(s.args) != 2:
                raise AsmError(f"line {s.line_no}: {s.mnem} expects rd, imm20")
            opcode = info[1]
            rd  = parse_reg(s.args[0], s.line_no)
            imm = parse_int(s.args[1], s.line_no)
            chk_imm(imm, 20, signed=False, line_no=s.line_no, tag=s.mnem + " imm")
            out.append(enc_u(imm << 12, rd, opcode))

        else:
            raise AsmError(f"line {s.line_no}: internal: unknown kind {kind!r}")

    return out


# ---------------------------------------------------------------------------
# Entry point
# ---------------------------------------------------------------------------

def assemble(source: str) -> list[int]:
    stmts, labels = first_pass(source)
    return emit(stmts, labels)


def format_hex(words: list[int]) -> str:
    return "\n".join(f"{w & 0xFFFFFFFF:08X}" for w in words) + ("\n" if words else "")


def main() -> int:
    ap = argparse.ArgumentParser(description="Tiny RV32I assembler")
    ap.add_argument("input", help="input .S file (use - for stdin)")
    ap.add_argument("-o", "--output", default="-", help="output hex file (default: stdout)")
    args = ap.parse_args()

    if args.input == "-":
        src = sys.stdin.read()
    else:
        src = Path(args.input).read_text()

    try:
        words = assemble(src)
    except AsmError as e:
        print(f"{args.input}: error: {e}", file=sys.stderr)
        return 1

    text = format_hex(words)
    if args.output == "-":
        sys.stdout.write(text)
    else:
        Path(args.output).write_text(text)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
