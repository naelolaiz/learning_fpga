# UART transmitter

Learn how a state machine turns a byte into an 8N1 serial frame.
Prerequisites: [shift register](../../building_blocks/shift_register/)
and [clocked logic](../../basics/logic_styles/). Continue with
[UART RX](../uart_rx/) for reception and loopback.

## Interface and timing

| Name | Meaning |
| --- | --- |
| `CLKS_PER_BIT` | Clock intervals per serial bit; positive integer, default 5208 |
| `clk` | Rising-edge clock |
| `tx_start`, `tx_data` | Capture the byte on an idle edge with `tx_start=1` |
| `tx` | Serial output, idle high |
| `tx_busy` | High while a frame is being transmitted |

The frame is one low start bit, eight data bits **LSB first**, then one
high stop bit. Each serial bit lasts `CLKS_PER_BIT` clock intervals:
`baud = f_clk / CLKS_PER_BIT`. With a 50 MHz clock, 5208 approximates
9600 baud and 434 approximates 115200 baud.

An accepted request makes `tx_busy` high; the start bit begins on the
following rising edge. Requests while busy are ignored, and changes to
`tx_data` cannot change the captured frame. Pulse `tx_start` for one
clock; holding it high can request another frame once the transmitter
returns idle. There is no reset port; the declared initial state is idle.

## Run and read the waveform

From the repo root, using the [installed tools or container](../../README.md#start-here):

```bash
make -C comm/uart_tx all
```

Open `build/tb_uart_tx.png` here or its `_v` counterpart. The test uses
eight clocks per bit and a 20 ns clock, so each bit lasts 160 ns. For
byte `A5`, look for:

```text
idle | start | data bits in time order | stop
  1  |   0   | 1 0 1 0 0 1 0 1      |  1
```

The testbenches sample bit centres and assert idle, start, stop, and the
recovered byte. They send one frame; busy-request rejection and repeated
frames require additional tests.

## Try it

**Guided change:** send `3C` instead of `A5` in both tests. Predict the
bit order `0 0 1 1 1 1 0 0`; assert the receiver reconstructs `3C` and
run `make -C comm/uart_tx test`.

**Challenge:** instantiate [UART RX](../uart_rx/) with the same bit
timing and connect `tx` to `rx`. Send `00`, `A5`, and `FF`, waiting for
idle before each request. Assert exactly three receive-valid pulses
and the three bytes in order. Use a comfortably larger bit divisor,
such as 32, to accommodate receiver synchronisation latency.
