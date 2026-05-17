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
| [`uda1380_init_fsm.{vhd,v}`](uda1380_init_fsm.vhd) | State machine that walks the `INIT_*` table and drives the I2C master one 3-byte register write at a time. |
| [`i2c_master.{vhd,v}`](i2c_master.vhd) | Generic bit-banged I2C master (open-drain SCL/SDA with start/stop/ack handling). VHDL is the Digi-Key reference design, see header in the file. |
| [`i2s_master.{vhd,v}`](i2s_master.vhd) | I2S transmitter (MCLK / LRCLK / BCK / SDATA generator), shared with [`comm/i2s_test_1`](../i2s_test_1/). |
| [`tone_gen.{vhd,v}`](tone_gen.vhd) | Half-scale square-wave audio source so the codec actually has something to play once initialised. |
| [`top_level_uda1380.{vhd,v}`](top_level_uda1380.vhd) | Simulation top: wires init-FSM + I2C master (inout flavour) + I2S master + tone-gen. Active-low reset, open-drain `i2cIO*` lines. |
| [`top_level_uda1380_core.{vhd,v}`](top_level_uda1380_core.vhd) | Diagram-renderable variant of the top. Uses `i2c_master_for_diagram` and exposes the I2C bus as `(scl_oe, scl_i, sda_oe, sda_i)` — no `inout` ports anywhere, so `netlistsvg` accepts the netlist. |
| [`i2c_master_for_diagram.{vhd,v}`](i2c_master_for_diagram.vhd) | Same logic as `i2c_master.{vhd,v}` but with the `inout` SDA/SCL ports split into `(*_oe, *_i)`. Used only by `top_level_uda1380_core`. |
| [`test/`](test/) | Unit testbench for the init FSM (asserts byte count + addressing) and integration testbench for the top-level (smoke-tests SCL / MCLK / BCK / LRCLK activity). Both VHDL and Verilog mirrors. |

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
which the FSM expresses as three sequential calls to the I2C master
with `ena` held high across the bytes (the master only inserts a STOP
when `ena` drops).

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
make simulate     # VHDL flow: tb_uda1380_init_fsm + tb_top_level_uda1380
make simulate_v   # Verilog flow: same two TBs
make all          # both flows + waveform PNGs
```

Or, the same container CI uses:

```bash
podman run --rm -v "$PWD":/work:rw -w /work \
    ghcr.io/naelolaiz/hdltools:netlistsvg-hierarchy \
    make all
```

## Testbenches

[`test/tb_uda1380_init_fsm.{vhd,v}`](test/) is the unit TB for the
boot FSM. It stubs the I2C master's `busy` handshake and asserts:

- every byte transaction targets `DEVICE_ADDR` (= `0x18`) with `rw=0`
  (writes only),
- 15 register writes × 3 bytes = 45 byte transactions are observed,
- `init_done` eventually rises.

[`test/tb_top_level_uda1380.{vhd,v}`](test/) is the integration smoke
test. It overrides the top-level generics so the boot finishes in
microseconds (`INIT_DELAY_CYCLES=4`, `I2C_BUS_FREQ=5_000_000`) and
asserts that SCL / MCLK / BCK / LRCLK actually toggle and `init_done`
rises. No I2C slave is modelled, so the master raises `ack_error` —
the FSM is allowed to ignore that, otherwise the boot would hang
whenever the codec is missing on the bus.

## Caveats / what's not here

- **Hardware verification** is the user's bench, not the simulator's.
  This PR brings the codec from "won't initialise at all" to "FSM
  walks the boot sequence and the wires move". Confirming a 500 Hz
  tone at the headphone jack still needs an actual board.
- **Rx (codec ADC → FPGA) path** is not implemented. The MCLK / LRCLK
  / BCK we generate would feed the ADC clocks too if wired; the
  serial-data input pin (DOUT on the codec → input on the FPGA) and
  an `i2s_slave` block would be needed to capture audio.
- **`ack_error` handling** is intentionally ignored in
  `uda1380_init_fsm`. A field-grade driver would surface this on a
  status pin or retry; for a tutorial the sim-friendly behaviour
  (boot completes regardless) is the right trade.
- **`i2c_master.vhd` is reproduced from the Digi-Key reference** with
  one small change: the bus-clock generator's `CASE` over a
  generic-derived range was rewritten as the equivalent `IF/ELSIF`
  chain so GHDL `--std=08` accepts it. The original case form is
  preserved as a comment in the source.

## Repo notes

- **Two top-levels by design.**
  [`top_level_uda1380`](top_level_uda1380.vhd) is the simulation top:
  it has `inout` SCL / SDA so the testbench can model the
  bidirectional bus directly via `'H'`/`'Z'` resolution.
  [`top_level_uda1380_core`](top_level_uda1380_core.vhd) is the
  netlist-diagram top: same logic, but the I2C bus is exposed as
  `(scl_oe, scl_i, sda_oe, sda_i)`. `netlistsvg`'s JSON schema only
  accepts `input` / `output` for port directions — yosys synthesises
  the inout flavour fine, but the renderer rejects its JSON. The
  `_core` variant has no `inout` anywhere in the hierarchy
  (it instantiates [`i2c_master_for_diagram`](i2c_master_for_diagram.vhd)
  instead of `i2c_master`), so `netlistsvg` accepts it.
- The original `i2c_master.{vhd,v}` is kept verbatim and used by
  the simulation top; only the diagram path goes through the
  `_for_diagram` copy.
- `i2s_master.{vhd,v}` is duplicated from
  [`comm/i2s_test_1`](../i2s_test_1/) so each project stays
  self-contained. Sharing across projects is a future cleanup.
