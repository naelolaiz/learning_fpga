# riscv_soc — small SoC built around the single-cycle RV32I CPU

The first **runnable computer** in the repo: the single-cycle CPU
from [`cpu/riscv_singlecycle`](../riscv_singlecycle/) wired up with
4 KB of data memory and two memory-mapped UART peripherals (TX +
RX). A hand-assembled program ([`prog_hello.S`](programs/prog_hello.S))
prints `"Hello, RV32!\n"` over the UART; the testbench samples the
TX line and verifies the bytes match.

| File | Purpose |
| ---- | ------- |
| [`riscv_soc.vhd`](riscv_soc.vhd) | SoC top: CPU + DMEM + address decoder + UART peripherals |
| [`riscv_singlecycle.vhd`](riscv_singlecycle.vhd) | CPU variant with the DMEM bus **exposed externally** (so the SoC can route loads/stores to either DMEM or peripherals) |
| [`ram_sync.vhd`](ram_sync.vhd), [`regfile_rv32.vhd`](regfile_rv32.vhd), [`alu_rv32.vhd`](alu_rv32.vhd), [`immgen_rv32.vhd`](immgen_rv32.vhd), [`decoder_rv32.vhd`](decoder_rv32.vhd) | Phase A building blocks (local copies) |
| [`uart_tx.vhd`](uart_tx.vhd), [`uart_rx.vhd`](uart_rx.vhd) | UART pair (local copies of [`comm/uart_tx`](../../comm/uart_tx/) and [`comm/uart_rx`](../../comm/uart_rx/)) |
| [`programs/prog_hello.S`](programs/prog_hello.S), [`programs/prog_hello.hex`](programs/prog_hello.hex) | Demo program (assembly source + golden hex) |
| [`test/tb_riscv_soc.vhd`](test/tb_riscv_soc.vhd) | Boot the SoC, sample UART_TX, verify the greeting |

## Address map

```
0x0000_0000 .. 0x0000_0FFF   IMEM  (4 KB, internal to CPU,
                                   pre-loaded from IMEM_INIT hex)

0x0001_0000 .. 0x0001_0FFF   DMEM  (4 KB, R/W, in the SoC top)
                                   — the decoder uses bit 31 only,
                                   so any non-MMIO address actually
                                   maps modulo 4 KB into DMEM. The
                                   assembler-emitted addresses just
                                   need to honour the plan's base.

0x8000_0000                   UART_TX_DATA
                                   W: send LSB byte
                                   R: bit 0 = tx_busy

0x8000_0004                   UART_RX_DATA
                                   R: bits[7:0] = received byte,
                                      bit 31  = rx_ready (1 if a
                                                byte is waiting)
                                   reading drains the latch
```

The address decoder is one bit (`dmem_addr[31]`): high = MMIO,
low = DMEM. Inside MMIO, `dmem_addr[2]` picks between TX (offset 0)
and RX (offset 4). Crude but plenty for the tutorial peripheral
set; a real SoC would decode finer.

## Datapath

```
                          ┌─────────────────┐
                          │     CPU         │
                          │  (single-cycle) │
                          │                 │
                          │   dmem_addr ────┼──────────────┐
                          │   dmem_wdata ───┼─────────┐    │
                          │   dmem_we ──────┼────┐    │    │
                          │   dmem_re ──────┼─┐  │    │    │
                          │   dmem_rdata <──┼─┼──┼────┼────┼── read mux
                          └─────────────────┘ │  │    │    │
                                              │  │    │    │
                                     ┌────────┴──┴────┴────┴──┐
                                     │   Address decoder       │
                                     │   (bit 31: MMIO vs DMEM)│
                                     └────┬──────────────┬─────┘
                                          │              │
                              ┌───────────▼───────┐  ┌───▼───────────────┐
                              │ DMEM 4 KB         │  │ MMIO peripherals  │
                              │ sync write,       │  │  ─ UART_TX_DATA   │
                              │ async read        │  │  ─ UART_RX_DATA   │
                              └───────────────────┘  └─────┬─────────┬───┘
                                                           │         │
                                                       UART_TX   UART_RX
                                                         (out)    (in)
```

The CPU exposes a 5-port DMEM bus (`addr`, `wdata`, `we`, `re`,
`rdata`). The SoC top gates the write (`dmem_we_q = we ∧ ¬is_mmio`,
`mmio_we = we ∧ is_mmio`), routes the read mux based on `is_mmio`
and `dmem_addr[2]`, and wires the rest.

## UART peripheral semantics

**TX** — write any byte to `0x8000_0000`. The peripheral checks
`tx_busy` and gates the write internally: if the UART is mid-frame
the write is dropped. The program polls `tx_busy` (read from the
same address, bit 0) before each write.

**RX** — when the receiver pulses `rx_valid`, the SoC latches the
byte + sets `rx_ready_latch`. Reading `0x8000_0004` returns
`{rx_ready, 23 zero bits, 8 data bits}` and drains the latch. If a
new byte arrives before the CPU reads, the new byte overwrites the
latch (single-entry buffer; at 9600 baud and a 50 MHz CPU the
margin is enormous).

## Demo program

[`prog_hello.S`](programs/prog_hello.S) sends "Hello, RV32!\n"
through 13 calls to a small `send_byte` subroutine that polls
`tx_busy` and then stores the character. The whole program is ~30
instructions, well under the 1024-word IMEM. Uses `lui` to
materialise the MMIO base address (since 0x80000000 doesn't fit in
a single ADDI's 12-bit signed immediate).

`make golden` re-assembles the program with
[`tools/rv32_asm`](../../tools/rv32_asm/) and regenerates the hex.

## Testbench

[`tb_riscv_soc.vhd`](test/tb_riscv_soc.vhd) boots the SoC with the
demo program in IMEM, samples the UART_TX line bit-by-bit (start
bit → 8 data bits LSB first → stop bit), captures each byte, and
asserts the running prefix matches "Hello, RV32!\n". The
`CLKS_PER_BIT` generic is overridden to 8 (vs. the board default
5208 for 50 MHz / 9600 baud) so the simulation completes in ~22 µs
instead of ~14 ms.

A subtle gotcha caught during verification: the sampler must NOT
exit when the CPU's HALT instruction is detected — halt fires
~5 cycles after the last `sw` that triggers UART transmission,
but the UART itself takes ~80 cycles per byte to finish framing.
Exiting on halt drops the last byte mid-flight. The driver
process bounds total simulation time instead.

## What's still on the roadmap

The plan called for additional MMIO peripherals (`GPIO_LEDS`,
debounced `GPIO_BUTTONS`, `SEG7_DATA` reusing
[`display/7segments/counter`](../../display/7segments/counter/)'s
digit-mux core). The current SoC stops at UART; adding the rest is
a straightforward extension of the same address decoder and
read-mux pattern.

The board-synthesis flow (Quartus, RZ EasyFPGA A2.2 pin mapping in
a `.qsf`) is also pending — simulation passes, but flashing to the
Cyclone IV needs the pin definitions for `clk_50mhz`, `rst_n`,
`uart_rx_in`, `uart_tx_out`.
