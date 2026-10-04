# RV32I CPU + SoC tutorial

A tutorial-grade 32-bit RISC-V computer built bottom-up from the
project's [building blocks](../building_blocks/). Two CPU
implementations (single-cycle and pipelined) execute the same RV32I
hex programs; a small SoC wires the single-cycle core to memory-
mapped UART + two accelerators (SIMD ALU and 4-tap FIR), and a CPU
program drives the SIMD ALU end-to-end through the bus.

### Reading order

1. **[cpu/building_blocks/regfile_rv32](building_blocks/regfile_rv32/)** —
   32 × 32 register file, x0 hardwired to zero. Its selectable write
   edge is falling by default for the pipeline and rising in the
   single-cycle cores so their architectural state commits together.
2. **[cpu/building_blocks/alu_rv32](building_blocks/alu_rv32/)** —
   10-op ALU (R-/I-type arithmetic + signed/unsigned compare).
3. **[cpu/building_blocks/immgen_rv32](building_blocks/immgen_rv32/)** —
   immediate-format generator for the 5 RV32I encodings (I/S/B/U/J).
4. **[cpu/building_blocks/decoder_rv32](building_blocks/decoder_rv32/)** —
   combinational decoder that drives every control-signal in the
   datapath.
5. **[`../building_blocks/ram_sync`](../building_blocks/ram_sync/)** —
   generic synchronous BRAM. Study its read latency before the CPU's
   internal asynchronous-read IMEM/DMEM models; it is a learning
   precursor rather than a directly instantiated CPU memory.
6. **[`../tools/rv32_asm`](../tools/rv32_asm/)** — tiny Python
   assembler that converts a `.S` source to a `.hex` file the CPUs
   load at elaboration.
7. **[cpu/riscv_singlecycle](riscv_singlecycle/)** — textbook flat
   datapath: one instruction completes per clock, no pipeline
   registers. The pedagogically simplest correct RV32I CPU.
8. **[cpu/riscv_soc](riscv_soc/)** — small SoC built around the
   single-cycle CPU: 4 KB DMEM + UART (TX/RX) + SIMD ALU + FIR. A
   demo program (`prog_simd.S`) drives the SIMD ALU and streams the
   result over UART.
9. **[cpu/building_blocks/forwarding_unit](building_blocks/forwarding_unit/)** +
   **[cpu/building_blocks/hazard_detector](building_blocks/hazard_detector/)** —
   the two combinational helpers a 5-stage pipeline needs to handle
   data + control hazards.
10. **[cpu/riscv_pipelined](riscv_pipelined/)** — 5-stage IF/ID/EX/MEM/WB
    with full forwarding, load-use stall, and branch flush. Same hex
    programs run unchanged; reading next to the single-cycle CPU
    shows exactly what pipelining adds.
11. **[cpu/building_blocks/simd_alu](building_blocks/simd_alu/)** —
    packed SIMD ALU (4×8 / 2×16 add/sub/min/max with saturation).
12. **[cpu/building_blocks/fir4tap](building_blocks/fir4tap/)** —
    streaming 4-tap FIR filter using the Cyclone IV hard 9×9
    multipliers.

### Instruction Set Architecture (RV32I) reference card (implemented subset)

| Type | Instructions |
|---|---|
| **R-type** | `add`, `sub`, `and`, `or`, `xor`, `sll`, `srl`, `sra`, `slt`, `sltu` |
| **I-type ALU** | `addi`, `andi`, `ori`, `xori`, `slli`, `srli`, `srai`, `slti`, `sltiu` |
| **Loads / stores** | `lw`, `sw` (word-only — `lb` / `lh` / `sb` / `sh` deferred) |
| **Branches** | `beq`, `bne`, `blt`, `bge`, `bltu`, `bgeu` |
| **Jumps** | `jal`, `jalr` |
| **Upper-immediate** | `lui`, `auipc` |
| **Pseudo-ops** | `nop`, `mv`, `not`, `neg`, `li`, `j`, `jr`, `ret`, `beqz`, `bnez`, `halt` |

**Halt sentinel:** `halt` is a pseudo-instruction for `jal x0, .` (jump
to itself = 0x0000006F). The testbenches detect this on the WB-stage
instruction bus and stop the simulation.

**Not implemented:** FENCE / ECALL / EBREAK, CSRs, interrupts, the
M-extension (multiply/divide), byte/halfword memory ops, FPU.

### SoC MMIO address map

The SoC top
([`cpu/riscv_soc/riscv_soc.vhd`](riscv_soc/riscv_soc.vhd)) splits the
4 GB address space with `addr[31]`: 0 = DMEM, 1 = MMIO. Inside MMIO,
the 6-bit word offset `addr[7:2]` picks the register slot:

