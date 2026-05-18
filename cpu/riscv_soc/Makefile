PROJECT_NAME := riscv_soc

TOP     := riscv_soc
TB_TOPS := tb_riscv_soc tb_riscv_soc_simd

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
             ../building_blocks/simd_alu/simd_alu.vhd \
             ../building_blocks/fir4tap/fir4tap.vhd \
             ../../comm/uart_tx/uart_tx.vhd \
             ../../comm/uart_rx/uart_rx.vhd \
             riscv_singlecycle.vhd \
             riscv_soc.vhd

TB_FILES  := test/tb_riscv_soc.vhd \
             test/tb_riscv_soc_simd.vhd

VHDL_STANDARD := 08

# Bump Node V8 stack for netlistsvg — the SoC synthesises to a wide
# mux+wire tree that trips netlistsvg's recursive `gather` on the
# default ~1 MB JS stack. Override _BIN only so the project inherits
# the config defaults from common.mk.
NETLISTSVG_BIN := node --stack-size=8000 $$(command -v netlistsvg)

# Verilog mirror — same composition, sourced from the .v twins of
# each building block. The two flows are bit-equivalent on the
# Hello-RV32 demo program.
V_TOP       := riscv_soc
V_TB_TOPS   := tb_riscv_soc tb_riscv_soc_simd
V_SRC_FILES := ../../building_blocks/ram_sync/ram_sync.v \
               ../building_blocks/regfile_rv32/regfile_rv32.v \
               ../building_blocks/alu_rv32/alu_rv32.v \
               ../building_blocks/immgen_rv32/immgen_rv32.v \
               ../building_blocks/decoder_rv32/decoder_rv32.v \
               ../building_blocks/simd_alu/simd_alu.v \
               ../building_blocks/fir4tap/fir4tap.v \
               ../../comm/uart_tx/uart_tx.v \
               ../../comm/uart_rx/uart_rx.v \
               riscv_singlecycle.v \
               riscv_soc.v
V_TB_FILES  := test/tb_riscv_soc.v test/tb_riscv_soc_simd.v


# `make golden` re-assembles programs/prog_hello.S into prog_hello.hex
# using the project's Python assembler. Review the diff before
# committing the new .hex.
.PHONY: golden
golden:
	python3 ../../tools/rv32_asm/rv32_asm.py programs/prog_hello.S \
	    -o programs/prog_hello.hex
	@echo "regenerated programs/prog_hello.hex"

include ../../mk/common.mk
