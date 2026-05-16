4-tap streaming FIR filter — the DSP-flavoured counterpart to
[`simd_alu`](../simd_alu/). Each new sample produces a new filtered
output two cycles later. The SoC integration in F1c hangs this
behind a small MMIO interface so the CPU streams audio samples via
plain `sw` writes.

### Data widths

| Signal | Width | Format |
|---|---|---|
| `sample_in`  | 16-bit signed | Typical audio sample |
| `coeff_<i>`  | 9-bit signed  | Q1.8 — `256` represents +1.0; range ≈ [-1, +1) |
| `result`     | 16-bit signed | Integer domain: `(sample × coeff_int) / 256` |

The 9-bit coefficient width matches the Cyclone IV hard 9×9 multiplier
exactly — one DSP block per tap, no chained-multiplier overhead.

### Why Q1.8 coefficients

A FIR with coefficients that sum to 256 has **unity gain on a DC
input**: the filter passes a constant signal unchanged, which is the
intuitive design point. Set coefficients so their integer sum is 256
and the input/output scales match without extra rescaling.

### Timing

```
clk:        __|‾‾|__|‾‾|__|‾‾|__|‾‾|__
sample_valid: __|‾‾|_________________________
sample_in:    [data]
                      ↑
                  shift in, MAC computing
                              ↑
                          result_valid pulses (one clock)
```

Two-cycle latency between `sample_valid` and `result_valid`.
`result_valid` is exactly one clock wide per `sample_valid` pulse.

### Internal pipeline

1. **Sample shift register** (4 stages): on `sample_valid`, the new
   sample lands in `samples[0]` and older samples shift one deeper.
2. **Combinational MAC**: four signed 16×9 products, summed into a
   27-bit signed accumulator (4 products of 25 bits + 2 bits of
   sum headroom).
3. **Output register**: slices `mac_sum[23:8]` (= MAC >> 8) into a
   16-bit signed result. The user is responsible for keeping the
   sum within ±32767; for audio with |coeffs| summing to ≤ 256 and
   full-scale samples, that's automatically true.

### Coefficient range note

9-bit signed reaches `[-256, +255]`. In Q1.8 that's a range of
`[-1.0, +0.996)` — exactly `+1.0` is one bin short. For tutorial
demos this matters: an "impulse" filter would want a coefficient
of `256` for a perfect 1.0 passthrough, but `256` doesn't fit.
The `tb_fir4tap` tests use `128` (= +0.5) instead, sidestepping
the boundary; the BOX AVERAGE uses `64 + 64 + 64 + 64 = 256`
which **does** fit because the sum is what represents +1.0,
not any single coefficient.

### Two test scenarios

| Test | Coefficients | Behaviour |
|---|---|---|
| **Halving passthrough** | `{128, 0, 0, 0}` | `stream(N) → result(N / 2)`. Demos a single-tap gain control. |
| **Box average** | `{64, 64, 64, 64}` | Output = mean of the 4 most recent samples. `stream(100,100,100,100) → 100`. |

`tb_fir4tap` walks both, including the partial-fill phase of the
box average (`stream(100)` once → `result = 25`, since 3 of 4 history
slots are still zero).
