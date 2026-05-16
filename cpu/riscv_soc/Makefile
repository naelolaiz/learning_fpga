PROJECT_NAME := riscv_soc

TOP     := riscv_soc
TB_TOPS := tb_riscv_soc

# Building blocks the SoC composes. Generic blocks live under the
# top-level building_blocks/; RV32-specific blocks live under
# cpu/building_blocks/; comm peripherals stay in comm/. Sourced via
# relative paths so there's a single source of truth — no duplicate
# copies in this directory.
SRC_FILES := ../../building_blocks/ram_sync/ram_sync.vhd \
             ../building_blocks/regfile_rv32/regfile_rv32.vhd \
             ../building_blocks/alu_rv32/alu_rv32.vhd \
             ../building_blocks/immgen_rv32/immgen_rv32.vhd \
             ../building_blocks/decoder_rv32/decoder_rv32.vhd \
             ../../comm/uart_tx/uart_tx.vhd \
             ../../comm/uart_rx/uart_rx.vhd \
             riscv_singlecycle.vhd \
             riscv_soc.vhd

TB_FILES  := test/tb_riscv_soc.vhd

VHDL_STANDARD := 08

# Bump Node V8 stack for netlistsvg — the SoC synthesises to a wide
# mux+wire tree that trips netlistsvg's recursive `gather` on the
# default ~1 MB JS stack. Override _BIN only so the project inherits
# the shared skin from common.mk's NETLISTSVG_SKIN default.
NETLISTSVG_BIN := node --stack-size=8000 $$(command -v netlistsvg)

# Verilog mirror — same composition, sourced from the .v twins of
# each building block. The two flows are bit-equivalent on the
# Hello-RV32 demo program.
V_TOP       := riscv_soc
V_TB_TOPS   := tb_riscv_soc
V_SRC_FILES := ../../building_blocks/ram_sync/ram_sync.v \
               ../building_blocks/regfile_rv32/regfile_rv32.v \
               ../building_blocks/alu_rv32/alu_rv32.v \
               ../building_blocks/immgen_rv32/immgen_rv32.v \
               ../building_blocks/decoder_rv32/decoder_rv32.v \
               ../../comm/uart_tx/uart_tx.v \
               ../../comm/uart_rx/uart_rx.v \
               riscv_singlecycle.v \
               riscv_soc.v
V_TB_FILES  := test/tb_riscv_soc.v

# Diagram tweaks — same composite pattern as
# building_blocks/serial_to_parallel: each submodule instance in the
# rendered top-level SVG is relabelled, linked to its standalone SVG
# in the gallery, and shows a live thumbnail of that SVG embedded
# in-place. Cell IDs:
#   * Entity instances in riscv_soc.vhd: cpu, tx, rx.
#   * yosys's memory_collect pass turns the SoC's `signal dmem` array
#     into a $mem_v2 cell named cell_dmem; link/preview it against
#     ram_sync, the reference sync R/W BRAM block this implements.
#     No relabel — the skin's $mem_v2 symbol uses a static "RAM"
#     label; "RAM" is the right label anyway.
SVG_RELABEL := cpu=riscv_singlecycle \
               tx=uart_tx \
               rx=uart_rx

SVG_LINKS   := cpu=../cpu-riscv_singlecycle/riscv_singlecycle.svg \
               tx=../comm-uart_tx/uart_tx.svg \
               rx=../comm-uart_rx/uart_rx.svg \
               dmem=../building_blocks-ram_sync/ram_sync.svg

SVG_PREVIEW := cpu=../riscv_singlecycle/build/riscv_singlecycle.svg \
               tx=../../comm/uart_tx/build/uart_tx.svg \
               rx=../../comm/uart_rx/build/uart_rx.svg \
               dmem=../../building_blocks/ram_sync/build/ram_sync.svg

# Same composite annotations on the Verilog side.
V_SVG_RELABEL := cpu=riscv_singlecycle \
                 tx=uart_tx \
                 rx=uart_rx

V_SVG_LINKS   := cpu=../cpu-riscv_singlecycle/riscv_singlecycle_v.svg \
                 tx=../comm-uart_tx/uart_tx_v.svg \
                 rx=../comm-uart_rx/uart_rx_v.svg \
                 dmem=../building_blocks-ram_sync/ram_sync_v.svg

V_SVG_PREVIEW := cpu=../riscv_singlecycle/build/riscv_singlecycle_v.svg \
                 tx=../../comm/uart_tx/build/uart_tx_v.svg \
                 rx=../../comm/uart_rx/build/uart_rx_v.svg \
                 dmem=../../building_blocks/ram_sync/build/ram_sync_v.svg

# `make golden` re-assembles programs/prog_hello.S into prog_hello.hex
# using the project's Python assembler. Review the diff before
# committing the new .hex.
.PHONY: golden
golden:
	python3 ../../tools/rv32_asm/rv32_asm.py programs/prog_hello.S \
	    -o programs/prog_hello.hex
	@echo "regenerated programs/prog_hello.hex"

include ../../mk/common.mk

# Cross-project diagram prereqs: SVG_PREVIEW (above) reads each
# sibling project's SVG at link time. Build them first if missing.
$(DIAGRAM_SVG): ../riscv_singlecycle/build/riscv_singlecycle.svg \
                ../../comm/uart_tx/build/uart_tx.svg \
                ../../comm/uart_rx/build/uart_rx.svg \
                ../../building_blocks/ram_sync/build/ram_sync.svg

$(V_DIAGRAM_SVG): ../riscv_singlecycle/build/riscv_singlecycle_v.svg \
                  ../../comm/uart_tx/build/uart_tx_v.svg \
                  ../../comm/uart_rx/build/uart_rx_v.svg \
                  ../../building_blocks/ram_sync/build/ram_sync_v.svg

../riscv_singlecycle/build/riscv_singlecycle.svg:
	$(MAKE) -C ../riscv_singlecycle diagram
../../comm/uart_tx/build/uart_tx.svg:
	$(MAKE) -C ../../comm/uart_tx diagram
../../comm/uart_rx/build/uart_rx.svg:
	$(MAKE) -C ../../comm/uart_rx diagram
../../building_blocks/ram_sync/build/ram_sync.svg:
	$(MAKE) -C ../../building_blocks/ram_sync diagram

../riscv_singlecycle/build/riscv_singlecycle_v.svg:
	$(MAKE) -C ../riscv_singlecycle diagram_v
../../comm/uart_tx/build/uart_tx_v.svg:
	$(MAKE) -C ../../comm/uart_tx diagram_v
../../comm/uart_rx/build/uart_rx_v.svg:
	$(MAKE) -C ../../comm/uart_rx diagram_v
../../building_blocks/ram_sync/build/ram_sync_v.svg:
	$(MAKE) -C ../../building_blocks/ram_sync diagram_v
