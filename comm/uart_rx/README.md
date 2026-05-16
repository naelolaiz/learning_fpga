# uart_rx — 8N1 UART receiver

Companion to [`comm/uart_tx/`](../uart_tx/). Watches the `rx` line for
a start-bit edge, captures the eight data bits LSB-first at their
centres, checks the stop bit, and pulses `rx_valid` for one clock
with the captured byte on `rx_data`. The line idles high; bytes are
silently dropped if the stop bit is low (framing error).

This is the receive half of the UART that the upcoming RV32I SoC will
expose as a memory-mapped peripheral, alongside the transmit half
that already exists in `uart_tx/`.

| File | Purpose |
| ---- | ------- |
| [`uart_rx.vhd`](uart_rx.vhd) | VHDL design |
| [`uart_rx.v`](uart_rx.v) | Verilog mirror |
| [`test/tb_uart_rx.vhd`](test/tb_uart_rx.vhd), [`test/tb_uart_rx.v`](test/tb_uart_rx.v) | Self-checking testbenches (bit-banged frames) |

## Generic

| Name | Default | Meaning |
| ---- | ------- | ------- |
| `CLKS_PER_BIT` | 5208 | Clocks per bit time (default = 50 MHz / 9600 baud) |

Pair this with `uart_tx`'s `CLKS_PER_BIT` for matched-baud loopback.

## Two robustness details

**Two-stage synchroniser.** `rx` is asynchronous to `clk`. Sampling
it directly would occasionally land in a flip-flop's metastable
window, and the start-bit edge detector would catch glitches. The
two-stage synchroniser (rx → rx_sync1 → rx_sync2 → FSM) costs two
clocks of latency, which at 50 MHz / 9600 baud is ~0.04% of one bit
time — invisible against the bit-time tolerance every UART builds
in. Synthesisers recognise this pattern and apply tighter timing
constraints to the synchroniser FFs.

**Three-tap majority sampler at every bit centre.** We keep a rolling
three-deep window of the synchronised line and, at the centre of
each bit, take the majority vote of the three samples around it. A
single noise glitch ±1 clock from the centre can't flip the
captured bit. The vote is the classic two-of-three decoder:

```
maj3(v) = (v[0] & v[1]) | (v[0] & v[2]) | (v[1] & v[2])
```

This same `maj3` is applied at the start-bit centre (rejecting brief
spurious lows that don't represent a real frame), at each of the
eight data-bit centres, and at the stop-bit centre.

## Framing handling

If the stop bit isn't a clean high at its centre (majority of the
window is `0`), the FSM returns to `S_IDLE` without pulsing
`rx_valid` — the byte is silently dropped. The testbench's last
scenario exercises this path: a frame with `stop_bv := '0'` must
NOT advance the valid-pulse count.

If you need an explicit framing-error indication for a particular
consumer, a future revision can add a `framing_err` output without
changing the existing port contract.

## Test strategy

A short `send_byte` task/procedure in each testbench bit-bangs a
full 8N1 frame at the configured `CLKS_PER_BIT`: a start bit, eight
data bits LSB-first, then a stop bit (which the caller can force
low to construct a framing error). The testbench drives four frames
back-to-back through the DUT and checks each one:

```
  0xA5  alternating pattern — exercises every 1↔0 data-bit transition
  0x00  all-zero data — proves the FSM doesn't treat the long
        zero window as a stretched start bit
  0xFF  all-one data — proves the stop-bit centre check still fires
  0x5A  with stop forced low — framing error, rx_valid must NOT pulse
```

A `watcher` block (process / `always` block) latches `rx_data` and
increments a pulse counter every time `rx_valid` fires; the asserts
compare the captured byte and the running pulse count against
expectations after each frame.
