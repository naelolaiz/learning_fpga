# Shift register

Learn how parallel loading and serial shifting change a vector register
on clock edges. Prerequisites: [blink LED](../../basics/blink_led/) and
[logic styles](../../basics/logic_styles/).

## Interface and timing

| Name | Meaning |
| --- | --- |
| `WIDTH` | Register width; default 8; use at least 2 with this implementation |
| `clk` | Rising-edge clock |
| `load`, `load_data` | Capture the parallel word when `load=1` |
| `serial_in` | New least-significant bit when `load=0` |
| `parallel_out` | Current register contents |
| `serial_out` | Current most-significant bit |

The register starts at zero. Loading has priority over shifting. Every
rising edge with `load=0` shifts toward the MSB, discards the old MSB,
and inserts `serial_in` at bit 0. There is no hold enable or reset port.
`serial_out` shows the **current** MSB; sample it before an edge if you
want the bit being shifted out at that edge.

## Run and read the waveform

From the repo root, using the [installed tools or container](../../README.md#start-here):

```bash
make -C building_blocks/shift_register all
```

Open this directory's `build/tb_shift_register.png` or its `_v` counterpart.
The test loads `A5`, then inserts bits 1, 0, 1:

| Action | `parallel_out` after the edge | Current `serial_out` |
| --- | --- | --- |
| Load `A5` | `10100101` (`A5`) | 1 |
| Shift in 1 | `01001011` (`4B`) | 0 |
| Shift in 0 | `10010110` (`96`) | 1 |
| Shift in 1 | `00101101` (`2D`) | 0 |

The testbenches assert the loaded word, final `2D`, and final serial
output 0. Stimulus changes on falling edges so inputs are stable at
the rising edges that capture them.

## Try it

**Guided change:** replace the loaded word with `3C` in both tests.
With the same three inserted bits, predict and assert intermediate
values `79`, `F2`, and `E5`; final `serial_out` must be 1. Run
`make -C building_blocks/shift_register test`.

**Challenge:** add an `enable` input. Preserve load priority, then shift
only when enabled. Assert that the word stays unchanged for three
disabled cycles and resumes shifting on the next enabled edge.
