# prog_addi.S — sanity-check ADDI + halt sentinel.
#
# Loads 1 into t0, then accumulates 1+2 = 3 in t0. Halts.
# After the run, the CPU testbench should see t0 == 3.

addi t0, x0, 1
addi t0, t0, 2
halt
