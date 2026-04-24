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
   TB_TOP  := tb_my_top

   SRC_FILES := my_top.vhd
   TB_FILES  := test/tb_my_top.vhd

   VHDL_STANDARD := 08   # optional; default is 08

   # Optional Verilog mirror — define these to enable the parallel
   # iverilog/yosys flow (`simulate_v`, `diagram_v`, `screenshot_v`).
   # `make all` runs both flows when both are populated.
   V_TOP       := my_top
   V_TB_TOP    := tb_my_top
   V_SRC_FILES := my_top.v
   V_TB_FILES  := test/tb_my_top.v

   include ../mk/common.mk    # adjust ../ depth if your project is deeper
   ```

   For Verilog testbenches, dump waveforms via the supplied `VCD_OUT`
   define so the file lands in `build/`:

   ```verilog
   initial begin
       $dumpfile(`VCD_OUT);
       $dumpvars(0, tb_my_top);
       // ...
   end
   ```

3. Build locally:

   ```bash
   make -C my_new_project
   ```

4. Push. CI auto-discovers the new directory — no workflow edit needed.

## Layout rules

- The VHDL work library, VCDs, PNGs, SVGs and JSON netlists all land in
  `build/` under the project directory. `make clean` is a single `rm -rf`.
- Paths in `SRC_FILES` / `TB_FILES` are relative to the `Makefile`. That's
  why the testbench in a `test/` subdir is listed as `test/tb_*.vhd`.
- The `include` path follows the nesting depth:
  - `blink_led/Makefile` uses `../mk/common.mk`
  - `7segments/counter/Makefile` uses `../../mk/common.mk`

## Running CI locally

The CI workflow runs every project through `make simulate`, `make diagram`
and `make screenshot`. You can reproduce any of those verbatim on your
laptop:

```bash
make -C blink_led simulate
make -C blink_led diagram
xvfb-run --auto-servernum make -C blink_led screenshot   # screenshot needs an X server
```

Or, the same container CI uses:

```bash
docker run --rm -it -v "$PWD":/work -w /work \
    ghcr.io/naelolaiz/hdltools:release \
    make
```

## Tool installs (non-container)

On Ubuntu 22.04+:

```bash
sudo apt-get install ghdl yosys yosys-plugin-ghdl iverilog \
                     gtkwave xvfb nodejs npm
sudo npm install -g netlistsvg
pip install -r scripts/requirements.txt
```
