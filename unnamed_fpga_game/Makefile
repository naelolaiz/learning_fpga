PROJECT_NAME := unnamed_fpga_game

# The testbench exercises trigonometric helpers through `tb_trigonometric`.
# `definitions` and `sprite` are analysed alongside so any break in the
# rest of the design shows up at CI time, even though the TB itself
# doesn't instantiate `sprite`.
#
# SKIP_DIAGRAM: yosys+ghdl-plugin can't synthesise `sprite` today — it
# trips over the `abs()` call in trigonometric.vhd (a GHDL/plugin
# interaction). Until either the plugin supports it or a synth-friendly
# top-level wrapper lands, we skip the diagram step for this project so
# CI stays green.
TOP     := sprite
TB_TOP  := tb_trigonometric

SRC_FILES := definitions.vhd trigonometric.vhd sprite.vhd
TB_FILES  := test/tb_trigonometric.vhd

VHDL_STANDARD := 08
SKIP_DIAGRAM  := 1

include ../mk/common.mk
