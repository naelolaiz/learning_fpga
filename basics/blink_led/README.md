# Blink led

Smallest possible "the FPGA is alive" example.

A counter clocked from the 50 MHz board clock toggles `led` every
`CLOCKS_TO_OVERFLOW` cycles. With the default `CLOCKS_TO_OVERFLOW =
50_000_000` the led switches state once per second (≈2 s period).

## Generated logic diagram

The synthesised design is exactly two cells: a counter (register fed
by an adder) and a single D flip-flop holding the toggled `pulse`.

![logic diagram](doc/blink_led_diagram.svg)

## Simulation

Automatically generated view from waveview. The testbench overrides
`CLOCKS_TO_OVERFLOW` to `10`, so the led toggles every 200 ns instead
of every second.

![tb simulation signals view](doc/gtkwave_tb_blink_led.png)

## Going further

Want buttons in the picture, or to see what AND/OR/XOR look like as
synthesised cells? See [`basics/glossary`](../glossary) — same shared
inputs (two buttons), every basic combinational primitive on its own
LED, plus the same gate written in three different HDL styles.
