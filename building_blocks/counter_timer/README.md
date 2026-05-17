# CounterTimer

A [`Timer`](../timer/) cascaded with a 64-bit mod-N saturating
counter — useful as a "tick every T cycles, advance state every
tick, wrap at N states" primitive.

## Composition

```
                ┌──────────┐
  clock  ──────►│  Timer   │── timerTriggered ─────────────► (output)
                │ MAX=T    │       │
                └──────────┘       ▼
                              ┌──────────────┐
                              │ +1 / wrap at │── counter ──► (output)
                              │ MAX_FOR_     │
                              │  COUNTER     │
                              └──────────────┘
```

## Interface

| Port | Direction | Meaning |
|---|---|---|
| `clock` | in | Counted edge |
| `reset` | in | Synchronously clear the counter and the inner Timer |
| `timerTriggered` | out | Passes through the inner Timer's tick |
| `counter` | out (64-bit) | Current state, wraps 0 → … → `MAX_NUMBER_FOR_COUNTER` → 0 |

Generics:

| Generic | Default | Meaning |
|---|---|---|
| `MAX_NUMBER_FOR_TIMER` | `50_000_000` | Inner Timer period (clocks per tick) |
| `MAX_NUMBER_FOR_COUNTER` | `10` | Counter modulus |

## Tested behaviour

[`test/tb_counter_timer.vhd`](test/tb_counter_timer.vhd) (and the
Verilog mirror) drive the DUT with a 10-cycle Timer and modulus-4
counter, then assert the counter is back at 0 after 5 ticks and
again at 0 after 10 ticks.
