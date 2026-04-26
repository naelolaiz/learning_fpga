4-digit hex display of an on-chip random number.

A slow gating divider pulses the random source's enable input high
for a short window every ~140 ms. New random bytes are shifted into
a 16-bit register on each `valid` strobe while the gate is open;
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
