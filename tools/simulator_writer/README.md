A 5-pin "logic-analyser printer".

The module drives 5 output pins (`outLines[4:0]`). On each pin the
*clock itself* appears only when the matching row of a 5×5 character
bitmap is currently lit; otherwise the pin is held low. Sample those
5 pins on a logic analyser as a single trace per pin and the captured
waveform draws the characters of a string side-by-side — the original
author's "HE110W" pun, extended here to "Hello world!".

The trick is that you don't need a display at all: the bench
instrument *is* the display.

### Two implementations

| File | String selection | Notes |
|---|---|---|
| [`tl_simulator_writer.vhd`](tl_simulator_writer.vhd) | `myString` generic (`string` type) | The string is built at elaboration; each character's bitmap is selected by `case vCurrentCharIdx`. |
| [`tl_simulator_writer.v`](tl_simulator_writer.v) | Hard-coded | Verilog has no equivalent of VHDL's `string` generic, so the character sequence is baked into the `case (vCurrentCharIdx)` statement. `STRING_LENGTH` is the only knob — extend the case if you change it. |

The two are functionally equivalent and the testbench (one VHDL TB +
one Verilog TB) asserts the same waveform from both.

### Implementation notes

**`reg [4:0][4:0] sCurrentChar`  —  packed, not unpacked.**

The natural Verilog shape for a 5×5 glyph buffer is the unpacked
form `reg [4:0] sCurrentChar [0:4]`, but that triggers yosys's
`memory_collect` pass — it sees an indexable array and asks "memory
or registers?". 25 bits is far below any FPGA memory primitive's
minimum, so yosys falls back to flip-flops AND prints:

    Warning: Replacing memory \sCurrentChar with list of registers.

Same hardware either way, but the warning is noise. Declaring the
buffer as a **packed** 2-D register — `reg [4:0][4:0] sCurrentChar`
— tells yosys "this is one 25-bit flat register, please don't
memory-infer it." Access syntax (`sCurrentChar[row][bit]`) is
unchanged. Warning gone.

The trade-off lives in the access path: iverilog accepts packed 2-D
arrays but **rejects variable-index access** into them
(`sCurrentChar[i]` with runtime `i` fails to compile). The original
single-line `for (i = 0; ...)` loop is unrolled to five constant-
indexed statements `sCurrentChar[0]`, `sCurrentChar[1]`, …,
`sCurrentChar[4]`. More verbose source, identical synthesis. The
trade-off is documented inline at the unroll site.

The VHDL twin uses a plain `type tChar is array (0 to 4) of
std_logic_vector(4 downto 0)`, which GHDL handles without complaint
— the packed/unpacked distinction is Verilog-specific.

### Run

    make            # build, simulate, render waveform + netlist
    make simulate   # GHDL + iverilog only
    make waveform   # render the FST → PNG
    make diagram    # render the synthesised netlist → SVG

The captured waveform PNG is what you would see on the logic analyser
if you flashed this onto a board and probed `outLines[4:0]`.
