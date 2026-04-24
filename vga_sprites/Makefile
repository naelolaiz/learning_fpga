PROJECT_NAME := vga_sprites

# Three focused testbenches, each renders its own VCD + PNG in CI:
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

include ../mk/common.mk
