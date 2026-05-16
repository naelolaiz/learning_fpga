# Contributing

## Adding a project

1. Create (or reuse) a project directory. Layout is flexible — flat or
   with a `test/` subdirectory both work:

   ```
   my_new_project/
   ├── my_top.vhd
   ├── test/
   │   └── tb_my_top.vhd
   └── Makefile
   ```

2. Drop a `Makefile` declaring what the project is. The `include` at the
   bottom pulls in every build rule:

   ```make
   PROJECT_NAME := my_new_project

   TOP     := my_top
   # TB_TOPS is a space-separated list. Projects with a single
   # testbench write a one-entry list; projects that have multiple
   # focused testbenches (e.g. unit vs. integration) list them all and
   # each one renders its own FST + PNG in `build/`.
   TB_TOPS := tb_my_top

   SRC_FILES := my_top.vhd
   TB_FILES  := test/tb_my_top.vhd

   VHDL_STANDARD := 08   # optional; default is 08

   # Optional Verilog mirror — define these to enable the parallel
   # iverilog/yosys flow (`simulate_v`, `diagram_v`, `waveform_v`).
   # `make all` runs both flows when both are populated.
   V_TOP       := my_top
   V_TB_TOPS   := tb_my_top
   V_SRC_FILES := my_top.v
   V_TB_FILES  := test/tb_my_top.v

   include ../../mk/common.mk    # adjust ../ depth to your project's nesting
   ```

   For Verilog testbenches, dump waveforms via the supplied `FST_OUT`
   define so the file lands in `build/`:

   ```verilog
   initial begin
       $dumpfile(`FST_OUT);
       $dumpvars(0, tb_my_top);
       // ...
   end
   ```

   The Makefile runs `vvp` with `IVERILOG_DUMPER=fst`, so iverilog 13
   emits FST natively — no testbench-side change needed beyond the
   filename extension.

3. Build locally:

   ```bash
   make -C basics/my_new_project
   ```

4. Push. CI auto-discovers the new directory at any depth — no workflow edit needed.

## Layout rules

- Projects live under a category subdirectory (`basics/`, `building_blocks/`,
  `display/`, `comm/`, `tools/`). The categorisation is informal — pick
  the one that fits, or propose a new bucket in the PR description.
- The VHDL work library, FST dumps, PNGs, SVGs and JSON netlists all land in
  `build/` under the project directory. `make clean` is a single `rm -rf`.
- Paths in `SRC_FILES` / `TB_FILES` are relative to the `Makefile`. That's
  why the testbench in a `test/` subdir is listed as `test/tb_*.vhd`.
- The `include` path follows the nesting depth — count the `../`s back
  to the repo root:
  - `basics/blink_led/Makefile` uses `../../mk/common.mk`
  - `display/7segments/counter/Makefile` uses `../../../mk/common.mk`

## Running CI locally

The CI workflow runs every project through `make simulate`, `make diagram`
and `make waveform`. You can reproduce any of those verbatim on your
laptop:

```bash
make -C basics/blink_led simulate
make -C basics/blink_led diagram
make -C basics/blink_led waveform
```

Or, the same container CI uses:

```bash
docker run --rm -it -v "$PWD":/work -w /work \
    ghcr.io/naelolaiz/hdltools:netlistsvg-hierarchy \
    make
```

## Tool installs (non-container)

On Ubuntu 22.04+:

```bash
sudo apt-get install ghdl yosys yosys-plugin-ghdl iverilog nodejs npm
sudo npm install -g netlistsvg
pip install git+https://github.com/naelolaiz/hdltools.git#subdirectory=waveview
```

`waveview` (the waveform renderer used by `make waveform`) lives in the
[hdltools](https://github.com/naelolaiz/hdltools) repo and is a regular
pip-installable package.
