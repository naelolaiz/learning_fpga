# ram_sync — single-port synchronous BRAM

A parameterised, single-port synchronous RAM with optional hex-file
initialisation. Both writes and reads are clocked, the storage is sized
as a power of two so it maps cleanly to a Cyclone IV block RAM, and the
init path uses the same `$readmemh` / VHDL `textio` convention that
[`rom_lut/`](../rom_lut/) established for read-only data.

This is the memory primitive the upcoming RV32I CPU will use as both
its instruction memory (initialised from a hex file produced by the
assembler) and its data memory (left zero-initialised, written at
runtime).

| File | Purpose |
| ---- | ------- |
| [`ram_sync.vhd`](ram_sync.vhd) | VHDL design |
| [`ram_sync.v`](ram_sync.v) | Verilog mirror |
| [`test/tb_ram_sync.vhd`](test/tb_ram_sync.vhd), [`test/tb_ram_sync.v`](test/tb_ram_sync.v) | Self-checking testbenches |

## Generics / parameters

| Name | Default | Meaning |
| ---- | ------- | ------- |
| `WIDTH` | 32 | Word width in bits |
| `ADDR_W` | 10 | Address width in bits — **depth is `2**ADDR_W`** |
| `INIT_FILE` | `""` | Optional hex file (`$readmemh` format). Empty string = zero-init |

## Two design notes worth knowing

**Storage is a `signal`, not a `constant`.** Quartus refuses to map a
`constant` array to a BRAM and emits the table as logic elements
instead — wasting both LE budget and BRAM availability. The
[`ROM_LUT.vhd`](../rom_lut/ROM_LUT.vhd) header in this repo flags the
same quirk; we follow the same pattern here.

**The address width is the generic, depth is derived.** `DEPTH = 2**ADDR_W`
inside the architecture. The entity port list deliberately avoids
`ieee.math_real` / `$clog2` to compute the address-port width from a
depth generic — those work in modern Quartus but have well-known
cross-tool quirks (older Vivado, ISE, ghdl-yosys-plugin edge cases),
and [`fifo_sync.vhd`](../fifo_sync/fifo_sync.vhd) avoids them too by
keeping its `clog2` function inside the architecture body.

## Read-before-write semantics

On a same-cycle write+read of the same address, `rdata` carries the
**old** value (the value that was at `addr` *before* this clock edge).
Both VHDL and Verilog produce this behaviour identically — the VHDL
falls out of signal scheduling, the Verilog falls out of NBA
scheduling — and Quartus / yosys both infer a BRAM in
`OLD_DATA`/read-before-write mode for this shape. The testbench
explicitly covers this.

## Test strategy

[`tb_ram_sync.vhd`](test/tb_ram_sync.vhd) and its Verilog twin
instantiate the RAM at `WIDTH=4, ADDR_W=4` (16 entries) so the FST
waveform stays readable. The testbench:

1. Writes addr `i → (15 - i)` at every location.
2. Reads each location back and asserts the stored value.
3. Issues a same-cycle write+read of address 5 (overwriting the stored
   `10` with `3`) and asserts `rdata == 10` (old value, read-before-write).
4. Reads address 5 the next cycle and asserts `rdata == 3` (new value
   committed).

The init-from-file path is exercised implicitly later in the project,
when the CPU's IMEM is loaded from a hex file produced by the
assembler.
