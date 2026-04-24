# learning_fpga

[![CI](https://github.com/naelolaiz/learning_fpga/actions/workflows/ci.yml/badge.svg)](https://github.com/naelolaiz/learning_fpga/actions/workflows/ci.yml)

Project containing tests for learning FPGA/VHDL.

Every `main` CI run produces netlist SVGs and GTKWave waveform PNGs rendered
inline in the job summary, per project — see the
[latest successful `main` run](https://github.com/naelolaiz/learning_fpga/actions/workflows/ci.yml?query=branch%3Amain+is%3Asuccess)
(top of the filtered list). The same images are also mirrored on the
[`ci-gallery/latest/`](https://github.com/naelolaiz/learning_fpga/tree/ci-gallery/latest)
branch, refreshed on every `main` push.

## Hardware

![Dev board](doc/board.jpg?raw=true)

- FPGA chip: EP4CE6E22C8N ([datasheet on Mouser](https://www.mouser.es/datasheet/2/612/cyiv-51001-1299459.pdf)).
- Dev board: Cyclone IV "RZ EasyFPGA A2.2" ([Banggood listing](https://www.banggood.com/es/ALTERA-Cyclone-IV-EP4CE6-FPGA-Development-Board-Kit-Altera-EP4CE-NIOSII-FPGA-Board-and-USB-Downloader-Infrared-Controller-p-1622523.html); product info is in Chinese).

## Software

- Intel Quartus FPGA Lite 21.1 ([download](https://www.intel.com/content/www/us/en/software-kit/684215/intel-quartus-prime-lite-edition-design-software-version-21-1-for-linux.html)).

## Related projects

Other code using the same board or covering similar ground:

- [VGA on the same board (Verilog)](https://github.com/fsmiamoto/EasyFPGA-VGA).
- [Translations of the Chinese board documentation + Verilog examples](https://github.com/jvitkauskas/Altera-Cyclone-IV-board-V3.0).
- [Board documentation in Portuguese, with VHDL examples](https://github.com/filippovf/KitEasyFPGA).
- [FPGA designs with VHDL](https://vhdlguide.readthedocs.io/en/latest/).

## Demos

### VGA driver

![VGA demo](doc/vga_testing_2.gif)

### [4 multiplexed 7-segment digits with alphanumeric characters and scroll](7segments/text)

![Scrolling text on 7-segment display](7segments/text/doc/scrolling_long_text.gif)

![RTL view](7segments/text/doc/RTL_view.png)

### [Rotating sprite with a trigonometric LUT](unnamed_fpga_game)

![Rotating sprite driven by a precomputed sin/cos LUT](unnamed_fpga_game/doc/rotating_with_lut_trigonometric.gif)

## Log

### Done

- Blinking LED (+ keyboard input) — [blink_led/](blink_led).
- 7-segment display driver:
  - 4-digit mux driven by a counter — [7segments/counter/](7segments/counter).
  - Alphanumeric characters, strings and scrolling — [7segments/text/](7segments/text).
- Rotating sprite driven by a precomputed sin/cos LUT — [unnamed_fpga_game/](unnamed_fpga_game).
- CI:
  - GHDL-based workflow compiling project VHDL — [.github/workflows/ci.yml](.github/workflows/ci.yml).
  - Per-project `simulate` → GTKWave PNG, `diagram` → yosys + ghdl-yosys-plugin → netlistsvg SVG.
  - Job summary embeds every `.svg` / `.png` inline, plus an auto-published gallery on the `ci-gallery` branch and PR-comment gallery.
  - Auto-discovery — adding a project means a new `Makefile`, no workflow edit (see [CONTRIBUTING.md](CONTRIBUTING.md)).
  - Build machinery merged in from [hdltools](https://github.com/naelolaiz/hdltools) and [fpga_tutorial](https://github.com/naelolaiz/fpga_tutorial).

### In progress

- 7-segment clock built from reusable entities — [7segments/clock/](7segments/clock):
  - [x] Digit entity + cascaded instances.
  - [x] Reusable timer entity driving the first digit.
  - [x] Reusable time-counter entity (timer inside) for the digit mux.
  - [x] HHMM / MMSS view modes toggled by a button, with debouncer (copied from [nandland](https://nandland.com/project-4-debounce-a-switch/); replace with own version).
  - [x] Set time with +/- buttons; speed scales with the view mode.
  - [ ] Blink the middle dot (1 Hz in HHMM, ~4 Hz in MMSS).
  - [ ] Alarm.
  - [ ] Milliseconds view.
  - [ ] Dynamic speed for set-time UX.
  - [ ] Drop redundant timers; general cleanup.
  - [ ] Make the clock project CI-compatible (fails today due to missing configurations and a likely VHDL-standard mismatch).

### Backlog

- Simple game on the buttons + 7-segment display (snake / space invaders); needs on-FPGA RNG.
- VGA text driver; port the 7-seg clock and game to render on VGA.
- I2S driver; then an FFT block, building toward:
  - a spectral analyzer (I2S + FFT + VGA);
  - an FX/DSP module (+ IFFT, + DSP algorithms);
  - wireless audio on top (+ BLE/Bluetooth driver).
- Learn Verilog (in progress): every CI-wired tutorial project ships a
  Verilog mirror alongside the VHDL — identical functionality, matching
  testbench expectations — so the two read side-by-side. Four new
  dual-language examples (`pwm_led`, `uart_tx`, `shift_register`,
  `fifo_sync`) land in both languages. Bigger SoC-style projects
  (`vga`, `i2s_test_1`, `uda1380`, `7segments/clock`, `unnamed_fpga_game`)
  still to mirror — leaf modules first, top levels after. See
  [Verilog support](#verilog-support).

## Build & CI

Every VHDL project in this repo is built by the same small Makefile
machinery. One `mk/common.mk` holds every rule (analyze / elaborate /
simulate / diagram / screenshot / clean); each project's Makefile just
declares *what the project is* (`TOP`, `TB_TOP`, `SRC_FILES`, `TB_FILES`).
CI auto-discovers projects — adding a new one is two files and zero
workflow changes. See [CONTRIBUTING.md](CONTRIBUTING.md).

### Running locally

```bash
# Everything, same commands as CI
make                            # all projects, all targets
make -C blink_led simulate      # one project, one stage
make list                       # what's discovered
make clean                      # nuke every build/
```

Or through the same container CI uses (includes GHDL, yosys+ghdl-plugin,
netlistsvg, GTKWave, Xvfb):

```bash
docker run --rm -it -v "$PWD":/work -w /work \
    ghcr.io/naelolaiz/hdltools:release \
    make
```

Podman works the same way — swap `docker` for `podman`.

### What CI produces, per project

| Artifact                  | Tool chain                                    |
| ------------------------- | --------------------------------------------- |
| `build/<tb>.vcd`          | GHDL simulate                                 |
| `build/<top>.svg`         | yosys + ghdl-yosys-plugin → netlistsvg        |
| `build/<tb>.png`          | GHDL → VCD → headless GTKWave (Xvfb)          |

Each matrix job uploads them as `<project>-artifacts`, and each build step
summary embeds the `.svg` / `.png` inline so the run page is a self-contained
gallery — no artifact download required. See the
[latest successful `main` run](https://github.com/naelolaiz/learning_fpga/actions/workflows/ci.yml?query=branch%3Amain+is%3Asuccess).

### Gallery branch

`.svg` diagrams and `.png` waveforms are also committed to the orphan
[`ci-gallery`](https://github.com/naelolaiz/learning_fpga/tree/ci-gallery)
branch, one directory per run (`run-<id>/<project>/`) plus a
[`latest/`](https://github.com/naelolaiz/learning_fpga/tree/ci-gallery/latest)
pointer refreshed on every `main` push. On pull requests the same gallery is
posted (and updated in place) as a PR comment.

### Project CI status

Adding a project means dropping a `Makefile` that `include`s `mk/common.mk`;
`discover` picks it up automatically. Status today:

| Project                     | CI | Notes                                                           |
| --------------------------- | -- | --------------------------------------------------------------- |
| `blink_led`                 | ✅ | VHDL + Verilog.                                                 |
| `general_components`        | ✅ | Serial2Parallel (VHDL + Verilog) + Debounce.                    |
| `simulator_writer`          | ✅ | VHDL + Verilog.                                                 |
| `7segments/counter`         | ✅ | VHDL + Verilog.                                                 |
| `unnamed_fpga_game`         | ✅ | Trigonometric testbench; `SKIP_DIAGRAM` set (see Makefile).     |
| `pwm_led`                   | ✅ | VHDL + Verilog.                                                 |
| `uart_tx`                   | ✅ | VHDL + Verilog.                                                 |
| `shift_register`            | ✅ | VHDL + Verilog.                                                 |
| `fifo_sync`                 | ✅ | VHDL + Verilog.                                                 |
| `7segments/text`            | ⏳ | Sources present, no Makefile yet.                               |
| `7segments/clock`           | ⏳ | Fails to compile under current toolchain (see In progress).     |
| `7segments/random_generator`| ⏳ | Sources present, no Makefile yet.                               |
| `i2s_test_1`                | ⏳ | Sources present, no Makefile yet.                               |
| `rom_lut`                   | ⏳ | Sources present, no Makefile yet.                               |
| `uda1380`                   | ⏳ | Sources present, no Makefile yet.                               |
| `vga`                       | ⏳ | Sources present, no Makefile yet.                               |

### Verilog support

The build machinery is **bilingual**: any project that defines
`V_SRC_FILES` / `V_TB_FILES` / `V_TOP` / `V_TB_TOP` in its `Makefile`
also gets a parallel iverilog/yosys flow. The Verilog artifacts share
`build/` with the VHDL ones using a `_v` suffix (`build/<top>_v.svg`,
`build/<tb>_v.vcd`, `build/<tb>_v.png`) so both languages co-exist
without colliding.

Per-language targets:

| target          | tooling                              |
| --------------- | ------------------------------------ |
| `simulate_v`    | `iverilog -g2012` → `vvp`            |
| `diagram_v`     | `yosys read_verilog` → `netlistsvg`  |
| `screenshot_v`  | `vvp` VCD → headless GTKWave         |

`make all` runs both flows when both language sets are populated.

Verilog testbenches must call `$dumpfile(\`VCD_OUT)`; the Makefile
supplies that define so the dump file lands in `build/` regardless of
where the testbench is invoked from. See `blink_led/test/tb_blink_led.v`
for the canonical pattern.

## More links

- [Project F tutorials](https://projectf.io/tutorials/)
  - [Recommended FPGA sites](https://projectf.io/recommended-fpga-sites/)
  - [How-to index](https://projectf.io/howto/)
