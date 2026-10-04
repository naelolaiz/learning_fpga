# From simulation to a timed FPGA design

Simulation checks behavior under the testbench's inputs. The shared
Yosys flow builds a logical netlist for a diagram. A board build also
needs device fitting and static timing analysis: the routed logic must
meet the clock period and external interface requirements.

Read [clock_enable](../basics/clock_enable/) first. This walkthrough uses
the existing EasyFPGA Cyclone IV blink project and a 50 MHz oscillator.
Quartus Prime Lite with Cyclone IV support is required for the board
steps; it is not included in the simulation container.

## One constrained clock

The blink project now includes [blink_led.sdc](../basics/blink_led/blink_led.sdc)
through its QSF. Its clock requirement is:

```tcl
create_clock -name clk -period 20.000 [get_ports {clk}]
derive_clock_uncertainty
```

50 MHz gives a 20 ns period. This tells the fitter and timing analyzer
when successive register values must arrive; it does not generate a
physical clock. Port names are case-sensitive. See "Creating Base
Clocks" in the *Quartus Prime Standard Edition User Guide: Timing
Analyzer* (document 683068), searchable from the
[Altera documentation portal](https://docs.altera.com/).

The SDC excludes only the LED output from timing: an indicator has no
external clocked receiver with setup/hold requirements. The internal
counter and pulse-register paths remain constrained. For UART, I2S,
VGA or a memory interface, define delays using the actual receiving
device and board requirements instead of copying the LED exception.

## Fit and inspect

From the repository root, with Quartus tools on `PATH`:

```bash
cd basics/blink_led
quartus_sh --flow compile blink_led
quartus_sta -t report_timing.tcl
```

Alternatively, open `blink_led.qpf`, compile, then open Timing Analyzer.
Inspect the Clocks, setup/hold timing and Unconstrained Paths reports.
The Tcl script writes these reports under `output_files/` for its selected
operating condition. It does not iterate all timing corners; inspect the
full compilation's corner reports before concluding that both setup and
hold timing close across the device's specified conditions.

Check the report against these expectations:

- One input clock named `clk` with a 20 ns period.
- Internal register paths have clock constraints and nonnegative setup
  and hold slack at the analyzed operating corners.
- Timing exceptions cover only the intentional LED output path.
- No unexpected unconstrained internal endpoints or extra clocks.

If timing fails, inspect the worst path's launch register, combinational
logic and capture register. Shorten that path or add a pipeline stage,
then rerun both behavioral tests and fitting. A successful simulation
does not measure routed slack or maximum usable clock frequency.

The QSF retains the EasyFPGA pin assignments (`clk` on PIN_23 and `led`
on PIN_87). Select pin locations and I/O standards from your own board's
schematic before adapting the project. These commands have not been
run through Quartus in this repository's open-source CI.

## Buttons, reset and clock domains

An external button can change close to any clock edge. Feed it into a
two-stage synchronizer in the destination clock domain, then debounce
the second stage. The [clock-enable lesson](../basics/clock_enable/)
demonstrates the synchronizer and the
[UART receiver](../comm/uart_rx/uart_rx.v) uses the same pattern.
Debouncing alone is not a metastability treatment.

Do not add a broad false path between the synchronizer stages: their
register-to-register settling time is useful. If an asynchronous input
requires a timing exception, target only its path to the **first**
stage, and check Quartus's synchronizer/metastability reports. A reset
port labeled synchronous must likewise arrive synchronized to `clk`;
an asynchronous reset design needs a deliberate release strategy.

The legacy [clock demo](../display/7segments/clock/) uses timer pulses,
carry outputs and button-selected clock muxes as clocks. A separate
generated clock requires an appropriate clock resource and generated
clock constraints. For these slow counters, the simpler next exercise
is to keep the oscillator as the sole clock and use tick enables for
seconds, display scanning and button actions.

## Exercises

1. Predict which internal paths are checked by the 20 ns constraint;
   find one launch/capture pair in the timing report. Explain why the
   LED false path does not remove the counter feedback path.
2. In a copy of the blink project, request a 10 ns clock period and
   refit. Compare worst setup slack and the reported clock. The board
   oscillator still runs at 50 MHz: changing an SDC does not change it.
3. Refactor one timer-clocked counter to a single oscillator clock and
   enable. Check its behavior in simulation, then verify that its
   clock report contains only the oscillator clock.
