# README additions

Paste these sections into `README.md` at whatever point fits your flow.
The first block replaces the current **"create a CI github infrastructure"**
bullet in the Log section (since that TODO is now done).

---

## Build & CI

[![CI](https://github.com/naelolaiz/learning_fpga/actions/workflows/ci.yml/badge.svg)](https://github.com/naelolaiz/learning_fpga/actions/workflows/ci.yml)

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
- `unnamed_fpga_game` (trigonometric testbench)

Projects pending adoption (they have VHDL sources but no CI hookup yet —
dropping a `Makefile` in each is all it takes): `7segments/text`,
`7segments/clock`, `i2s_test_1`, `rom_lut`, `uda1380`, `vga`.
