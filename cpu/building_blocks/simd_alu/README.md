Packed SIMD ALU — one of the two MMIO accelerators in
[`cpu/`](../../) (the other is [`fir4tap`](../fir4tap/)). Pure
combinational; the SoC wraps it in MMIO registers so the CPU drives
it via plain `sw` / `lw`.

### Lane shape (op[3])

| op[3] | Lanes |
|---|---|
| `0` | 4 × signed 8-bit, packed into the 32-bit operand |
| `1` | 2 × signed 16-bit, packed into the 32-bit operand |

### Operations (op[2:1])

| op[2:1] | Operation | Saturation honours op[0]? |
|---|---|---|
| `00` | lane-wise `a + b` | yes |
| `01` | lane-wise `a - b` | yes |
| `10` | lane-wise signed `min(a, b)` | no — pick one input, never overflows |
| `11` | lane-wise signed `max(a, b)` | no |

### Saturation (op[0])

| op[0] | Behaviour |
|---|---|
| `0` | Wrap. Truncates to the lane width; signed overflow flips sign (textbook two's-complement). |
| `1` | Saturate. Clamps to `[-2^(W-1), 2^(W-1)-1]` where W is the lane width (8 or 16). |

### Flags

`flags[i]` is high iff lane `i` saturated during this operation. For
4×8-bit mode all 4 bits are valid; for 2×16-bit mode only `flags[1:0]`
are valid (upper bits are 0). `min` / `max` never saturate.

### Why this exists

It's the simplest, most didactic shape of a SIMD accelerator: one
lane-shape knob (`op[3]`), one operation knob (`op[2:1]`), one
saturation knob (`op[0]`). The CPU drives it via memory-mapped
registers — it does NOT modify the CPU core, the decoder, or the
ISA. That's the *coprocessor* pattern used in real silicon
(Hexagon DSP, Cortex-M + NPU blocks, etc.): the host CPU stays
plain; the workload-specific block hangs off the bus.

### Test coverage

`tb_simd_alu` walks twelve golden vectors: every (width × op) pair,
plus the saturation boundary cases (`0x7F + 0x01 → 0x7F sat`,
`-128 + -128 → -128 sat`, …). Same vectors run on both the VHDL and
Verilog twins.
