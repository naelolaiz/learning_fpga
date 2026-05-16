# prog_simd.S
#
# Drives the SoC's SIMD accelerator (cpu/building_blocks/simd_alu,
# exposed via the SoC's MMIO map) to perform one packed-SIMD
# operation, then streams the 4-byte result out the UART.
#
# Inputs:
#   OPERAND_A = 0x04030201   — 4 signed-8 lanes:  1,  2,  3,  4
#   OPERAND_B = 0x40302010   —                  16, 32, 48, 64
#   OP        = 0x0          — 4x8 add, wrap (op[3]=0 width 8b,
#                               op[2:1]=00 add, op[0]=0 wrap)
# Expected RESULT = 0x44332211 — lanes: 17, 34, 51, 68
#
# The TB receives bytes 0x11, 0x22, 0x33, 0x44 (LSB first) over UART
# and asserts they match. This proves end-to-end:
#   CPU SW → MMIO write path → SIMD ALU → MMIO read path → CPU LW → UART TX
#
# MMIO register offsets (from base 0x8000_0000), see riscv_soc.vhd:
#   0x00 UART_TX_DATA (W: send; R: bit 0 = tx_busy)
#   0x30 SIMD_OPERAND_A (W)
#   0x34 SIMD_OPERAND_B (W)
#   0x38 SIMD_OP        (W, low 4 bits)
#   0x3C SIMD_RESULT    (R)

  # Setup: t0 = MMIO base = 0x8000_0000
  lui   t0, 0x80000

  # Write operand A = 0x04030201 to SIMD_OPERAND_A.
  lui   a0, 0x04030
  addi  a0, a0, 0x201
  sw    a0, 0x30(t0)

  # Write operand B = 0x40302010.
  lui   a1, 0x40302
  addi  a1, a1, 0x010
  sw    a1, 0x34(t0)

  # Write OP = 0 (4x8 add, wrap).
  sw    x0, 0x38(t0)

  # Read SIMD_RESULT into a2 — expect 0x44332211.
  lw    a2, 0x3C(t0)

  # Send 4 bytes of the result LSB-first over UART.
  # The send_byte helper only looks at the low 8 bits of a0.
  add   a0, a2, x0
  jal   ra, send_byte
  srli  a0, a2, 8
  jal   ra, send_byte
  srli  a0, a2, 16
  jal   ra, send_byte
  srli  a0, a2, 24
  jal   ra, send_byte

  halt

# ----------------------------------------------------------------
# send_byte(a0): low 8 bits → UART. Polls tx_busy until clear.
# Trashes t1.
# ----------------------------------------------------------------
send_byte:
  lw    t1, 0(t0)
  bne   t1, x0, send_byte
  sw    a0, 0(t0)
  ret
