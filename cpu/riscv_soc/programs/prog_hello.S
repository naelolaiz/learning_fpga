# prog_hello.S
#
# Sends "Hello, RV32!\n" out the SoC's UART_TX peripheral one byte at
# a time, then halts. The MMIO address for UART_TX_DATA is fixed at
# 0x8000_0000 by the SoC's address decoder:
#   write to 0x8000_0000  → enqueue the LSB byte for transmission
#   read  from 0x8000_0000 → bit 0 = tx_busy
#
# The send_byte subroutine polls the busy bit until it's clear, then
# stores the character.

  # Setup: t0 = UART_TX_DATA = 0x8000_0000
  # ADDI can't reach 0x8000_0000 in one shot (12-bit signed imm range
  # is -2048 to +2047), so use LUI to load the upper 20 bits. The
  # lower 12 bits are zero, so no follow-up ADDI is needed.
  lui   t0, 0x80000              # t0 = 0x80000000

  # Send each character of "Hello, RV32!\n"
  addi  a0, x0, 0x48             # 'H'
  jal   ra, send_byte
  addi  a0, x0, 0x65             # 'e'
  jal   ra, send_byte
  addi  a0, x0, 0x6C             # 'l'
  jal   ra, send_byte
  addi  a0, x0, 0x6C             # 'l'
  jal   ra, send_byte
  addi  a0, x0, 0x6F             # 'o'
  jal   ra, send_byte
  addi  a0, x0, 0x2C             # ','
  jal   ra, send_byte
  addi  a0, x0, 0x20             # ' '
  jal   ra, send_byte
  addi  a0, x0, 0x52             # 'R'
  jal   ra, send_byte
  addi  a0, x0, 0x56             # 'V'
  jal   ra, send_byte
  addi  a0, x0, 0x33             # '3'
  jal   ra, send_byte
  addi  a0, x0, 0x32             # '2'
  jal   ra, send_byte
  addi  a0, x0, 0x21             # '!'
  jal   ra, send_byte
  addi  a0, x0, 0x0A             # '\n'
  jal   ra, send_byte

  halt                            # jal x0, . — self-loop sentinel

# ----------------------------------------------------------------
# send_byte(a0 = byte to send)
# Polls 0x8000_0000 until tx_busy == 0, then writes a0 to the same
# address (which triggers transmission). Uses t1 as a scratch.
# ----------------------------------------------------------------
send_byte:
  lw    t1, 0(t0)                # read UART_TX status (bit 0 = busy)
  bne   t1, x0, send_byte        # loop while busy
  sw    a0, 0(t0)                # send byte
  ret                            # jalr x0, ra, 0
