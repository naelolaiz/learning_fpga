# vga

A VGA tutorial: bouncing square + scrolling/dynamic text driven straight
into the on-board VGA connector at 640×480 @ 60 Hz, 1 bit per channel,
with three button controls and four status LEDs.

![demo](doc/crazy_screen.gif)

## What it shows

* A coloured square that bounces around the visible area, recolouring
  on each wall hit. Three step-rate presets (fast / medium / slow)
  selectable from a button.
* A static line of text (`"VGA with FPGA. 1 bit per component :)"`)
  that scrolls horizontally at ~33 px/s, wrapping at the right margin.
* Two `changingString` lines whose characters cycle by ASCII every
  ~80 ms — one printed forward, the mirror printed backward.
* A long dynamic banner (`"<<<((([[[ * FPGA VGA TEST * ]]])))>>>"`)
  that bounces in parallel with the square, recolouring on each wall
  hit.
* Overlap colour mixing: where two layers' boxes intersect, their RGB
  triplets XOR (so a green square crossing a yellow text background
  paints magenta in the overlap region). When the square sits on the
  static text and the dynamic banner also crosses, the static-text
  colour rotates to mark the hit.

## Controls

The top entity exposes:

| Pin | Direction | Signal             | Purpose                                         |
| --- | :-------: | ------------------ | ----------------------------------------------- |
| 23  | in        | `clk`              | 50 MHz on-board oscillator.                     |
| 88  | in        | `inputButtons(0)`  | Pause / resume animation (active-low).          |
| 89  | in        | `inputButtons(1)`  | Reset square to centre while held (active-low). |
| 90  | in        | `inputButtons(2)`  | Cycle step speed: medium → slow → fast.         |
| 87  | out       | `leds(0)`          | One-clock pulse on every square step.           |
| 86  | out       | `leds(1)`          | Pause indicator (lit while paused).             |
| 85  | out       | `leds(2)`          | ~12.5 Hz heartbeat (`ticksForHalfSecond`).      |
| 84  | out       | `leds(3)`          | Lit while in fast speed mode.                   |
| 106 | out       | `rgb(0)`           | Red channel.                                    |
| 105 | out       | `rgb(1)`           | Green channel.                                  |
| 104 | out       | `rgb(2)`           | Blue channel.                                   |
| 101 | out       | `hsync`            | Horizontal sync.                                |
| 103 | out       | `vsync`            | Vertical sync.                                  |

Buttons are active-low (the EasyFPGA convention): a press shows up as a
falling edge on the debounced output. Each button is filtered by an
instance of [`Debounce`](../../building_blocks/debounce/) reused via
`entity work.Debounce(RTL)` — no third copy is added under this project.

`leds(0)` is one master-clock cycle wide per step. On a physical LED at
50 MHz that's too short to perceive (it blends to a dim glow); on a scope
or in the rendered TB waveform it reads cleanly per step.

## Files

```
vga/
├── Makefile               # CI wiring + Verilog mirror flags
├── top_level_vga_test.vhd # Board top
├── top_level_vga_test.qsf # Quartus project
├── control_panel.vhd      # 3 debouncers + pause / speed / reset
│                          # state-machine + status LED panel.
│                          # Instantiated by the board top; exercised
│                          # directly by tb_vga_top.
├── control_panel.v        # Verilog mirror of control_panel.vhd
├── text_generator/
│   ├── commonPak.vhd      # Font types + constants
│   ├── Font_Rom.vhd       # 8x16 ASCII glyph ROM (2048 x 8 bits)
│   ├── Pixel_On_Text.vhd  # Single-line renderer (text + position)
│   ├── Pixel_On_Text2.vhd # Same but with separate positionX / positionY
│   ├── Pixel_On_Text_WithSize.vhd  # Scaled + mirrored variant
│   └── font_rom.v         # Verilog mirror of Font_Rom (same ROM
│                          # contents, mechanical translation)
├── test/
│   ├── tb_vga_smoke.vhd   # Primitive smoke: Square procedure + Font_Rom
│   ├── tb_vga_smoke.v     # Verilog mirror of the smoke TB
│   ├── tb_vga_top.vhd     # Integration TB on control_panel:
│   │                      # pause toggle / speed-cycler walk / reset
│   │                      # level / heartbeat passthrough
│   └── tb_vga_top.v       # Verilog mirror of the integration TB
└── doc/
    └── crazy_screen.gif   # Captured demo
```

