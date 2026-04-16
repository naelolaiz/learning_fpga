PROJECT_NAME := unnamed_fpga_game

# The current testbench exercises the trigonometric module. `definitions`
# and `sprite` are pulled in because they are dependencies of the full
# design, even when the TB itself only instantiates `trigonometric`.
TOP     := trigonometric
TB_TOP  := tb_trigonometric

SRC_FILES := definitions.vhd trigonometric.vhd sprite.vhd
TB_FILES  := test/tb_trigonometric.vhd

VHDL_STANDARD := 08

include ../mk/common.mk
