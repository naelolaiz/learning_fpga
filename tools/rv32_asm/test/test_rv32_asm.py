#!/usr/bin/env python3
"""
Unit tests for rv32_asm.py.

The bench is split into two halves:

  1. Per-instruction encoding: hand-encoded RV32I instructions vs.
     the assembler's output for the same mnemonic. These are the same
     reference encodings used by the decoder testbench
     (building_blocks/decoder_rv32/test/), so a regression here lines
     up with a regression there.

  2. Whole-program golden files: every .S in tools/rv32_asm/programs/
     is re-assembled and its output diffed against the committed
     .hex sibling. If the assembler changes, the golden files are
     the audit trail.
"""

import subprocess
import sys
import unittest
from pathlib import Path

# Resolve relative to this test file so the tests work whether
# they're invoked from the project root or the tool dir itself.
HERE = Path(__file__).resolve().parent
TOOL = HERE.parent / "rv32_asm.py"
PROGS = HERE.parent / "programs"

sys.path.insert(0, str(HERE.parent))
import rv32_asm  # noqa: E402


class EncodingTests(unittest.TestCase):
    """One short program per case so the inputs are readable in the
    diff if a regression shows up."""

    def assemble_one(self, src: str) -> int:
        words = rv32_asm.assemble(src)
        self.assertEqual(len(words), 1, f"expected 1 instr from {src!r}")
        return words[0]

    # R-type
    def test_add(self):
        self.assertEqual(self.assemble_one("add x3, x1, x2"), 0x002081B3)

    def test_sub(self):
        self.assertEqual(self.assemble_one("sub x3, x1, x2"), 0x402081B3)

    def test_and(self):
        self.assertEqual(self.assemble_one("and x3, x1, x2"), 0x0020F1B3)

    def test_sra(self):
        self.assertEqual(self.assemble_one("sra x3, x1, x2"), 0x4020D1B3)

    def test_srl(self):
        self.assertEqual(self.assemble_one("srl x3, x1, x2"), 0x0020D1B3)

    def test_slt(self):
        self.assertEqual(self.assemble_one("slt x3, x1, x2"), 0x0020A1B3)

    # I-type ALU
    def test_addi_positive(self):
        self.assertEqual(self.assemble_one("addi x3, x1, 100"), 0x06408193)

    def test_addi_negative_one(self):
        self.assertEqual(self.assemble_one("addi x1, x0, -1"), 0xFFF00093)

    def test_addi_most_negative(self):
        self.assertEqual(self.assemble_one("addi x1, x0, -0x800"), 0x80000093)

    def test_slli(self):
        # SLLI x3, x1, 5
        # shamt = 5, funct7=0 → imm[11:5]=0000000, imm[4:0]=00101
        # opcode 0010011, funct3=001, rd=x3, rs1=x1
        # Encoding: 0000000_00101_00001_001_00011_0010011 = 0x00509193
        self.assertEqual(self.assemble_one("slli x3, x1, 5"), 0x00509193)

    def test_srli(self):
        self.assertEqual(self.assemble_one("srli x3, x1, 5"), 0x0050D193)

    def test_srai(self):
        self.assertEqual(self.assemble_one("srai x3, x1, 5"), 0x4050D193)

    # Loads / stores
    def test_lw(self):
        self.assertEqual(self.assemble_one("lw x3, 0(x1)"), 0x0000A183)

    def test_lw_negative_offset(self):
        # LW x3, -4(x1)  imm = -4 → 12-bit 0xFFC
        # 111111111100_00001_010_00011_0000011
        # = 1111_1111_1100_0000_1010_0001_1000_0011 = 0xFFC0A183
        self.assertEqual(self.assemble_one("lw x3, -4(x1)"), 0xFFC0A183)

    def test_sw(self):
        self.assertEqual(self.assemble_one("sw x2, 4(x1)"), 0x0020A223)

    # Branches with labels: label arithmetic is what we really want to
    # cover here, since plain numeric offsets are caught by the
    # encoders in isolation.
    def test_beq_forward_label(self):
        src = (
            "beq x1, x2, target\n"
            "nop\n"
            "nop\n"
            "target: nop\n"
        )
        words = rv32_asm.assemble(src)
        # BEQ at addr 0, target at addr 12 → offset +12
        self.assertEqual(words[0], 0x00208663)

    def test_beq_backward_label(self):
        src = (
            "target: nop\n"
            "nop\n"
            "beq x1, x2, target\n"
        )
        words = rv32_asm.assemble(src)
        # BEQ at addr 8, target at addr 0 → offset -8
        # imm=-8: bit12=1, bit11=1, bit10:5=111111, bit4:1=1100, bit0=0
        # = 1_111111_00010_00001_000_1100_1_1100011
        # = 1111_1110_0010_0000_1000_1100_1110_0011 = 0xFE208CE3
        self.assertEqual(words[2], 0xFE208CE3)

    # Jumps
    def test_jal_forward_label(self):
        src = (
            "jal x1, target\n"
            "nop\n"
            "target: nop\n"
        )
        words = rv32_asm.assemble(src)
        # JAL at addr 0, target at 8, offset = +8
        self.assertEqual(words[0], 0x008000EF)

    def test_jalr(self):
        # JALR x1, x2, 4
        self.assertEqual(self.assemble_one("jalr x1, x2, 4"), 0x004100E7)

    # Upper
    def test_lui(self):
        self.assertEqual(self.assemble_one("lui x4, 0x12345"), 0x12345237)

    def test_auipc(self):
        self.assertEqual(self.assemble_one("auipc x4, 0x12345"), 0x12345217)

    # ABI register aliases
    def test_abi_register_aliases(self):
        # ADDI ra (=x1), zero (=x0), 1  → 0x00100093
        self.assertEqual(self.assemble_one("addi ra, zero, 1"), 0x00100093)
        # MV t0 (=x5), t1 (=x6) → ADDI t0, t1, 0
        # = 0x00030293
        self.assertEqual(self.assemble_one("mv t0, t1"), 0x00030293)

    # Pseudos
    def test_nop(self):
        self.assertEqual(self.assemble_one("nop"), 0x00000013)

    def test_ret(self):
        # JALR x0, x1, 0 → 0x00008067
        self.assertEqual(self.assemble_one("ret"), 0x00008067)

    def test_halt(self):
        # JAL x0, .  → self-loop, offset 0 → 0x0000006F
        self.assertEqual(self.assemble_one("halt"), 0x0000006F)

    # .word
    def test_word_directive(self):
        words = rv32_asm.assemble(".word 0xDEADBEEF\n")
        self.assertEqual(words, [0xDEADBEEF])

    # Comments
    def test_comments(self):
        src = (
            "# this is a comment\n"
            "addi x1, x0, 1   // and so is this\n"
            "  # blank-after-strip line\n"
            "\n"
            "addi x2, x0, 2\n"
        )
        words = rv32_asm.assemble(src)
        self.assertEqual(words, [0x00100093, 0x00200113])

    # Error paths
    def test_unknown_mnemonic_raises(self):
        with self.assertRaises(rv32_asm.AsmError):
            rv32_asm.assemble("foop x1, x2, x3\n")

    def test_out_of_range_imm_raises(self):
        # 0x800 doesn't fit in 12-bit signed (range is -0x800..0x7FF)
        with self.assertRaises(rv32_asm.AsmError):
            rv32_asm.assemble("addi x1, x0, 0x800\n")

    def test_undefined_label_raises(self):
        with self.assertRaises(rv32_asm.AsmError):
            rv32_asm.assemble("beq x1, x2, never_declared\n")


class GoldenFileTests(unittest.TestCase):
    """Re-assemble every .S in programs/ and compare against its .hex
    sibling. If anything changes, the .hex needs to be regenerated by
    hand (run rv32_asm directly) so a maintainer sees what shifted."""

    def _golden_pairs(self):
        if not PROGS.is_dir():
            return []
        return sorted(p for p in PROGS.glob("*.S"))

    def test_each_program(self):
        for s_file in self._golden_pairs():
            hex_file = s_file.with_suffix(".hex")
            with self.subTest(program=s_file.name):
                self.assertTrue(
                    hex_file.exists(),
                    f"missing golden file {hex_file}"
                )
                # Run rv32_asm in-process for speed.
                src = s_file.read_text()
                words = rv32_asm.assemble(src)
                actual = rv32_asm.format_hex(words)
                expected = hex_file.read_text()
                self.assertEqual(
                    actual.splitlines(),
                    expected.splitlines(),
                    f"{s_file.name}: assembler output differs from "
                    f"{hex_file.name} — re-run rv32_asm to update if "
                    "the change is intentional"
                )


if __name__ == "__main__":
    unittest.main()
