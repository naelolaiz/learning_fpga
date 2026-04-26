PROJECT_NAME := serial_to_parallel

TOP     := Serial2Parallel
TB_TOPS := tb_serial_to_parallel_basic tb_serial_to_parallel_print_gating

# Cross-project source: this project wraps the shift_register entity
# from building_blocks/shift_register/ rather than reimplementing the
# shift loop. GHDL/iverilog/yosys all accept relative paths in their
# source list, so the include is a path, not a build-system import.
# shift_register comes first so GHDL analyses it before Serial2Parallel
# reaches `entity work.shift_register`.
SRC_FILES := ../shift_register/shift_register.vhd Serial2Parallel.vhd
TB_FILES  := test/tb_serial_to_parallel_basic.vhd \
             test/tb_serial_to_parallel_print_gating.vhd

VHDL_STANDARD := 08

# Diagram tweaks:
#   - SVG_RELABEL rewrites the visible label on the wrapped sub-instance
#     from yosys's auto-generated cruft (`shift_register_Brtl_16` on the
#     VHDL side via ghdl-yosys-plugin, `$paramod\shift_register\WIDTH=…`
#     on the Verilog side) back to the bare `shift_register` name.
#   - SVG_LINKS turns the wrapped sub-instance into a hyperlink to the
#     shift_register project's own diagram in the published gallery —
#     click to drill from the wrapper into the wrapped module's RTL.
#   - SVG_PREVIEW inlines the sibling project's SVG inside the wrapped
#     cell, so the wrapper's diagram shows a thumbnail of the wrapped
#     module's circuit rather than an empty box. Read at build time
#     from the sibling's local build/ dir; the prereqs below trigger
#     that build first when running in CI's parallel matrix (each
#     project's job otherwise builds in isolation).
SVG_RELABEL    := inner=shift_register
V_SVG_RELABEL  := inner=shift_register
SVG_LINKS      := inner=../building_blocks-shift_register/shift_register.svg
V_SVG_LINKS    := inner=../building_blocks-shift_register/shift_register_v.svg
SVG_PREVIEW    := inner=../shift_register/build/shift_register.svg
V_SVG_PREVIEW  := inner=../shift_register/build/shift_register_v.svg

V_TOP       := Serial2Parallel
V_TB_TOPS   := tb_serial_to_parallel_basic tb_serial_to_parallel_print_gating
V_SRC_FILES := ../shift_register/shift_register.v Serial2Parallel.v
V_TB_FILES  := test/tb_serial_to_parallel_basic.v \
               test/tb_serial_to_parallel_print_gating.v

include ../../mk/common.mk

# Cross-project diagram prereqs: SVG_PREVIEW (above) reads the
# sibling shift_register project's SVG at link time, so make sure
# it has been built first. Locally and in CI alike, recurse into
# that project's Makefile if the artifact is missing.
$(DIAGRAM_SVG):   ../shift_register/build/shift_register.svg
$(V_DIAGRAM_SVG): ../shift_register/build/shift_register_v.svg

../shift_register/build/shift_register.svg:
	$(MAKE) -C ../shift_register diagram

../shift_register/build/shift_register_v.svg:
	$(MAKE) -C ../shift_register diagram_v
