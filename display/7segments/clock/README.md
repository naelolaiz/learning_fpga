# Multiplexed clock and alarm

Learn to compose timers, digit counters, debouncers, and a display
multiplexer. Prerequisites: [7-segment counter](../counter/),
[timer](../../../building_blocks/timer/),
[modular counter](../../../building_blocks/mod_counter/), and
[debounce](../../../building_blocks/debounce/).

This is a legacy composition example: it clocks counters from divided
signals and carry outputs. The VHDL version also uses debounced button
edges as clocks; the Verilog mode handlers detect those edges on the
master clock.
Study [clock enables](../../../basics/clock_enable/) and
[timing constraints](../../../docs/timing.md) before adapting that
structure for hardware. A single master clock with enables makes the
timing relationships easier to constrain and verify.

## Interface and behaviour

The board top is `top_level_7segments_clock`; its Quartus project is
`top_level_7segments_clock.qpf` and pin assignments are in the matching
`.qsf`. Timer generics use a 50 MHz clock by default and can be reduced
for simulation.

| Port | Meaning |
| --- | --- |
| `clock` | Board oscillator input |
| `resetButton` | Active-low reset input |
| `inputButtons(0)` | Active-low press toggles MMSS / HHMM view |
| `inputButtons(1)` | Active-low press selects main time / alarm time |
| `inputButtons(2)` | Hold to decrease the selected time |
| `inputButtons(3)` | Hold to increase the selected time |
| `sevenSegments` | Active-low segment outputs; bit 7 is the decimal point |
| `cableSelect` | Active-low selection of one of four digits |
| `buzzer` | Tone gated by the alarm match and the seconds square wave |

The main clock advances while idle and while the alarm is selected.
The alarm value changes only while it is selected and a set button is
held. Setting uses different rates in MMSS and HHMM views. The middle
dot follows the seconds square in MMSS and toggles on its rising edge
in HHMM, halving its frequency. The alarm comparator ignores the
seconds-units digit, so a match spans a ten-second interval rather than
a single second. The current hour digit cascade is not a complete
24-hour rollover implementation; test and repair rollover before using
this as an actual clock.

## Run and read the waveform

From the repo root, using the [installed tools or container](../../../README.md#start-here):

```bash
make -C display/7segments/clock all
```

Open this directory's `build/tb_clock_dot_blink.png` or its `_v`
counterpart. The current CI test instantiates only
[`mode_blink`](../../../building_blocks/mode_blink/), not the full
clock. With a synthetic 200 ns input period, MMSS output has that same
period and HHMM output has a 400 ns period. The assertion counts output
transitions over equal observation windows and requires an exact 2:1
ratio. The netlist renders the full clock, but this leaf test does not
verify digit rollover, button controls, display scanning, or alarm behaviour.

## Try it

**Guided change:** change `SQ_PERIOD` to 400 ns in the two dot-blink
testbenches. Predict output periods of 400 ns and 800 ns while the edge
count ratio stays 2:1. Run `make -C display/7segments/clock test`.

**Challenge:** add a full-top testbench with smaller timer generics.
Observe that exactly one `cableSelect` bit is low during each digit
slot and verify the MMSS carry from 00:59 to 01:00. Add its name and
files to `TB_TOPS` / `TB_FILES` and the Verilog equivalents so `make
test` checks the integration. Extend it to verify 03:59:59 → 04:00:00
and 23:59:59 → 00:00:00, repairing the hour cascade when those checks fail.