| Address | Reg | R/W | Purpose |
|---|---|---|---|
| `0x8000_0000` | UART_TX_DATA  | W: send byte; R: bit 0 = `tx_busy` | UART transmitter |
| `0x8000_0004` | UART_RX_DATA  | R: bits[7:0] = byte, bit 31 = `rx_ready` | UART receiver (read drains latch) |
| `0x8000_0030` | SIMD_OPERAND_A | W | First 32-bit packed operand |
| `0x8000_0034` | SIMD_OPERAND_B | W | Second 32-bit packed operand |
| `0x8000_0038` | SIMD_OP        | W (low 4 bits) | Op encoding (see `simd_alu` README) |
| `0x8000_003C` | SIMD_RESULT    | R | Combinational result of the configured op |
| `0x8000_0040` | SIMD_FLAGS     | R (low 4 bits) | Saturation flag per lane |
| `0x8000_0050` | FIR_COEFFS_01  | W | `coeff_0` in bits[8:0], `coeff_1` in bits[24:16] |
| `0x8000_0054` | FIR_COEFFS_23  | W | `coeff_2` / `coeff_3` (same packing) |
| `0x8000_0058` | FIR_SAMPLE     | W | Write triggers `sample_valid` pulse; bits[15:0] = signed sample |
| `0x8000_005C` | FIR_RESULT     | R | Most recent filter output (sign-extended) |
| `0x8000_0060` | FIR_STATUS     | R | Bit 0 = `result_valid` latch (clears on FIR_RESULT read) |

DMEM lives at any `addr[31]=0` address; the decoder uses
`addr[11:2]` to index the 1024-word array (so addresses
`0x0000_0000`, `0x0001_0000`, `0x0002_0000`, ... all alias to the
same 4 KB).

### Write + assemble + run your own program

1. Write a `.S` file in the subset above. See
   [`cpu/riscv_soc/programs/prog_simd.S`](riscv_soc/programs/prog_simd.S)
   or [`tools/rv32_asm/programs/prog_loop.S`](../tools/rv32_asm/programs/prog_loop.S)
   for working examples.
2. Assemble it with the project's Python assembler:
   ```
   podman run --rm -v "$(pwd):/work:rw" -w /work \
       ghcr.io/naelolaiz/hdltools@sha256:a661d7b9a126fbb44e64d542a19edb9cf1ff7cf70dcf714150a5b03edd2ae312 \
       python3 tools/rv32_asm/rv32_asm.py path/to/prog.S \
           -o path/to/prog.hex
   ```
3. Wire the `.hex` into a CPU testbench via the `IMEM_INIT` generic
   — see e.g. [`cpu/riscv_singlecycle/test/tb_riscv_singlecycle_addi.vhd`](riscv_singlecycle/test/tb_riscv_singlecycle_addi.vhd).
4. Run:
   ```
   podman run --rm -v "$(pwd):/work:rw" \
       -w /work/cpu/riscv_singlecycle \
       ghcr.io/naelolaiz/hdltools@sha256:a661d7b9a126fbb44e64d542a19edb9cf1ff7cf70dcf714150a5b03edd2ae312 make simulate
   ```

The testbench's halt detector fires when your `halt` instruction
retires; the shadow-regfile snoop captures every commit so you can
assert final architectural state.

### Single-cycle vs pipelined: compare standalone execution

The standalone CPUs execute the same hex programs and report commits
through `dbg_*`. Compare their waveforms to see forwarding, stalls,
and branch flushes change the cycle count while preserving final state.
A higher clock-frequency claim also needs synthesis and timing results.

The SoC instantiates its own
[`riscv_singlecycle` variant](riscv_soc/riscv_singlecycle.vhd), which
exposes an external data-memory/MMIO bus. It shares the entity name
with the standalone core but is a separate source file with extra
ports. `riscv_pipelined` has internal DMEM and no matching
bus ports, so changing an entity name cannot connect it to the SoC.
Integration requires a pipelined bus variant, a defined memory response
contract, stall handling for that contract, and tests for UART/MMIO
side effects. This remains a future integration exercise.

### What's still out of scope

The following are intentionally deferred:

- Byte / halfword memory ops (`lb`, `lh`, `sb`, `sh`).
- Interrupts / CSRs / privilege levels / `mtime` / `mtvec` / `mret`
  — the "Next up" item in the top-level [README.md](../README.md);
  needed to turn the polled UART_RX peripheral into a real
  interrupt-driven device.
- M-extension (multiply / divide).
- Cache, branch prediction.
- Full RVV vector extension (the SIMD ALU + FIR accelerators cover
  the SIMD teaching goal at a fraction of the cost).
- Pipelined CPU in the SoC (requires the bus adaptation described
  above; the current demos use the SoC's external-DMEM `riscv_singlecycle`
  variant).
