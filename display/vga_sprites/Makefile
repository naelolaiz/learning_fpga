PROJECT_NAME := vga_sprites

# Three focused testbenches, each renders its own FST + PNG in CI:
#   tb_trigonometric      integration sweep + algebraic property checks
#                         on the rotate() function and LUT.
#   tb_multiply_by_sin_lut unit tests for the multiplyBySinLUT primitive.
#   tb_sprite_gravity     sprite entity with gravity on, checks the
#                         fall/bounce path end-to-end.
TOP     := sprite
TB_TOPS := tb_trigonometric tb_multiply_by_sin_lut tb_sprite_gravity

SRC_FILES := definitions.vhd trigonometric.vhd sprite.vhd
TB_FILES  := test/tb_trigonometric.vhd \
             test/tb_multiply_by_sin_lut.vhd \
             test/tb_sprite_gravity.vhd

VHDL_STANDARD := 08

# Verilog mirror. sprite.v + its three TBs pair 1:1 with the VHDL
# above; trigonometric_functions.vh is ``include``d inside each module
# that needs it, so V_INCDIRS covers both the synth path and the
# testbench build.
V_TOP       := sprite
V_TB_TOPS   := tb_trigonometric tb_multiply_by_sin_lut tb_sprite_gravity
V_SRC_FILES := sprite.v
V_TB_FILES  := test/tb_trigonometric.v \
               test/tb_multiply_by_sin_lut.v \
               test/tb_sprite_gravity.v
V_INCDIRS   := .

include ../../mk/common.mk
