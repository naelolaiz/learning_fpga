# uda1380 — codec init over I2C + I2S playback

Brings the Waveshare UDA1380 codec board up from cold reset using
nothing but the dev-board's 50 MHz clock: a state machine writes the
required boot register sequence over I2C, the I2S master streams a
half-scale square wave at 96 kHz Fs, and the codec drives the
headphone jack.

## Files

| File | Role |
| ---- | ---- |
| [`uda1380_control_definitions.vhd`](uda1380_control_definitions.vhd) | UDA1380 register map: addresses, bit-field record types per register, and a set of pre-baked `INIT_*` constants of `I2C_COMMAND_TYPE` that encode the boot sequence. |
| [`uda1380_init_fsm.{vhd,v}`](uda1380_init_fsm.vhd) | State machine that walks the `INIT_*` table and hands the I2C master one byte at a time: address, register, data high, data low. |
| [`../i2c_master/i2c_master.{vhd,v}`](../i2c_master/) | The I2C master from the [`comm/i2c_master`](../i2c_master/) lesson, used here as is. |
| [`i2s_master.{vhd,v}`](i2s_master.vhd) | I2S transmitter (MCLK / LRCLK / BCK / SDATA generator), shared with [`comm/i2s_test_1`](../i2s_test_1/). |
| [`tone_gen.{vhd,v}`](tone_gen.vhd) | Half-scale square-wave audio source so the codec actually has something to play once initialised. |
| [`top_level_uda1380_core.{vhd,v}`](top_level_uda1380_core.vhd) | All of the logic: init-FSM + I2C master + I2S master + tone-gen. Active-low reset. The I2C bus is exposed as `(scl_oe, scl_i, sda_oe, sda_i)` — no `inout` anywhere, so it simulates with plain levels and `netlistsvg` accepts the netlist. |
| [`top_level_uda1380.{vhd,v}`](top_level_uda1380.vhd) | Board top: wraps the core and turns each `(oe, i)` pair into one open-drain `i2cIO*` pin. |
| [`test/`](test/) | Unit testbench for the init FSM (asserts how each write is framed), integration testbench for the core (checks every byte the codec receives on the bus, plus MCLK / BCK / LRCLK activity) and a board-top testbench on a pulled-up `inout` bus. All in VHDL and Verilog. |

## The boot sequence

The codec needs ~15 register writes after power-up before it can play
audio: power on, configure clocks, set the I2S frame format, unmute,
set volumes. Encoded as a table in
[`uda1380_init_fsm.vhd`](uda1380_init_fsm.vhd) using the constants
from [`uda1380_control_definitions.vhd`](uda1380_control_definitions.vhd):

| # | Register (hex addr)        | Effect |
| - | -------------------------- | ------ |
|  1 | `7F` L3                    | Reset L3 settings |
|  2 | `02` PWR_CTRL              | Power on PLL / DAC / HP / bias / AVC / LNA / PGA / ADC |
|  3 | `00` EVALCLK               | Enable WSPLL + ADC/DEC/DAC/INT clocks, 256·Fs system divider |
|  4 | `01` I2S                   | I2S bus format, digital-mixer source, BCK0 = slave |
|  5 | `03` ANAMIX                | Analog mixer left/right gain |
|  6 | `04` HEADAMP               | Headphone driver short-circuit protection on |
|  7 | `10` MSTRVOL               | Master volume = 0 dB (full) |
|  8 | `11` MIXVOL                | Mixer volume = 0 dB on both channels |
|  9 | `12` MODEBBT               | Mode flat, treble / bass-boost defaults |
| 10 | `13` MSTRMUTE              | Master & per-channel mute off, no de-emphasis |
| 11 | `14` MIXSDO                | Digital mixer / silence-detect off |
| 12 | `20` DECVOL                | Decimator volume = max |
| 13 | `21` PGA                   | PGA: no mute, full gain |
| 14 | `22` ADC                   | Line-in + mic, max mic gain |
| 15 | `23` AGC                   | AGC: settings register, AGC disabled |

