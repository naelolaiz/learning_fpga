# learning_fpga

[![CI](https://github.com/naelolaiz/learning_fpga/actions/workflows/ci.yml/badge.svg)](https://github.com/naelolaiz/learning_fpga/actions/workflows/ci.yml)
[![CI gallery](https://img.shields.io/badge/CI-gallery-blueviolet)](https://github.com/naelolaiz/learning_fpga/tree/ci-gallery/latest)
[![License](https://img.shields.io/badge/license-see%20LICENSE.md-lightgrey)](LICENSE.md)

A personal, progressive **FPGA / VHDL (and now Verilog) tutorial** — a
collection of small self-contained examples that build up from a blinking
LED to richer designs (PWM, UART, FIFO, shift registers, 7-segment mux,
mini-game, VGA & I²S sketches).

Every project simulates, renders its **netlist diagram** (`*.svg`), and
captures a **waveform screenshot** (`*.png`) automatically in CI. The
examples below embed the **latest diagrams and waveforms** rendered from
`main` — they update whenever the source changes.

- 📚 **What it is** — a tutorial you can read front-to-back, or dip into
  one example at a time.
- 🪞 **Two languages side-by-side** — most examples ship in both VHDL and
  Verilog with matching behaviour.
- 🧪 **Reproducible** — one `make` builds everything locally *and* in CI,
  through the same pinned container image.
- 🤝 **Easy to extend** — drop a `Makefile` in a new directory and CI
  picks it up (see [CONTRIBUTING.md](CONTRIBUTING.md)).

Every `main` CI run publishes its netlist SVGs and GTKWave waveform PNGs
inline in every job summary, on the run-summary page, and on PR comments
— see the
[latest successful `main` run](https://github.com/naelolaiz/learning_fpga/actions/workflows/ci.yml?query=branch%3Amain+is%3Asuccess).
The same images are mirrored on the
[`ci-gallery/latest/`](https://github.com/naelolaiz/learning_fpga/tree/ci-gallery/latest)
branch and embedded in the [Gallery](#gallery) below, refreshed on every
`main` push.

---

## Hardware

![Dev board](doc/board.jpg?raw=true)

- **FPGA:** Altera/Intel Cyclone IV `EP4CE6E22C8N`
  ([datasheet](https://www.mouser.es/datasheet/2/612/cyiv-51001-1299459.pdf))
- **Dev board:** *RZ EasyFPGA A2.2*
  ([Banggood listing](https://www.banggood.com/es/ALTERA-Cyclone-IV-EP4CE6-FPGA-Development-Board-Kit-Altera-EP4CE-NIOSII-FPGA-Board-and-USB-Downloader-Infrared-Controller-p-1622523.html); product info is in Chinese)
- **Synthesis / P&R:** Intel Quartus Prime Lite 21.1
  ([download](https://www.intel.com/content/www/us/en/software-kit/684215/intel-quartus-prime-lite-edition-design-software-version-21-1-for-linux.html))

---

## On real hardware

A few demos running on the board itself:

| VGA driver (2nd revision)         | Scrolling alphanumeric 7-seg       |
| :-------------------------------: | :--------------------------------: |
| ![VGA demo](doc/vga_testing_2.gif) | ![Scrolling text on 7-segment display](7segments/text/doc/scrolling_long_text.gif) |

### [Rotating sprite with a trigonometric LUT](unnamed_fpga_game)

![Rotating sprite driven by a precomputed sin/cos LUT](unnamed_fpga_game/doc/rotating_with_lut_trigonometric.gif)

---

## Gallery

Every diagram / waveform below is the **latest output from CI on `main`**
(served from the
[`ci-gallery` branch](https://github.com/naelolaiz/learning_fpga/tree/ci-gallery/latest)).
For every project that ships both languages, VHDL is shown on the left
and Verilog on the right so you can compare the two directly.

> **Tip:** click a `<summary>` bar to expand each project.

<!-- GALLERY:START -->

<details open>
<summary><b><code>blink_led</code></b> — the "hello world": toggle an LED at 1 Hz</summary>

| VHDL | Verilog |
| :--: | :-----: |
| ![blink_led netlist (VHDL)](https://raw.githubusercontent.com/naelolaiz/learning_fpga/ci-gallery/latest/blink_led/blink_led.svg) | ![blink_led netlist (Verilog)](https://raw.githubusercontent.com/naelolaiz/learning_fpga/ci-gallery/latest/blink_led/blink_led_v.svg) |
| ![blink_led waveform (VHDL)](https://raw.githubusercontent.com/naelolaiz/learning_fpga/ci-gallery/latest/blink_led/tb_blink_led.png) | ![blink_led waveform (Verilog)](https://raw.githubusercontent.com/naelolaiz/learning_fpga/ci-gallery/latest/blink_led/tb_blink_led_v.png) |

</details>

<details>
<summary><b><code>pwm_led</code></b> — duty-cycle modulation driving an LED</summary>

| VHDL | Verilog |
| :--: | :-----: |
| ![pwm_led netlist (VHDL)](https://raw.githubusercontent.com/naelolaiz/learning_fpga/ci-gallery/latest/pwm_led/pwm_led.svg) | ![pwm_led netlist (Verilog)](https://raw.githubusercontent.com/naelolaiz/learning_fpga/ci-gallery/latest/pwm_led/pwm_led_v.svg) |
| ![pwm_led waveform (VHDL)](https://raw.githubusercontent.com/naelolaiz/learning_fpga/ci-gallery/latest/pwm_led/tb_pwm_led.png) | ![pwm_led waveform (Verilog)](https://raw.githubusercontent.com/naelolaiz/learning_fpga/ci-gallery/latest/pwm_led/tb_pwm_led_v.png) |

</details>

<details>
<summary><b><code>uart_tx</code></b> — a minimal 8N1 UART transmitter</summary>

| VHDL | Verilog |
| :--: | :-----: |
| ![uart_tx netlist (VHDL)](https://raw.githubusercontent.com/naelolaiz/learning_fpga/ci-gallery/latest/uart_tx/uart_tx.svg) | ![uart_tx netlist (Verilog)](https://raw.githubusercontent.com/naelolaiz/learning_fpga/ci-gallery/latest/uart_tx/uart_tx_v.svg) |
| ![uart_tx waveform (VHDL)](https://raw.githubusercontent.com/naelolaiz/learning_fpga/ci-gallery/latest/uart_tx/tb_uart_tx.png) | ![uart_tx waveform (Verilog)](https://raw.githubusercontent.com/naelolaiz/learning_fpga/ci-gallery/latest/uart_tx/tb_uart_tx_v.png) |

</details>

<details>
<summary><b><code>shift_register</code></b> — parameterisable shift register</summary>

| VHDL | Verilog |
| :--: | :-----: |
| ![shift_register netlist (VHDL)](https://raw.githubusercontent.com/naelolaiz/learning_fpga/ci-gallery/latest/shift_register/shift_register.svg) | ![shift_register netlist (Verilog)](https://raw.githubusercontent.com/naelolaiz/learning_fpga/ci-gallery/latest/shift_register/shift_register_v.svg) |
| ![shift_register waveform (VHDL)](https://raw.githubusercontent.com/naelolaiz/learning_fpga/ci-gallery/latest/shift_register/tb_shift_register.png) | ![shift_register waveform (Verilog)](https://raw.githubusercontent.com/naelolaiz/learning_fpga/ci-gallery/latest/shift_register/tb_shift_register_v.png) |

</details>

<details>
<summary><b><code>fifo_sync</code></b> — synchronous FIFO with full / empty flags</summary>

| VHDL | Verilog |
| :--: | :-----: |
| ![fifo_sync netlist (VHDL)](https://raw.githubusercontent.com/naelolaiz/learning_fpga/ci-gallery/latest/fifo_sync/fifo_sync.svg) | ![fifo_sync netlist (Verilog)](https://raw.githubusercontent.com/naelolaiz/learning_fpga/ci-gallery/latest/fifo_sync/fifo_sync_v.svg) |
| ![fifo_sync waveform (VHDL)](https://raw.githubusercontent.com/naelolaiz/learning_fpga/ci-gallery/latest/fifo_sync/tb_fifo_sync.png) | ![fifo_sync waveform (Verilog)](https://raw.githubusercontent.com/naelolaiz/learning_fpga/ci-gallery/latest/fifo_sync/tb_fifo_sync_v.png) |

</details>

<details>
<summary><b><code>7segments/counter</code></b> — multiplexed 4-digit counter</summary>

| VHDL | Verilog |
| :--: | :-----: |
| ![7seg counter netlist (VHDL)](https://raw.githubusercontent.com/naelolaiz/learning_fpga/ci-gallery/latest/7segments-counter/test.svg) | ![7seg counter netlist (Verilog)](https://raw.githubusercontent.com/naelolaiz/learning_fpga/ci-gallery/latest/7segments-counter/test_v.svg) |
| ![7seg counter waveform (VHDL)](https://raw.githubusercontent.com/naelolaiz/learning_fpga/ci-gallery/latest/7segments-counter/tb_test.png) | ![7seg counter waveform (Verilog)](https://raw.githubusercontent.com/naelolaiz/learning_fpga/ci-gallery/latest/7segments-counter/tb_test_v.png) |

</details>

<details>
<summary><b><code>general_components</code></b> — reusable Serial2Parallel block</summary>

| VHDL | Verilog |
| :--: | :-----: |
| ![Serial2Parallel netlist (VHDL)](https://raw.githubusercontent.com/naelolaiz/learning_fpga/ci-gallery/latest/general_components/Serial2Parallel.svg) | ![Serial2Parallel netlist (Verilog)](https://raw.githubusercontent.com/naelolaiz/learning_fpga/ci-gallery/latest/general_components/Serial2Parallel_v.svg) |
| ![Serial2Parallel waveform (VHDL)](https://raw.githubusercontent.com/naelolaiz/learning_fpga/ci-gallery/latest/general_components/Serial2Parallel_tb.png) | ![Serial2Parallel waveform (Verilog)](https://raw.githubusercontent.com/naelolaiz/learning_fpga/ci-gallery/latest/general_components/Serial2Parallel_tb_v.png) |

</details>

<details>
<summary><b><code>simulator_writer</code></b> — produces a VCD trace for the simulator flow</summary>

| VHDL | Verilog |
| :--: | :-----: |
| ![simulator_writer netlist (VHDL)](https://raw.githubusercontent.com/naelolaiz/learning_fpga/ci-gallery/latest/simulator_writer/tl_simulator_writer.svg) | ![simulator_writer netlist (Verilog)](https://raw.githubusercontent.com/naelolaiz/learning_fpga/ci-gallery/latest/simulator_writer/tl_simulator_writer_v.svg) |
| ![simulator_writer waveform (VHDL)](https://raw.githubusercontent.com/naelolaiz/learning_fpga/ci-gallery/latest/simulator_writer/tb_simulator_writer.png) | ![simulator_writer waveform (Verilog)](https://raw.githubusercontent.com/naelolaiz/learning_fpga/ci-gallery/latest/simulator_writer/tb_simulator_writer_v.png) |

</details>

<details>
<summary><b><code>unnamed_fpga_game</code></b> — mini game kernel (trigonometric testbench)</summary>

Netlist synthesis is intentionally skipped (`SKIP_DIAGRAM=1`) — the
`abs()` call in `trigonometric.vhd` trips `yosys + ghdl-yosys-plugin`.
Only the simulation waveform is produced:

![unnamed_fpga_game trig waveform](https://raw.githubusercontent.com/naelolaiz/learning_fpga/ci-gallery/latest/unnamed_fpga_game/tb_trigonometric.png)

</details>

<!-- GALLERY:END -->

---

## Build & CI

Every project in this repo builds through one small set of `make` rules.
Adding a project is **two files, zero workflow edits** — CI auto-discovers
any `Makefile` that includes `mk/common.mk`.

### What CI produces, per project

| Stage        | Tool chain                                        | Output             |
| ------------ | ------------------------------------------------- | ------------------ |
| simulate     | GHDL (VHDL) / iverilog (Verilog)                  | `build/<tb>.vcd`   |
| diagram      | yosys + ghdl-yosys-plugin → netlistsvg            | `build/<top>.svg`  |
| screenshot   | GHDL → VCD → headless GTKWave (Xvfb)              | `build/<tb>.png`   |

Each matrix job:

1. **Simulates** the VHDL testbench — and the Verilog mirror if present.
2. **Renders** the netlist diagram (both languages).
3. **Screenshots** the waveform under a headless Xvfb.
4. **Publishes** the `.svg` / `.png` to the orphan
   [`ci-gallery`](https://github.com/naelolaiz/learning_fpga/tree/ci-gallery)
   branch (one directory per run, `run-<id>/<project>/`, plus a
   [`latest/`](https://github.com/naelolaiz/learning_fpga/tree/ci-gallery/latest)
   pointer refreshed on every `main` push). Those images show up
   inline in (a) per-job step summaries, (b) the run-summary page, and
   (c) the auto-upserted PR comment on pull requests.

### Running locally

```bash
make                            # build every project
make -C blink_led simulate      # one project, one stage
make list                       # what CI would discover
make clean                      # nuke every build/
```

…or through the same container CI uses (ships GHDL, yosys +
ghdl-plugin, iverilog, netlistsvg, GTKWave, Xvfb):

```bash
podman run --rm -it -v "$PWD":/work -w /work \
    ghcr.io/naelolaiz/hdltools:release \
    make
```

Swap `podman` for `docker` if that is your local runtime.

### Verilog support

The build machinery is **bilingual**. A project that defines `V_TOP` /
`V_TB_TOP` / `V_SRC_FILES` / `V_TB_FILES` in its `Makefile` also gets a
parallel iverilog / yosys flow whose artifacts share `build/` with the
VHDL ones via a `_v` suffix (`build/<top>_v.svg`, `build/<tb>_v.vcd`,
`build/<tb>_v.png`) — both languages coexist without colliding.

| target         | tooling                              |
| -------------- | ------------------------------------ |
| `simulate_v`   | `iverilog -g2012` → `vvp`            |
| `diagram_v`    | `yosys read_verilog` → `netlistsvg`  |
| `screenshot_v` | `vvp` VCD → headless GTKWave         |

`make all` runs both flows when both language sets are populated.
Verilog testbenches must call `` $dumpfile(`VCD_OUT) `` — the Makefile
supplies that define so the dump file always lands in `build/`. See
[blink_led/test/tb_blink_led.v](blink_led/test/tb_blink_led.v) for the
canonical pattern.

### Adding a new example

See [CONTRIBUTING.md](CONTRIBUTING.md). tl;dr: drop a `Makefile` that
declares `TOP / TB_TOP / SRC_FILES / TB_FILES` (and optionally the
`V_*` equivalents), `include ../mk/common.mk`, done.

---

## What's in the repo

| Project                       | CI | Languages      | Notes                                                          |
| ----------------------------- | :-: | -------------- | -------------------------------------------------------------- |
| [blink_led](blink_led/)                                     | ✅ | VHDL + Verilog | Hello-world LED toggler.                                       |
| [pwm_led](pwm_led/)                                         | ✅ | VHDL + Verilog | Brightness via duty-cycle modulation.                          |
| [uart_tx](uart_tx/)                                         | ✅ | VHDL + Verilog | 8N1 UART transmitter.                                          |
| [shift_register](shift_register/)                           | ✅ | VHDL + Verilog | Parameterised shift register.                                  |
| [fifo_sync](fifo_sync/)                                     | ✅ | VHDL + Verilog | Synchronous FIFO.                                              |
| [7segments/counter](7segments/counter/)                     | ✅ | VHDL + Verilog | Multiplexed 4-digit counter.                                   |
| [general_components](general_components/)                   | ✅ | VHDL + Verilog | Serial2Parallel (both languages) + Debounce (VHDL only).       |
| [simulator_writer](simulator_writer/)                       | ✅ | VHDL + Verilog | VCD writer used to sanity-check the sim flow.                  |
| [unnamed_fpga_game](unnamed_fpga_game/)                     | ✅ | VHDL           | Trigonometric testbench; `SKIP_DIAGRAM` set (see Makefile).    |
| [7segments/text](7segments/text/)                           | ⏳ | VHDL           | Sources present, no Makefile yet.                              |
| [7segments/clock](7segments/clock/)                         | ⏳ | VHDL           | Fails to compile under current toolchain (see Roadmap).        |
| [7segments/random_generator](7segments/random_generator/)   | ⏳ | VHDL           | Sources present, no Makefile yet.                              |
| [i2s_test_1](i2s_test_1/)                                   | ⏳ | VHDL           | Sources present, no Makefile yet.                              |
| [rom_lut](rom_lut/)                                         | ⏳ | VHDL           | Sources present, no Makefile yet.                              |
| [uda1380](uda1380/)                                         | ⏳ | VHDL           | Sources present, no Makefile yet.                              |
| [vga](vga/)                                                 | ⏳ | VHDL           | Sources present, no Makefile yet.                              |

Legend: ✅ built in CI · ⏳ pending adoption (dropping a `Makefile` is all it takes).

---

## Roadmap

### VHDL — done ✅

- Blinking LED (keyboard-driven variant).
- 7-segment driver:
  - multiplexed 4-digit counter;
  - alphanumeric characters + scrolling strings.
- Rotating sprite driven by a precomputed sin/cos LUT.
- CI: per-project simulate + diagram + GTKWave screenshot, with
  auto-discovery and a pinned hdltools container. Build machinery
  merged in from
  [hdltools](https://github.com/naelolaiz/hdltools) and
  [fpga_tutorial](https://github.com/naelolaiz/fpga_tutorial).

### Verilog mirrors — done ✅

- Every built-in-CI example ships a Verilog twin with matching
  behaviour — read the two languages side-by-side in [Gallery](#gallery).
- New dual-language examples: `pwm_led`, `uart_tx`, `shift_register`,
  `fifo_sync`.

### In progress 🛠️

- **`7segments/clock`** — application-level example composed from smaller
  entities. Working:
  - [x] Digit entity + cascaded instances.
  - [x] Reusable timer entity driving the first digit.
  - [x] Reusable time-counter entity (timer inside) for the digit mux.
  - [x] HHMM / MMSS view modes toggled by a button, with debouncer
    (copied from
    [nandland](https://nandland.com/project-4-debounce-a-switch/);
    replace with own version).
  - [x] Set time with +/- buttons; speed scales with the view mode.
- Remaining:
  - [ ] Blink the middle dot (1 Hz in HHMM, ~4 Hz in MMSS).
  - [ ] Alarm.
  - [ ] Milliseconds view.
  - [ ] Dynamic speed for set-time UX.
  - [ ] Drop redundant timers; general cleanup.
  - [ ] Make the clock project CI-compatible (missing configurations +
    likely VHDL-standard mismatch).

### Next up 🎯

- Verilog mirrors for the bigger SoC-style projects: `vga`,
  `i2s_test_1`, `uda1380`, `7segments/clock`, `unnamed_fpga_game` —
  leaf modules first, top-levels after.
- Wire the "pending adoption" projects above into CI once their
  sources build cleanly (the old `rom_lut` was intentionally disabled
  in the legacy workflow; it will need work before it can join).
- Small game using the buttons + 7-segment display (snake / space
  invaders). Prerequisite: on-FPGA RNG.
- VGA text driver, then adapt the 7-seg examples (clock, game, …) to
  render on VGA.
- I²S driver + an FFT implementation → spectral analyser (I²S → FFT →
  VGA). Eventually extend with IFFT / DSP kernels for a small FX
  module; later BLE / Bluetooth audio.

---

## Further reading

- [projectf.io tutorials](https://projectf.io/tutorials/)
  · [recommended FPGA sites](https://projectf.io/recommended-fpga-sites/)
  · [how-to guides](https://projectf.io/howto/)
- [FPGA designs with VHDL](https://vhdlguide.readthedocs.io/en/latest/)
- Compatible projects for the same board:
  - [VGA demo](https://github.com/fsmiamoto/EasyFPGA-VGA) (Verilog).
  - [Verilog translations of the board's Chinese docs](https://github.com/jvitkauskas/Altera-Cyclone-IV-board-V3.0).
  - [Portuguese walkthrough with VHDL](https://github.com/filippovf/KitEasyFPGA).
