# PWM LED

Learn how a counter and comparator encode a duty cycle as a pulse train.
Prerequisites: [blink LED](../blink_led/) and
[combinational versus sequential logic](../logic_styles/).

## Interface and timing

| Name | Meaning |
| --- | --- |
| `WIDTH` | Counter and duty width; default 8 |
| `clk` | Rising-edge clock |
| `duty` | Unsigned number of high clock intervals per PWM period |
| `pwm_out` | High when the current counter value is below `duty` |

The counter starts at zero and wraps every `2^WIDTH` clocks. For a duty
value held constant throughout a period:

```text
PWM frequency = f_clk / 2^WIDTH
high fraction = duty / 2^WIDTH
```

At `WIDTH=8`, duty 0 is always low, 128 is 50%, and 255 is **255/256**
high; the maximum value still has one low clock interval. At 50 MHz,
the period is 5.12 µs. There is no reset port. `duty` feeds the
comparator directly, so changing it mid-period changes the output
immediately; it is not latched at the period boundary. The high fraction
describes electrical duty, not a linear relationship with perceived brightness.

## Run and read the waveform

From the repo root, using the [installed tools or container](../../README.md#start-here):

```bash
make -C basics/pwm_led all
```

Open `build/tb_pwm_led.png` in this directory; the Verilog version is
`build/tb_pwm_led_v.png`. Each `sDuty` step changes the high portion of
`sPwm`. The testbenches count high samples over a complete 256-clock
window for duties 0, 32, 64, …, 224, and 255, and assert that the count
equals the selected duty. Compare the netlist's counter register,
adder, and comparator with the blink lesson.

## Try it

**Guided change:** set `WIDTH=4` in both testbenches, sweep all duties
0–15 (remove the condition that selects multiples of 32), and measure
16 clocks per window. Duty 8 must produce exactly
eight high samples. Run `make -C basics/pwm_led test` to check both versions.

**Challenge:** add a registered duty value that updates only when the
counter wraps. Change the input halfway through a period and assert
that the current period retains its old high count and the next uses
the new one. Keep the VHDL and Verilog behaviours equal.
