# Timer

Free-running tick generator: counts rising edges of `clock` up to a
limit, then pulses `timerTriggered` high for `TRIGGER_DURATION`
cycles and wraps to zero.

## Interface

| Port | Direction | Default | Meaning |
|---|---|---|---|
| `clock` | in | `'0'` | Counted edge |
| `reset` | in | `'0'` | Synchronously clears both count and output; counting pauses while held high |
| `maxLimit` | in (integer, runtime) | `MAX_NUMBER` | Counter wraps on the next rising edge when its count reaches or exceeds this value |
| `timerTriggered` | out | `'0'` | High for `TRIGGER_DURATION` cycles starting at wrap |

Two generics:

| Generic | Default | Meaning |
|---|---|---|
| `MAX_NUMBER` | `50_000_000` | Nonnegative compile-time upper bound for the counter type and `maxLimit`'s default |
| `TRIGGER_DURATION` | `1` | Positive number of cycles `timerTriggered` stays high after a wrap |

## Why `maxLimit` is both a generic *and* a port

Callers that know the period at synthesis time pass it as the
`MAX_NUMBER` generic and never wire the `maxLimit` port; the port
defaults to the generic. Callers that need to *change the period at
runtime* (e.g. [`variable_timer`](../variable_timer/)) drive
`maxLimit` from a register. The counter's type is
`integer range 0 to MAX_NUMBER`, so the runtime override must fit in
that range — wrappers that accept arbitrary user input have to clamp.
The Verilog input has no port default: connect `maxLimit` explicitly to
`MAX_NUMBER` when no runtime override is needed.

## Timing and boundary cases

With a stable limit, the period is **`maxLimit + 1` clock cycles**. After
reset is released, the first trigger occurs on that many rising edges.
Reset takes effect only on a rising edge, including when a pulse is active;
it suppresses triggers and holds the output low for as long as it is high.

Limits change at the next rising edge. Increasing the limit extends the
current count; lowering it below the count triggers immediately on that
edge and starts a new period. This avoids counting beyond `MAX_NUMBER`.
`maxLimit = 0` (including `MAX_NUMBER = 0`) triggers on every enabled edge.

When `TRIGGER_DURATION` is at least the current period, pulses overlap,
so the output stays high after the first trigger. A longer runtime period
lets it return low once `TRIGGER_DURATION` cycles have elapsed since the
most recent trigger. There is no compulsory low cycle between overlapping
pulses. Negative bounds, zero duration, and out-of-range runtime limits are
invalid and are rejected in simulation.

## Tested behaviour

[`test/tb_timer.vhd`](test/tb_timer.vhd) (and the Verilog mirror) run
two DUTs side-by-side: one using the generic only, one driving
`maxLimit` at runtime. Asserts that the tick count in 110 cycles
matches the expected period for each.

Run the complete Timer checks with:

```sh
make -C building_blocks/timer test
```

The test target also runs [`check_timer_equivalence.py`](../../tools/check_timer_equivalence.py).
Both trace benches read the same stimulus file; the driver checks their
per-cycle outputs against explicit expected sequences and against each
other. Cases cover held reset, reset during a pulse, release timing, runtime
limit increases and decreases, zero/minimum bounds, and overlapping pulses.
The benches also assert that changing reset or limit between clock edges
cannot change the output. Compilation and traces use a temporary directory.
