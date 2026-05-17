# VariableTimer

A [`Timer`](../timer/) whose trigger period is reprogrammed at
runtime through a 64-bit serial-load port.

## Composition

```
              ┌──────────────────────┐
              │  shift register +    │  limitReg ┌──────────┐
  dataIn  ───►│  clamp to MAX_NUMBER ├──────────►│  Timer   ├──► timerTriggered
              │                      │           │          │
  setMax  ─┬─►│  (held active during │           │ maxLimit │
           │  │   load)              │           │          │
           │  └──────────────────────┘           └────▲─────┘
           │                                          │
           └─────► OR (innerReset) ───────────────────┘
```

The inner `Timer` is held in reset for the duration of the load so
the new period takes effect on the falling edge of `setMax`.

## Interface

| Port | Direction | Meaning |
|---|---|---|
| `clock` | in | Counted edge |
| `reset` | in | Reset the shift register and the inner Timer |
| `setMax` | in | When high, shift `dataIn` into the limit register |
| `dataIn` | in | Serial input — sampled on each clock while `setMax = '1'` |
| `timerTriggered` | out | Pulses high for `TRIGGER_DURATION` cycles each period |

Generics `MAX_NUMBER` (compile-time upper bound, default
50 000 000) and `TRIGGER_DURATION` (cycles the output stays high,
default 1) flow through to the inner Timer.

## Tested behaviour

[`test/tb_variable_timer.vhd`](test/tb_variable_timer.vhd) and the
Verilog mirror shift in the bit pattern for 9 over 64 clocks, then
assert that the post-load tick rate matches a period of 10.
