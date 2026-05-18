# mode_blink

Two-mode blink driver:

| `toggleMode` | `signalOut` |
|---|---|
| `0` | passes `signalIn` through unchanged — one transition per rising **and** each falling edge of the input |
| `1` | toggles only on rising edges of `signalIn` — perceived rate halves |

Originally lived as `DotBlinker.vhd` inside the 7-segments clock,
driving the middle decimal-point with HHMM/MMSS-aware behaviour. The
logic itself is mode-agnostic — lifted out and renamed with neutral
port names so anything that wants a "full rate / half rate" blink
toggle can reuse it.

## Interface

| Port | Direction | Meaning |
|---|---|---|
| `signalIn` | in | Source pulse |
| `toggleMode` | in | 0 = pass through, 1 = toggle on rising edge |
| `signalOut` | out | Result |

## Tested behaviour

[`test/tb_mode_blink.vhd`](test/tb_mode_blink.vhd) and the Verilog
mirror feed both modes from the same square-wave input and assert
the edge-count ratio: 20 transitions on the passthrough output vs
10 on the half-rate output over 10 input periods.