The shared VGA driver (`VgaController`, `VgaUtils`) lives one level up
at [`display/vga_driver/`](../vga_driver/) and is reused by
[`vga_sprites`](../vga_sprites/) too. `vga_driver/vga_controller.v`
is a 1:1 Verilog mirror of `VgaController.vhd` so both CI flows can
synthesise the same timing FSM and the gallery shows paired netlist
diagrams.

## Build

```sh
make all       # simulate + diagram + waveform, both VHDL and Verilog flows
make simulate
make diagram
make waveform
```

From the repo root:

```sh
make           # builds every project, including this one
```

The diagram TOP is `VgaController` in both flows — the bare VGA timing
controller (state-machine view of HSYNC/VSYNC counters). The Verilog
mirror of the FSM lives at
[`vga_driver/vga_controller.v`](../vga_driver/vga_controller.v) (module
name kept in PascalCase to match the VHDL entity, so the gallery's
stem-based pairing puts the two diagrams on the same row). The full
`top_level_vga_test` is in `SRC_FILES` so GHDL syntax-checks it on
every CI run, but it isn't synthesised because of the string-typed
generics in `Pixel_On_Text*`.

Both testbenches are paired across flows. The integration TB doesn't
need a Verilog mirror of `top_level_vga_test` — it instantiates the
`control_panel` building block directly (where all the debouncer +
pause/speed/reset state lives), which has its own Verilog mirror at
`control_panel.v`. That keeps the test surface synthesisable by
yosys without dragging in the un-portable `Pixel_On_Text*` string
generics from the full top.

## Relationship to vga_sprites

The two `display/vga*` examples cover different ground:

* **`vga`** (this one) is the introductory text + geometric primitives
  demo. Bouncing square, scrolling/cycling text, font ROM, button
  controls, overlap colour XOR. No multipliers, no LUT trigonometry.
* **[`vga_sprites`](../vga_sprites/)** is the advanced bitmap-sprite
  demo: rotating sprites driven by a sin/cos LUT, optional gravity,
  collision detection. No text rendering.

Both share the [`vga_driver/`](../vga_driver/) at the parent level
(640×480 @ 60 Hz, 1 bit per channel, ported from
[fsmiamoto/EasyFPGA-VGA](https://github.com/fsmiamoto/EasyFPGA-VGA)).

## Upstream code

| Component                                | Origin |
| ---------------------------------------- | --- |
| `vga_driver/Vga{Controller,Utils}.vhd`   | [fsmiamoto/EasyFPGA-VGA](https://github.com/fsmiamoto/EasyFPGA-VGA) |
| `text_generator/*.vhd`                   | [Derek-X-Wang/VGA-Text-Generator](https://github.com/Derek-X-Wang/VGA-Text-Generator) |
| `building_blocks/debounce/Debounce.vhd`  | [nandland switch debounce](https://nandland.com/project-4-debounce-a-switch/) |

Modifications kept minimal:

* `Pixel_On_Text2.vhd` had an unconstrained-string generic default
  (`displayText: string := (others => NUL)`) which Quartus accepted but
  GHDL rejects; replaced with `string := ""`.
* Both `Pixel_On_Text*.vhd` now guard the
  `displayText(charPosition)` read with a range check; the original was
  synthesisable (downstream always masks by `inXRange`/`inYRange`) but
  tripped GHDL's bound check at sim time when the raster scanned
  outside the text box.
