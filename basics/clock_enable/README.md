# Clock enables and asynchronous inputs

Learn to update a counter slowly while every register uses the same `clk`.
Read [blink_led](../blink_led/) and [logic_styles](../logic_styles/) first.
The lesson runs entirely in simulation; no board is needed.

## Interface and timing

`clock_enable.vhd` and `clock_enable.v` implement the same interface:

| Signal / parameter | Contract |
| --- | --- |
| `clk` | The only clock; all state updates on rising edges |
| `rst` | Synchronous active-high reset; clears the divider, synchronizer, tick and count |
| `enable_async` | A slowly changing asynchronous single bit, such as a button |
| `enable_sync` | Output of the second synchronizer stage |
| `tick` | High after every `DIVISOR`-th rising edge following reset release |
| `count` | Increments on a tick edge when the **previous** `enable_sync` was high; wraps modulo `2**COUNT_WIDTH` |
| `DIVISOR` / `COUNT_WIDTH` | Positive integers; defaults are 4 / 4 |

With `DIVISOR=1`, `tick` stays high throughout normal operation: every edge
is eligible to update the count. Reset still clears it. At larger divisors,
each high interval lasts one clock period.

The two synchronizer stages sample a stable input change on consecutive
clock edges. RTL simulation shows the two-edge delay, but does not model
metastability: on hardware, settling can occasionally take another cycle.
Use this chain for slow single-bit levels; narrow pulses and multi-bit
values need a different crossing protocol. Synchronizing a button does
not remove its contact bounce; place a [debouncer](../../building_blocks/debounce/)
after the synchronizer when you need one press to cause one action.

## Why the enable is inside the process

Both the divider and the count use `rising_edge(clk)` / `posedge clk`.
The terminal-count condition gates the counter's **data update**; it does
not create a new clock. The exported `tick` is registered for observation.
Using it in another clocked process as `if tick` consumes the tick on
the next edge, because that process sees the previous register value.

Compare this with [CounterTimer](../../building_blocks/counter_timer/),
which uses a timer pulse as a clock, and the legacy
[seven-segment clock](../../display/7segments/clock/). Those versions are
useful examples to refactor: clock enables keep timing analysis within
one clock domain and avoid routing a logic-generated pulse as a clock.

## Run and inspect

Inside the [documented tool container](../../README.md#start-here), run:

```bash
make -C basics/clock_enable all
```

Open `build/tb_clock_enable.png` and `build/tb_clock_enable_v.png`.
After reset, the synchronized input becomes high on the second edge,
the first tick increments `count` on edge 4, and ticks continue every
four clocks. The counter wraps after 16 enabled ticks. When the input
is disabled, synchronization still takes two edges and the count holds.

Both testbenches assert tick cadence, input latency, holding, wrap and
reset. A second instance covers `DIVISOR=1` and `COUNT_WIDTH=1`.
The netlists show clocked state driven by a single clock.

## Try it

1. Change the main DUT and its cadence assertions to `DIVISOR=8`.
   Predict the first tick at edge 8 and the 4-bit counter wrapping on
   edge 128 when the enable stays high from reset release. Extend the
   stimulus to reach that wrap and assert both predictions.
2. Convert `CounterTimer` to a single-clock design with an enable input.
   Drive it from a timer tick inside a `posedge clk` process, then check
   that each tick changes the count exactly once. Account explicitly for
   the one-edge delay when consuming a registered tick.

Continue with [PWM](../pwm_led/) and the
[hardware timing walkthrough](../../docs/timing.md).