Each row is one I2C transaction: `START | (DEVICE_ADDR<<1)|W | reg_addr | data_hi | data_lo | STOP`,
which the FSM expresses as four commands to the
[I2C master](../i2c_master/), one per byte: `cmd_start` on the address
byte, `cmd_stop` on `data_lo`. The FSM holds `cmd_valid` high and
steps to the next byte whenever the master reports `cmd_ready`.

## Documentation references

Local copies (in [`docs/`](docs/)):

- [`docs/UDA1380.pdf`](docs/UDA1380.pdf) — chip datasheet. The
  boot-sequence register choices above come from §"L3 interface and
  control register description" / "Power management" / "Clock
  generation".
- [`docs/UDA1380-Board-Schematic.pdf`](docs/UDA1380-Board-Schematic.pdf)
  — Waveshare board schematic; gives the FPGA-pin / codec-pin mapping
  including the I2C address pin tying.
- [`docs/UDA1380-Board-Code.7z`](docs/UDA1380-Board-Code.7z) —
  Waveshare reference code for LPC1768 / STM32F2xx, useful as a
  cross-check for which registers their driver writes and in what
  order.
- [`docs/board.jpg`](docs/board.jpg),
  [`docs/board_pinout.jpg`](docs/board_pinout.jpg) — board photos.

External:

- Waveshare UDA1380 board wiki: <https://www.waveshare.com/wiki/UDA1380_Board>
  (the same source as the local copies above).

Other I2C masters to read alongside this one:

