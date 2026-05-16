# prog_branches.S — exercise every conditional branch with both a
# taken and a not-taken path.
#
# t0 = 5, t1 = 5 → BEQ taken    BNE not-taken
# t0 = -1 (signed) vs t1 = 1
#   BLT signed  -1 < 1            -> taken
#   BLTU unsigned 0xFFFFFFFF < 1  -> not taken
# t0 = 1 vs t1 = 1
#   BGE 1 >= 1                    -> taken
#   BGEU 1 >= 1                   -> taken
#
# Each branch that's expected to be TAKEN bumps a counter; if a
# branch is mistaken NOT-taken it falls through and runs an
# `addi s0, x0, -1` that the CPU TB can spot. Final s0 == 4 means
# every "should be taken" really was taken.

addi s0, x0, 0           # taken-branch counter
addi t0, x0, 5
addi t1, x0, 5

beq  t0, t1, beq_taken
addi s0, x0, -1          # fall-through: BEQ failed to take
beq_taken:
addi s0, s0, 1

bne  t0, t1, bne_taken   # 5 != 5 is false; should NOT take
j    bne_ok
bne_taken:
addi s0, x0, -1          # BNE incorrectly took
bne_ok:

addi t0, x0, -1          # -1 as signed, 0xFFFFFFFF as unsigned
addi t1, x0, 1

blt  t0, t1, blt_taken   # signed -1 < 1
addi s0, x0, -1
blt_taken:
addi s0, s0, 1

bltu t0, t1, bltu_bad    # unsigned 0xFFFFFFFF < 1 is FALSE
j    bltu_ok
bltu_bad:
addi s0, x0, -1
bltu_ok:

addi t0, x0, 1
addi t1, x0, 1

bge  t0, t1, bge_taken   # 1 >= 1
addi s0, x0, -1
bge_taken:
addi s0, s0, 1

bgeu t0, t1, bgeu_taken  # 1 >= 1 unsigned
addi s0, x0, -1
bgeu_taken:
addi s0, s0, 1

halt
