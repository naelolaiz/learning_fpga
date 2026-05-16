PROJECT_NAME := riscv_singlecycle

TOP     := riscv_singlecycle
TB_TOPS := tb_riscv_singlecycle_addi \
           tb_riscv_singlecycle_loop \
           tb_riscv_singlecycle_branches

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
             test/tb_riscv_singlecycle_branches.vhd

VHDL_STANDARD := 08

# Bumped Node V8 stack — the synthesised CPU is a wide combinational
# tree (decoder + 5 building blocks + branch comparator + muxes) that
# trips netlistsvg's recursive `gather` on the default ~1 MB stack.
# Override NETLISTSVG_BIN (not NETLISTSVG) so the project still
# inherits the shared skin from common.mk's NETLISTSVG_SKIN default.
NETLISTSVG_BIN := node --stack-size=8000 $$(command -v netlistsvg)

# Verilog mirror — same composition as the VHDL side, but sourced
# from the .v twins of each building block. The two flows produce
# bit-equivalent behaviour on every hex program.
V_TOP       := riscv_singlecycle
V_TB_TOPS   := tb_riscv_singlecycle_addi \
               tb_riscv_singlecycle_loop \
               tb_riscv_singlecycle_branches
V_SRC_FILES := ../../building_blocks/ram_sync/ram_sync.v \
               ../building_blocks/regfile_rv32/regfile_rv32.v \
               ../building_blocks/alu_rv32/alu_rv32.v \
               ../building_blocks/immgen_rv32/immgen_rv32.v \
               ../building_blocks/decoder_rv32/decoder_rv32.v \
               riscv_singlecycle.v
V_TB_FILES  := test/tb_riscv_singlecycle_addi.v \
               test/tb_riscv_singlecycle_loop.v \
               test/tb_riscv_singlecycle_branches.v

# Diagram tweaks — same composite pattern as
# building_blocks/serial_to_parallel: each submodule instance in the
# rendered top-level SVG is relabelled, linked to its standalone SVG
# in the gallery, and shows a live thumbnail of that SVG embedded
# in-place. Cell IDs:
#   * Entity instances in riscv_singlecycle.vhd: decoder, immgen,
#     regfile, alu.
#   * yosys's memory_collect pass turns the `signal dmem` array into
#     a $mem_v2 cell named cell_dmem; link/preview it against
#     ram_sync, the reference sync R/W BRAM block this implements.
#     No relabel — the skin's $mem_v2 symbol uses a static "RAM"
#     label (not parameterised by $cell_id), so svg_add_links'
#     relabel pass can't target it; "RAM" is the right label anyway.
SVG_RELABEL := decoder=decoder_rv32 \
               immgen=immgen_rv32 \
               regfile=regfile_rv32 \
               alu=alu_rv32

SVG_LINKS   := decoder=../cpu-building_blocks-decoder_rv32/decoder_rv32.svg \
               immgen=../cpu-building_blocks-immgen_rv32/immgen_rv32.svg \
               regfile=../cpu-building_blocks-regfile_rv32/regfile_rv32.svg \
               alu=../cpu-building_blocks-alu_rv32/alu_rv32.svg \
               dmem=../building_blocks-ram_sync/ram_sync.svg

SVG_PREVIEW := decoder=../building_blocks/decoder_rv32/build/decoder_rv32.svg \
               immgen=../building_blocks/immgen_rv32/build/immgen_rv32.svg \
               regfile=../building_blocks/regfile_rv32/build/regfile_rv32.svg \
               alu=../building_blocks/alu_rv32/build/alu_rv32.svg \
               dmem=../../building_blocks/ram_sync/build/ram_sync.svg

# Same composite annotations on the Verilog side. The cell IDs match
# the instance names in riscv_singlecycle.v (which mirror the VHDL's
# entity-instance labels). The gallery URL convention adds a `_v`
# suffix to distinguish Verilog netlists from VHDL.
V_SVG_RELABEL := decoder=decoder_rv32 \
                 immgen=immgen_rv32 \
                 regfile=regfile_rv32 \
                 alu=alu_rv32

V_SVG_LINKS   := decoder=../cpu-building_blocks-decoder_rv32/decoder_rv32_v.svg \
                 immgen=../cpu-building_blocks-immgen_rv32/immgen_rv32_v.svg \
                 regfile=../cpu-building_blocks-regfile_rv32/regfile_rv32_v.svg \
                 alu=../cpu-building_blocks-alu_rv32/alu_rv32_v.svg \
                 dmem=../building_blocks-ram_sync/ram_sync_v.svg

V_SVG_PREVIEW := decoder=../building_blocks/decoder_rv32/build/decoder_rv32_v.svg \
                 immgen=../building_blocks/immgen_rv32/build/immgen_rv32_v.svg \
                 regfile=../building_blocks/regfile_rv32/build/regfile_rv32_v.svg \
                 alu=../building_blocks/alu_rv32/build/alu_rv32_v.svg \
                 dmem=../../building_blocks/ram_sync/build/ram_sync_v.svg

include ../../mk/common.mk

# Cross-project diagram prereqs: SVG_PREVIEW (above) reads each
# sibling building-block project's SVG at link time, so make sure
# they have been built first. Locally and in CI alike, recurse into
# each sibling Makefile if the artifact is missing.
$(DIAGRAM_SVG): ../building_blocks/decoder_rv32/build/decoder_rv32.svg \
                ../building_blocks/immgen_rv32/build/immgen_rv32.svg \
                ../building_blocks/regfile_rv32/build/regfile_rv32.svg \
                ../building_blocks/alu_rv32/build/alu_rv32.svg \
                ../../building_blocks/ram_sync/build/ram_sync.svg

$(V_DIAGRAM_SVG): ../building_blocks/decoder_rv32/build/decoder_rv32_v.svg \
                  ../building_blocks/immgen_rv32/build/immgen_rv32_v.svg \
                  ../building_blocks/regfile_rv32/build/regfile_rv32_v.svg \
                  ../building_blocks/alu_rv32/build/alu_rv32_v.svg \
                  ../../building_blocks/ram_sync/build/ram_sync_v.svg

../building_blocks/decoder_rv32/build/decoder_rv32.svg:
	$(MAKE) -C ../building_blocks/decoder_rv32 diagram
../building_blocks/immgen_rv32/build/immgen_rv32.svg:
	$(MAKE) -C ../building_blocks/immgen_rv32 diagram
../building_blocks/regfile_rv32/build/regfile_rv32.svg:
	$(MAKE) -C ../building_blocks/regfile_rv32 diagram
../building_blocks/alu_rv32/build/alu_rv32.svg:
	$(MAKE) -C ../building_blocks/alu_rv32 diagram
../../building_blocks/ram_sync/build/ram_sync.svg:
	$(MAKE) -C ../../building_blocks/ram_sync diagram

../building_blocks/decoder_rv32/build/decoder_rv32_v.svg:
	$(MAKE) -C ../building_blocks/decoder_rv32 diagram_v
../building_blocks/immgen_rv32/build/immgen_rv32_v.svg:
	$(MAKE) -C ../building_blocks/immgen_rv32 diagram_v
../building_blocks/regfile_rv32/build/regfile_rv32_v.svg:
	$(MAKE) -C ../building_blocks/regfile_rv32 diagram_v
../building_blocks/alu_rv32/build/alu_rv32_v.svg:
	$(MAKE) -C ../building_blocks/alu_rv32 diagram_v
../../building_blocks/ram_sync/build/ram_sync_v.svg:
	$(MAKE) -C ../../building_blocks/ram_sync diagram_v
