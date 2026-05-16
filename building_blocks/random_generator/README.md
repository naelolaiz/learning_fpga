On-chip random number generator, viewed on a 4-digit 7-segment.

A slow gating divider pulses the generator's enable input high for
a short window every ~140 ms. New random bytes are shifted into a
16-bit register on each `valid` strobe while the gate is open;
between pulses the displayed value is stable.

`inputButtons[0]` is wired as an active-low freeze: hold to keep
the displayed value steady.

### VHDL vs Verilog

The two language implementations use different random sources:

- **VHDL** uses [`neoTRNG`](neoTRNG.vhd) — a chaotic ring-oscillator
  generator (Stephan Nolting, BSD-3) that produces real entropy on
  hardware. The `IS_SIM` generic switches it to neoTRNG's built-in
  LFSR fallback for deterministic simulation.
- **Verilog** uses a simple 16-bit Galois LFSR ([`lfsr.v`](lfsr.v)),
  in both simulation and on hardware. Same visible behaviour on the
  display; pedagogically simpler.

### Expected yosys warnings (not a bug)

When this project is synthesised, yosys prints many lines of:

    Warning: found logic loop in module neotrng_cell_…

**These warnings are intentional and correct.** A true RNG ring
oscillator IS a combinational loop by definition — that's exactly how
it generates entropy. Each `neoTRNG_cell` instance produces one warning
per inverter in its ring; with three cells of sizes 5, 7, and 9
inverters, the total adds up to a couple of dozen warnings repeated for
each yosys pass.

The design specifically prevents synthesis tools from optimising the
loops away (each inverter is gated by an individually-controlled enable
from a shift register, so they are not "logically identical"). The
loops survive into the netlist on real silicon — that's the entire
point. The warnings only confirm the synth tool noticed what we built.

If you want a clean log (e.g. for a derivative project that doesn't
need true RNG entropy), instantiate `neoTRNG` with `IS_SIM => true`,
which substitutes the deterministic LFSR fallback and removes the
ring oscillators entirely. Do NOT do this on real hardware — the
LFSR is for simulation only and is not cryptographic.
