# prog_load_use.S — exercises the load-use hazard path.
#
# On the pipelined CPU, a load's value isn't available until the
# end of MEM, but the *next* instruction is already in EX by then.
# Forwarding can't deliver this case — the hazard_detector must
# stall (one-cycle bubble), then forwarding picks up the value.
#
# The single-cycle CPU runs this program identically (no stalls
# needed because every instruction completes in one clock); the
# pipelined CPU must produce the same final state but inserts a
# bubble after each lw.
#
# Final state:
#   t0 (x5) = 7
#   t1 (x6) = 42       (loaded from mem[0])
#   t2 (x7) = 84       (= t1 + t1, depends on load-use stall)
#   s0 (x8) = 7        (loaded from mem[4])
#   s1 (x9) = 14       (= s0 + s0)

# Setup: store two known values to memory.
addi  t0, x0, 42
sw    t0, 0(x0)
addi  t0, x0, 7
sw    t0, 4(x0)

# Load-use pair #1.
lw    t1, 0(x0)         # t1 = 42 — stall expected
add   t2, t1, t1        # t2 = 84

# Load-use pair #2 — different registers, same idiom.
lw    s0, 4(x0)         # s0 = 7 — stall expected
add   s1, s0, s0        # s1 = 14

halt
