# I2C master

Learn how two open-drain wires carry addressed, acknowledged bytes,
and how a state machine builds START, data bits, ACK and STOP out of
quarter-period steps. Prerequisites: [UART TX](../uart_tx/) for serial
state machines and [clock enable](../../basics/clock_enable/) for the
two-stage input synchroniser. Continue with [uda1380](../uda1380/),
which uses this master to boot an audio codec.

## The bus in one paragraph

SCL (clock) and SDA (data) are pulled high by resistors; a device can
only pull a line low or let go. SDA changes while SCL is low and is
read while SCL is high. The two exceptions frame a transfer: SDA
falling while SCL is high is a **START**, SDA rising while SCL is high
is a **STOP**. Every byte is eight bits MSB first plus a ninth
**acknowledge** bit driven by the receiver: low means ACK, high (nobody
pulled) means NACK. The first byte after a START is the 7-bit address
and a read/write bit.

## Interface and timing

| Name | Meaning |
| --- | --- |
| `CLKS_PER_QUARTER` | Clock cycles per quarter of an SCL period; integer ≥ 2, default 125 |
| `clk`, `rst` | Rising-edge clock; synchronous, active-high reset |
| `cmd_valid`, `cmd_ready` | A command is accepted on an edge where both are high |
| `cmd_start` | Send a START (or a repeated START) before the byte |
| `cmd_stop` | Send a STOP after the byte's acknowledge bit |
| `cmd_read` | `0` write `cmd_wdata`, `1` read a byte |
| `cmd_nack` | Reads only: answer the byte with NACK instead of ACK |
| `rsp_valid` | One-clock pulse when the byte and its acknowledge bit are done |
| `rsp_rdata` | The eight bits as seen on SDA (a write reads back its own byte) |
| `rsp_nack` | The acknowledge bit: `1` means not acknowledged |
| `busy` | High from the START until the STOP has completed |
| `scl_oe`, `sda_oe` | `1` pulls the line low, `0` releases it |
| `scl_i`, `sda_i` | The line read back |

One command is one byte on the bus. The address is not special: it is
the first byte written after a START. Writing two bytes to register
`0x10` of the device at `0x50`, then reading them back:

| `cmd_start` | `cmd_stop` | `cmd_read` | `cmd_nack` | `cmd_wdata` | On the bus |
| :-: | :-: | :-: | :-: | :-: | --- |
| 1 | 0 | 0 | – | `A0` | START, address `0x50` + write |
| 0 | 0 | 0 | – | `10` | register pointer |
| 0 | 0 | 0 | – | `A5` | first data byte |
| 0 | 1 | 0 | – | `3C` | second data byte, STOP |
| 1 | 0 | 0 | – | `A0` | START, address + write |
| 0 | 0 | 0 | – | `10` | register pointer |
| 1 | 0 | 0 | – | `A1` | repeated START, address + read |
| 0 | 0 | 1 | 0 | – | read, master ACKs: more to come |
| 0 | 1 | 1 | 1 | – | read, master NACKs: last byte, STOP |

`cmd_ready` is high while the bus is free and between bytes of an open
transfer, where the master holds SCL low for as long as it takes the
next command to arrive. From a free bus a START is always sent, so
`cmd_start` only matters between bytes. The master reports NACKs but
does not act on them: after a NACK, end the transfer with a command
that has `cmd_stop` set. The last byte of a read must be answered with
`cmd_nack`, otherwise the slave keeps driving SDA and the STOP cannot
form.

Each bit takes four quarters: SCL low with SDA holding the previous
bit, SCL low with the new bit on SDA, then two quarters of SCL high
with SDA sampled between them. START, STOP and the bus-free gap each
hold their levels for two quarters.

`scl_i` and `sda_i` pass through two flip-flops. Whenever the master
has released SCL but still reads it low, the quarter timer waits —
that is how a slave **stretches** the clock. It also means the
master's own SCL rise costs two extra clocks per period:
`f_SCL = f_clk / (4 × CLKS_PER_QUARTER + 2)`, which is 99.6 kHz for
the default at 50 MHz. SCL low lasts `2 × CLKS_PER_QUARTER` clocks.
The default meets the standard-mode (100 kHz) minimums. Fast mode
needs SCL low for at least 1.3 µs, which a symmetric 400 kHz clock
misses; at 50 MHz use `CLKS_PER_QUARTER = 33` (373 kHz).

There is no timeout: a line stuck low stalls the master until `rst`.
Reset releases both lines immediately, without sending a STOP.

## Run and read the waveform

From the repo root, using the [installed tools or container](../../README.md#start-here):

```bash
make -C comm/i2c_master all
```

Open `build/tb_i2c_master.png` here or its `_v` counterpart. The image
zooms on the first transfer (the four-command write from the table
above); the test uses four clocks per quarter, so one SCL period is
360 ns. Look for:

- `sSda` falling while `sScl` is still high at the far left (the
  START), and rising while `sScl` is high near 13.7 µs (the STOP);
- nine SCL pulses per byte, with `sSlaveSdaOe` high during each ninth
  pulse — the slave's ACK;
- `shreg` shifting left by one bit per SCL pulse, from `a0` for the
  address byte;
- `stretching` pulsing for two clocks at every SCL rise: the master
  waiting for its own release to come back through the synchroniser.

(The VHDL image shows the testbench names in lower case.)

The rest of the run is in `build/tb_i2c_master.fst`. The testbench
connects the master to a behavioural slave
([`test/i2c_slave_model`](test/)) that answers at one address, stores
written bytes behind a pointer, and returns them on reads. It asserts:

- the write is acknowledged byte by byte and framed by exactly one
  START and one STOP;
- the read-back through a repeated START returns both bytes, with the
  master's ACK after the first and NACK after the last;
- a transfer to an address nobody answers reports `rsp_nack` and still
  ends with a STOP;
- with the slave stretching SCL before every acknowledge bit, a write
  and its read-back still succeed, and SCL is low for the stretch
  length once per byte;
- no SCL high or low is ever shorter than two quarters.

START and STOP are the only SDA edges while SCL is high, so the START
and STOP totals also show that data never changed during SCL high. Not
covered: reset in the middle of a transfer, a stuck bus, a second
master, and the analogue timings of a real bus (rise times, the
setup and hold figures in the specification).

## Try it

**Guided change:** set `CLKS_PER_QUARTER` to 8 in both testbenches.
Predict the new SCL period from the formula above — (4 × 8 + 2) × 20 ns
= 680 ns — and whether any assertion has to change. Run
`make -C comm/i2c_master test`: it still passes, because every check
is written in quarters, not nanoseconds. Measure the period in the
FST to confirm the prediction.

**Challenge:** add a way to end a transfer without sending another
byte, for example a `cmd_skip` flag that makes a command with
`cmd_stop` go straight to the STOP. Extend the unanswered-address test
to send the address *without* `cmd_stop`, then the bare STOP. Assert
that `rsp_nack` is high, that the STOP count still goes up by one, and
that SCL pulsed exactly nine times for that transfer.

## Further reading

- NXP UM10204, *I2C-bus specification and user manual* — the timing
  tables behind the numbers above.
- The codec boot sequence in [uda1380](../uda1380/) for a design that
  drives this interface from a table.
