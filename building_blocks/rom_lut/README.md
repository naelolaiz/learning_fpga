# rom_lut — three ways to store the same lookup table

A 32 × 16 ROM holding precomputed `sin(angle) × nibble` values for the
first quadrant; the wrapping logic mirrors the table around π/2 and
negates across π so a 7-bit angle index covers the full circle. The
output is a 10-bit two's-complement value (sign + 9-bit magnitude).

The interesting part isn't the table — it's that the **same table is
populated three different ways**, all kept in sync by a multi-method
equivalence testbench:

| Method | VHDL                  | Verilog                  | How the data gets into the ROM |
| ------ | --------------------- | ------------------------ | ------------------------------ |
| A      | [`ROM_LUT.vhd`](ROM_LUT.vhd)           | [`rom_lut.v`](rom_lut.v)               | **Inline literal** — every entry written out in the source. |
| B      | [`ROM_LUT_hex.vhd`](ROM_LUT_hex.vhd)   | [`rom_lut_hex.v`](rom_lut_hex.v)       | **External hex file** ([`rom_lut.hex`](rom_lut.hex)) loaded via VHDL `textio` / Verilog `$readmemh`. |
| C      | [`ROM_LUT_func.vhd`](ROM_LUT_func.vhd) | [`rom_lut_func.v`](rom_lut_func.v)     | **Computed** at elaboration from `IEEE.MATH_REAL.SIN` / Verilog `$sin`. |

The synthesis TOP is [`tl_rom_lut`](tl_rom_lut.vhd) which wraps method A
(inline literal), since it's the most portable across synth toolchains.
Methods B and C are simulation-friendly demonstrations — yosys
read_verilog rejects `real`, so method C ships behind a
`// synthesis translate_off` pragma; method B's textio / `$readmemh`
synthesizes cleanly on most flows but isn't the default here.

## Why this exists

> "I did a LUT for the trig multiplications to avoid using all the 9-bit
> multipliers. But I ended up using all the logic cells. So I wanted to
> *force* using memory cells, which needs to be synchronous."

Method A solves the original problem (force BRAM inference instead of
ALMs) by structuring the array initialiser so the synthesiser
recognises it as a ROM. Yosys confirms during synthesis:

```
ROM_LUT.vhd:33:9:note: found ROM "rom", width: 9 bits, depth: 512
```

Methods B and C are about **where the data comes from**, not about the
hardware structure: all three produce a single-port synchronous ROM.
The trade-offs are:

- **A (inline literal)** — auditable, trivial to diff, but bloats the
  source for non-trivial table sizes; tooling-portable.
- **B (external file)** — keeps the source compact and lets a
  preprocessing script (Python, generator, etc.) own the table; both
  languages can read the same file, so a regression in one binding
  shows up immediately.
- **C (compute at elaboration)** — the formula *is* the source of
  truth, no parallel hex artifact to forget to regenerate; depends on
  the simulator/synthesiser supporting real-math at elaboration.

## Test strategy

Two testbenches:

- **`tb_rom_lut`** drives the synthesised wrapper and asserts six
  algebraic properties of the registered output: nibble=0 yields zero
  for any angle, angle=0 yields zero for any nibble, mirror around π/2
  (`out(31, n) == out(32, n)`), anti-symmetry across π
  (`out(k, n) == -out(k+64, n)`), and the +464 / -464 peaks at the
  upper- and lower-half maxima. Same shape in VHDL and Verilog.

- **`tb_rom_lut_methods`** instantiates all three methods in parallel,
  drives the entire 7+4-bit address space (2048 reads), and asserts
  bit-identical outputs at every step. Both flows print
  `all three methods agree on every address` on success.

## Hex-file format

[`rom_lut.hex`](rom_lut.hex) is shared between the VHDL and Verilog
method-B variants — same file, same data, two different parsers. 32
lines of 16 three-digit hex tokens (only the lower 9 bits are
significant). Verilog-style `//` line comments are skipped by both
loaders (`$readmemh` recognises them natively; the VHDL function
filters them before calling `hread`).

## See also

- [`generate_tables.py`](generate_tables.py) — the original Python
  script the literal table was computed from; method C reproduces the
  same formula in HDL.
- [`old_generic/`](old_generic/) — the historical predecessor that
  used a single hex file (`MY_ROM.hex`) for a flat 32-element table,
  before the multiplication tables were added.