- DigiKey TechForum, [I2C Master (VHDL)](https://forum.digikey.com/t/i2c-master-vhdl/12797)
  — a step-by-step write-up with transaction timing diagrams.
- OpenCores [`i2c_master_slave`](https://opencores.org/projects/i2c_master_slave)
  (VHDL, BSD) — master and slave in one core, with burst transfers.
- OpenCores [`i2c_master_slave_core`](https://opencores.org/projects/i2c_master_slave_core)
  (Verilog) — Wishbone-attached master / slave.
- OpenCores [`iicmb`](https://opencores.org/projects/iicmb) (VHDL, BSD)
  — one controller driving several I2C buses.

## Wiring (RZ EasyFPGA A2.2 → UDA1380 board)

| FPGA port (entity) | UDA1380 pin | Notes |
| ------------------ | ----------- | ----- |
| `iClk`             | —           | 50 MHz from on-board oscillator. |
| `iNoReset`         | —           | Active-low reset. Tie high (or to a debounced button) for normal operation. |
| `i2cIOScl`         | SCL         | Open-drain. The board has 4.7 kΩ pull-ups; no FPGA-side pull-up needed. |
| `i2cIOSda`         | SDA         | Open-drain. Same pull-up note. |
| `oTxMasterClock`   | SYSCLK      | 24.576 MHz nominal (256 × 96 kHz Fs). |
| `oTxBitClock`      | BCK0        | Bit clock; UDA1380 configured as I2S slave on BCK0. |
| `oTxWordSelectClock` | WSI / LRCK | Word-select / sample-rate clock. |
| `oTxSerialData`    | DATAI       | 24-bit MSB-first audio data. |
| `oInitDone`        | LED (any)   | Goes high after the FSM finishes the boot sequence. |

Power, ground, and the headphone jack come from the Waveshare board
itself; nothing else from the FPGA goes to the codec.

## Building locally

```bash
make simulate     # VHDL flow: FSM, core and board-top testbenches
make simulate_v   # Verilog flow: same three TBs
make all          # both flows + waveform PNGs
```

Or, the same container CI uses:

```bash
podman run --rm -v "$PWD":/work:rw -w /work \
    ghcr.io/naelolaiz/hdltools@sha256:a661d7b9a126fbb44e64d542a19edb9cf1ff7cf70dcf714150a5b03edd2ae312 \
    make all
```

## Testbenches

[`test/tb_uda1380_init_fsm.{vhd,v}`](test/) is the unit TB for the
boot FSM. It stubs the I2C master's command handshake (`cmd_ready`,
`i2c_busy`) and asserts:

- the first byte of every write carries `cmd_start` and is
  `DEVICE_ADDR` (= `0x18`) with the write bit,
- the fourth byte carries `cmd_stop`, and the two in between carry
  neither flag,
- 15 register writes × 4 bytes = 60 bytes are handed over,
- `init_done` rises, and only once the bus is idle again.

[`test/tb_top_level_uda1380.{vhd,v}`](test/) is the integration test.
It overrides the generics so the boot finishes in microseconds
(`INIT_DELAY_CYCLES=4`, `I2C_BUS_FREQ=5_000_000`) and puts the
[behavioural I2C slave](../i2c_master/test/) on the bus in place of
the codec, answering at `DEVICE_ADDR`. It asserts:

- all 45 bytes the codec receives (register, data high, data low for
  each write) match the expected stream, in order,
- the bus saw exactly 15 STARTs and 15 STOPs and is released at the
  end,
- MCLK / BCK / LRCLK toggle and `init_done` rises.

Both languages are checked against the same expected stream, which is
what ties the VHDL `INIT_*` records and the Verilog hex table to each
other. The slave acknowledges every byte; what the design does when a
byte is *not* acknowledged is not tested (see the caveats).

[`test/tb_top_level_uda1380_board.{vhd,v}`](test/) runs the board top,
`top_level_uda1380`, with SCL and SDA as single pulled-up `inout`
wires shared with the same slave model. It covers the two open-drain
pins the wrapper adds:

- neither line ever shows contention (a device driving it high while
  another pulls it low),
- the boot completes and the codec receives all 45 bytes in 15 framed
  writes,
- both lines rest on the pull-ups before and after.

It renders no waveform: a line resting on a pull-up is a weak level,
which the waveform check would flag. The same traffic is drawn with
plain levels by `tb_top_level_uda1380`.

## Caveats / what's not here

- **Hardware verification** is the user's bench, not the simulator's.
  This PR brings the codec from "won't initialise at all" to "FSM
  walks the boot sequence and the wires move". Confirming a 500 Hz
  tone at the headphone jack still needs an actual board.
- **Rx (codec ADC → FPGA) path** is not implemented. The MCLK / LRCLK
  / BCK we generate would feed the ADC clocks too if wired; the
  serial-data input pin (DOUT on the codec → input on the FPGA) and
  an `i2s_slave` block would be needed to capture audio.
- **Missing acknowledges are ignored.** The I2C master reports each
  byte's acknowledge bit on `rsp_nack`, but the core leaves it
  unconnected and `uda1380_init_fsm` sends all four bytes of every
  write regardless. With no codec on the bus the boot still "completes"
  and `oInitDone` rises. A field-grade driver would surface this on a
  status pin or retry; for a tutorial the sim-friendly behaviour is the
  right trade.

## Repo notes

- **Two top-levels by design.**
  [`top_level_uda1380_core`](top_level_uda1380_core.vhd) holds all of
  the logic and exposes the I2C bus as `(scl_oe, scl_i, sda_oe,
  sda_i)`. It is the diagram top and what the byte-level testbench
  drives: `netlistsvg`'s JSON schema only accepts `input` / `output`
  port directions, and a bus without `inout` simulates with plain
  `'0'` / `'1'` levels. [`top_level_uda1380`](top_level_uda1380.vhd) is
  the board top: a thin wrapper that turns each `(oe, i)` pair into one
  open-drain pin, simulated on a pulled-up bus by
  `tb_top_level_uda1380_board`. The Verilog
  wrapper is hidden from yosys with `` `ifndef YOSYS ``, since yosys
  has limited tri-state support and the diagram only needs the core.
- `i2c_master.{vhd,v}` is not copied into this project: the Makefile
  lists it from [`comm/i2c_master`](../i2c_master/), the same way the
  CPU projects pull in their building blocks.
- `i2s_master.{vhd,v}` is duplicated from
  [`comm/i2s_test_1`](../i2s_test_1/) so each project stays
  self-contained. Sharing across projects is a future cleanup.
