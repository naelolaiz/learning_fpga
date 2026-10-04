PROJECT_NAME := riscv_singlecycle

TOP     := riscv_singlecycle
TB_TOPS := tb_riscv_singlecycle_addi \
           tb_riscv_singlecycle_loop \
           tb_riscv_singlecycle_branches \
           tb_riscv_singlecycle_jalr

# Building blocks the CPU composes. Generic blocks live under the
# top-level building_blocks/; RV32-specific blocks live under
# cpu/building_blocks/. Sourced via relative paths so there's a
# single source of truth — no duplicate copies in this directory.
SRC_FILES := ../../building_blocks/ram_sync/ram_sync.vhd \
             ../building_blocks/regfile_rv32/regfile_rv32.vhd \
             ../building_blocks/alu_rv32/alu_rv32.vhd \
             ../building_blocks/immgen_rv32/immgen_rv32.vhd \
             ../building_blocks/decoder_rv32/decoder_rv32.vhd \
             riscv_singlecycle.vhd

TB_FILES  := test/tb_riscv_singlecycle_addi.vhd \
             test/tb_riscv_singlecycle_loop.vhd \
             test/tb_riscv_singlecycle_branches.vhd \
             test/tb_riscv_singlecycle_jalr.vhd

VHDL_STANDARD := 08

# Bumped Node V8 stack — the synthesised CPU is a wide combinational
# tree (decoder + 5 building blocks + branch comparator + muxes) that
# trips netlistsvg's recursive `gather` on the default ~1 MB stack.
# Override NETLISTSVG_BIN (not NETLISTSVG) so the project still
# inherits the config defaults from common.mk.
NETLISTSVG_BIN := node --stack-size=8000 $$(command -v netlistsvg)

# Verilog mirror — same composition as the VHDL side, but sourced
# from the .v twins of each building block. The two flows produce
# bit-equivalent behaviour on every hex program.
V_TOP       := riscv_singlecycle
V_TB_TOPS   := tb_riscv_singlecycle_addi \
               tb_riscv_singlecycle_loop \
               tb_riscv_singlecycle_branches \
               tb_riscv_singlecycle_jalr
V_SRC_FILES := ../../building_blocks/ram_sync/ram_sync.v \
               ../building_blocks/regfile_rv32/regfile_rv32.v \
               ../building_blocks/alu_rv32/alu_rv32.v \
               ../building_blocks/immgen_rv32/immgen_rv32.v \
               ../building_blocks/decoder_rv32/decoder_rv32.v \
               riscv_singlecycle.v
V_TB_FILES  := test/tb_riscv_singlecycle_addi.v \
               test/tb_riscv_singlecycle_loop.v \
               test/tb_riscv_singlecycle_branches.v \
               test/tb_riscv_singlecycle_jalr.v

include ../../mk/common.mk
