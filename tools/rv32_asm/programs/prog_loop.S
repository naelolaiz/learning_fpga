# prog_loop.S — counted decrement loop.
#
# Counts t0 down from 5 to 0 (inclusive), incrementing t1 each pass
# of the loop body. At the end t1 = 5 and t0 = 0. Halts.

addi t0, x0, 5          # loop counter
addi t1, x0, 0          # accumulator

loop:
    beq  t0, x0, done   # exit when counter hits zero
    addi t1, t1, 1
    addi t0, t0, -1
    j    loop

done:
    halt
