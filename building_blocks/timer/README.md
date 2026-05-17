# Timer

Free-running tick generator: counts rising edges of `clock` up to a
limit, then pulses `timerTriggered` high for `TRIGGER_DURATION`
cycles and wraps to zero.

## Interface

| Port | Direction | Default | Meaning |
|---|---|---|---|
| `clock` | in | `'0'` | Counted edge |
| `reset` | in | `'0'` | Synchronously clears the count |
| `maxLimit` | in (integer, runtime) | `MAX_NUMBER` | Period — counter wraps when it reaches this value |
| `timerTriggered` | out | `'0'` | High for `TRIGGER_DURATION` cycles starting at wrap |

Two generics:

| Generic | Default | Meaning |
|---|---|---|
| `MAX_NUMBER` | `50_000_000` | Compile-time upper bound for the counter type and `maxLimit`'s default |
| `TRIGGER_DURATION` | `1` | How many cycles `timerTriggered` stays high after a wrap |

## Why `maxLimit` is both a generic *and* a port

Callers that know the period at synthesis time pass it as the
`MAX_NUMBER` generic and never wire the `maxLimit` port; the port
defaults to the generic. Callers that need to *change the period at
runtime* (e.g. [`variable_timer`](../variable_timer/)) drive
`maxLimit` from a register. The counter's type is
`integer range 0 to MAX_NUMBER`, so the runtime override must fit in
that range — wrappers that accept arbitrary user input have to clamp.

## Tested behaviour

[`test/tb_timer.vhd`](test/tb_timer.vhd) (and the Verilog mirror) run
two DUTs side-by-side: one using the generic only, one driving
`maxLimit` at runtime. Asserts that the tick count in 110 cycles
matches the expected period for each.
