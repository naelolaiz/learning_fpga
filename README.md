# learning_fpga

[![CI](https://github.com/naelolaiz/learning_fpga/actions/workflows/ci.yml/badge.svg)](https://github.com/naelolaiz/learning_fpga/actions/workflows/ci.yml)

Project containing tests for learning FPGA/VHDL.

## Hardware
![used board](doc/board.jpg?raw=true)
 * FPGA chip: EP4CE6E22C8N. ([datasheet in mouser](https://www.mouser.es/datasheet/2/612/cyiv-51001-1299459.pdf))
 * Dev board: Cyclone IV. "RZ EasyFPGA A2.2" ([banggood link](https://www.banggood.com/es/ALTERA-Cyclone-IV-EP4CE6-FPGA-Development-Board-Kit-Altera-EP4CE-NIOSII-FPGA-Board-and-USB-Downloader-Infrared-Controller-p-1622523.html), with information in chineese)
## Software
 * Intel Quartus FPGA Lite 21.1 ([download link](https://www.intel.com/content/www/us/en/software-kit/684215/intel-quartus-prime-lite-edition-design-software-version-21-1-for-linux.html))
## links
 * compatible code related interesting projects
   * [VGA using same board](https://github.com/fsmiamoto/EasyFPGA-VGA)
   * [Some Translations of the chineese information and examples for the board, in Verilog](https://github.com/jvitkauskas/Altera-Cyclone-IV-board-V3.0)
   * [Information in Portuguese, with example in vhdl](https://github.com/filippovf/KitEasyFPGA)
   * [FPGA designs with VHDL](https://vhdlguide.readthedocs.io/en/latest/)
## Demos:
### Testing VGA driver
![New version of vga demo](doc/vga_testing_2.gif)
### ![Driving 4 multiplexed 7 segment digits with alphanumeric characters, with scroll](https://github.com/naelolaiz/learning_fpga/tree/main/7segments/text)
![What it looks like](7segments/text/doc/scrolling_long_text.gif)
![RTL view](7segments/text/doc/RTL_view.png)
## Log:
- Learn VHDL (in progress)
  - [x] hello world: blinking led (+keyboard) : https://github.com/naelolaiz/learning_fpga/tree/main/blink_led
  - [x] driver for 7 segments display
    - [x] basic handling and mux for 4 digits on a simple counter: https://github.com/naelolaiz/learning_fpga/tree/main/7segments/counter
    - [x] extended handling with alphanumeric chars, strings and scrolling: https://github.com/naelolaiz/learning_fpga/tree/main/7segments/text
    - (in progress) simple clock application using entities for compositions: https://github.com/naelolaiz/learning_fpga/tree/main/7segments/clock
      - [x] create reusable entity for digits and connect instances in cascade.
      - [x] create reusable entity for a timer. Use it as clock for the first digit.
      - [x] create reusable entity for a time counter (instatiating a timer inside). Use it for handling the CableSelect on the multiplexed digits.
      - [x] allow two view modes HHMM/MMSS. Change it with a button.
        - [x] use a debouncer for the button (this is the only code that is not mine. It is copied from https://nandland.com/project-4-debounce-a-switch/). I copied it because I knew that it was there, and I was focused on other functionalities. TODO: create my own version.
      - [x] allow setting the time by increasing the numbers with a second button.
        - [x] the speed should be fast, and should depend on the current view mode.
      - [x] allow setting the time by decreasing the numbers with a third button. Update digit entity accordingly.
      - TODO: 
        - make the middle dot on the second display to blink. At different intervals depending on the view mode (0.5 sec to change state -period 1hz- for HHMM, 0.25 ? sec to change state in MMSS)
        - add alarm
        - milliseconds view
        - improve set time interface (dynamic speed for increasing/decreasing time)
        - cleanup
        - simplify code to remove redundant timers
 - [x] create a CI github action to compile a vhdl file with ghdl : https://github.com/naelolaiz/learning_fpga/blob/main/.github/workflows/ci.yml
   - TODO: make other vhdl files compatible (at least the Clock — today it doesn't compile because of missing configurations and probably a different VHDL standard).
 - [x] create a CI github infrastructure that
   - [x] runs every project's simulation and renders a GTKWave PNG of the waveform
   - [x] renders netlist SVG diagrams for each top-level entity via yosys + ghdl-yosys-plugin + netlistsvg
   - [x] auto-discovers new projects, no workflow edit needed (see [CONTRIBUTING.md](CONTRIBUTING.md))
   - machinery merged in from https://github.com/naelolaiz/hdltools and https://github.com/naelolaiz/fpga_tutorial

  - TODO:
    - create a simple game with the buttons and the 7 segments display (snake / space invaders)
      - learn how to generate random numbers with the FPGA
    - create a vga text driver
      - adapt 7 segment created entities to use VGA as display (clock, game, ...)
    - create an i2s driver
      - create / find a FFT implementation to
        - create a spectral analyzer (i2s, fft, vga)
        - (+IFFT, +DSP algorithms) create an FX/DSP module
          - (+bluetooth/BLE driver) extend module with wireless audio
- Learn Verilog (TODO)

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

Each matrix job uploads them as `<project>-artifacts`.

### Currently built in CI

- `blink_led`
- `general_components` (Serial2Parallel)
- `simulator_writer`
- `7segments/counter`
- `unnamed_fpga_game` (trigonometric testbench; `SKIP_DIAGRAM` set — see
  project Makefile for the reason)

Projects pending adoption (they have VHDL sources but no CI hookup yet —
dropping a `Makefile` in each is all it takes): `7segments/text`,
`7segments/clock`, `7segments/random_generator`, `i2s_test_1`, `rom_lut`,
`uda1380`, `vga`.

## more links
 - https://projectf.io/tutorials/
   - https://projectf.io/recommended-fpga-sites/
   - https://projectf.io/howto/
