PROJECT_NAME := riscv_pipelined

TOP     := riscv_pipelined
TB_TOPS := tb_riscv_pipelined_addi \
           tb_riscv_pipelined_loop \
           tb_riscv_pipelined_branches \
           tb_riscv_pipelined_load_use

# Building blocks the CPU composes. Generic blocks live under the
# top-level building_blocks/; RV32-specific blocks live under
# cpu/building_blocks/. Sourced via relative paths so there's a
# single source of truth — no duplicate copies in this directory.
SRC_FILES := ../../building_blocks/ram_sync/ram_sync.vhd \
             ../building_blocks/regfile_rv32/regfile_rv32.vhd \
             ../building_blocks/alu_rv32/alu_rv32.vhd \
             ../building_blocks/immgen_rv32/immgen_rv32.vhd \
             ../building_blocks/decoder_rv32/decoder_rv32.vhd \
             ../building_blocks/forwarding_unit/forwarding_unit.vhd \
             ../building_blocks/hazard_detector/hazard_detector.vhd \
             riscv_pipelined.vhd

TB_FILES  := test/tb_riscv_pipelined_addi.vhd \
             test/tb_riscv_pipelined_loop.vhd \
             test/tb_riscv_pipelined_branches.vhd \
             test/tb_riscv_pipelined_load_use.vhd

VHDL_STANDARD := 08

# Bumped Node V8 stack — the synthesised pipelined CPU has even more
# combinational paths than the single-cycle version (forwarding muxes
# add 3:1 selects at each ALU input, plus the wide pipeline registers
# get rendered as individual cells). Same workaround as the
# single-cycle CPU; inherit the netlistsvg defaults from common.mk.
NETLISTSVG_BIN := node --stack-size=8000 $$(command -v netlistsvg)

# Verilog mirror — same composition, sourced from the .v twins of
# each building block including the new pipeline-specific helpers
# (forwarding_unit, hazard_detector).
V_TOP       := riscv_pipelined
V_TB_TOPS   := tb_riscv_pipelined_addi \
               tb_riscv_pipelined_loop \
               tb_riscv_pipelined_branches \
               tb_riscv_pipelined_load_use
V_SRC_FILES := ../../building_blocks/ram_sync/ram_sync.v \
               ../building_blocks/regfile_rv32/regfile_rv32.v \
               ../building_blocks/alu_rv32/alu_rv32.v \
               ../building_blocks/immgen_rv32/immgen_rv32.v \
               ../building_blocks/decoder_rv32/decoder_rv32.v \
               ../building_blocks/forwarding_unit/forwarding_unit.v \
               ../building_blocks/hazard_detector/hazard_detector.v \
               riscv_pipelined.v
V_TB_FILES  := test/tb_riscv_pipelined_addi.v \
               test/tb_riscv_pipelined_loop.v \
               test/tb_riscv_pipelined_branches.v \
               test/tb_riscv_pipelined_load_use.v

# Diagram tweaks. Cell IDs match the entity instance labels in
# riscv_pipelined.vhd (decoder, immgen, regfile, alu, fu, hd). dmem
# links to ram_sync the same way the single-cycle CPU's diagram does.
SVG_RELABEL := decoder=decoder_rv32 \
               immgen=immgen_rv32 \
               regfile=regfile_rv32 \
               alu=alu_rv32 \
               fu=forwarding_unit \
               hd=hazard_detector

SVG_LINKS   := decoder=../cpu-building_blocks-decoder_rv32/decoder_rv32.svg \
               immgen=../cpu-building_blocks-immgen_rv32/immgen_rv32.svg \
               regfile=../cpu-building_blocks-regfile_rv32/regfile_rv32.svg \
               alu=../cpu-building_blocks-alu_rv32/alu_rv32.svg \
               fu=../cpu-building_blocks-forwarding_unit/forwarding_unit.svg \
               hd=../cpu-building_blocks-hazard_detector/hazard_detector.svg \
               dmem=../building_blocks-ram_sync/ram_sync.svg \
               regs=../cpu-building_blocks-regfile_rv32/regfile_rv32.svg

# Same annotations on the Verilog side.
V_SVG_RELABEL := decoder=decoder_rv32 \
                 immgen=immgen_rv32 \
                 regfile=regfile_rv32 \
                 alu=alu_rv32 \
                 fu=forwarding_unit \
                 hd=hazard_detector

V_SVG_LINKS   := decoder=../cpu-building_blocks-decoder_rv32/decoder_rv32_v.svg \
                 immgen=../cpu-building_blocks-immgen_rv32/immgen_rv32_v.svg \
                 regfile=../cpu-building_blocks-regfile_rv32/regfile_rv32_v.svg \
                 alu=../cpu-building_blocks-alu_rv32/alu_rv32_v.svg \
                 fu=../cpu-building_blocks-forwarding_unit/forwarding_unit_v.svg \
                 hd=../cpu-building_blocks-hazard_detector/hazard_detector_v.svg \
                 dmem=../building_blocks-ram_sync/ram_sync_v.svg \
                 regs=../cpu-building_blocks-regfile_rv32/regfile_rv32_v.svg

include ../../mk/common.mk
