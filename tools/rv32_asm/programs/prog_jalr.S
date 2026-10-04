# JALR commit-order regression, shared by both CPUs and the SoC.
# Jump destinations are formed with AUIPC, so every source value is
# independent of the link value written by JALR. Two rd == rs1 cases
# also check bit-0 masking and a negative JALR immediate.
# Final: s0=4, s1=16, s2=44, s3=76, s4=42, s5=43, s6=0.

addi s0, s0, 1          # 0: execute once, never during reset
auipc t0, 0            # 4: t0 = 4
addi t0, t0, 21        # 8: odd target 25 -> 24
jalr t0, t0, 0         # 12: target uses OLD t0; link = 16
addi s0, x0, -1        # 16: wrong path
halt                   # 20: wrong path
addi s0, s0, 1         # 24: first destination
mv s1, t0              # 28: capture first link

auipc t0, 0            # 32: t0 = 32
addi t0, t0, 29        # 36: t0 = 61
jalr t0, t0, -4        # 40: (61 - 4) & ~1 = 56; link = 44
sw t0, 4(x0)           # 44: wrong-path store must never commit
addi s0, x0, -1        # 48: wrong path
halt                   # 52: wrong path
addi s0, s0, 1         # 56: second destination
mv s2, t0              # 60: capture second link

auipc t1, 0            # 64
addi t1, t1, 24        # 68: target = 88
jalr ra, t1, 0         # 72: distinct rd/rs1; link = 76
sw t0, 4(x0)           # 76: wrong-path store
addi s0, x0, -1        # 80: wrong path
halt                   # 84: wrong path
mv s3, ra              # 88: capture distinct-register link
addi s0, s0, 1         # 92
addi t2, x0, 42        # 96
sw t2, 0(x0)           # 100: test memory write on the commit edge
lw s4, 0(x0)           # 104
addi s5, s4, 1         # 108: load-use dependency in pipeline
lw s6, 4(x0)           # 112: check skipped stores
halt                   # 116
