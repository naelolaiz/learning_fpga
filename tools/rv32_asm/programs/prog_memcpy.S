# prog_memcpy.S — LW/SW sweep: read 4 words starting at address
# 0x100, write them back at address 0x200. After the copy, the CPU
# testbench can compare DMEM[0x100:0x110] with DMEM[0x200:0x210].
#
# Assumes DMEM has been initialised so addresses 0x100..0x10C hold
# a known pattern (the testbench sets that up before run).

addi t0, x0, 4           # word counter
addi t1, x0, 0x100       # src pointer  (need ≤ 0x7FF for ADDI imm)
addi t2, x0, 0x200       # dst pointer

loop:
    beq  t0, x0, done
    lw   t3, 0(t1)
    sw   t3, 0(t2)
    addi t1, t1, 4
    addi t2, t2, 4
    addi t0, t0, -1
    j    loop

done:
    halt
