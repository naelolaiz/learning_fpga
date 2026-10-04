PROJECT_NAME := vga_sprites

# Six focused testbenches, each renders its own FST + PNG in CI:
#   tb_trigonometric      integration sweep + algebraic property checks
#                         on the rotate() function and LUT.
#   tb_multiply_by_sin_lut unit tests for the multiplyBySinLUT primitive.
#   tb_sprite_rotator     the pipelined rotator against rotate(), for
#                         every rotation step and sprite position.
#   tb_sprite_raster      a full screen scan of a rotated sprite against
#                         a one-step reference: picture and latency.
#   tb_sprite_gravity     sprite entity with gravity on, checks the
#                         fall/bounce path end-to-end.
#   tb_vga_sprites_top    the board top itself: where a sprite lands on
#                         a scan line, seen from the rgb / sync pins.
#
# The diagram TOP stays `sprite`: it is the block this example is
# about, and the board top is three of them plus the VGA controller.
TOP     := sprite
TB_TOPS := tb_trigonometric tb_multiply_by_sin_lut tb_sprite_rotator \
           tb_sprite_raster tb_sprite_gravity tb_vga_sprites_top

SRC_FILES := definitions.vhd trigonometric.vhd sprite_rotator.vhd sprite.vhd \
             ../vga_driver/VgaUtils.vhd \
             ../vga_driver/VgaController.vhd \
             top_level_vga_test.vhd
TB_FILES  := test/tb_trigonometric.vhd \
             test/tb_multiply_by_sin_lut.vhd \
             test/tb_sprite_rotator.vhd \
             test/tb_sprite_raster.vhd \
             test/tb_sprite_gravity.vhd \
             test/tb_vga_sprites_top.vhd

VHDL_STANDARD := 08

# Verilog mirror. sprite.v, sprite_rotator.v, the board top and the six
# TBs pair 1:1 with the VHDL above; trigonometric_functions.vh is
# ``include``d by each file that needs it, so V_INCDIRS covers both the
# synth path and the testbench build.
V_TOP       := sprite
V_TB_TOPS   := tb_trigonometric tb_multiply_by_sin_lut tb_sprite_rotator \
               tb_sprite_raster tb_sprite_gravity tb_vga_sprites_top
V_SRC_FILES := sprite_rotator.v sprite.v \
               ../vga_driver/vga_controller.v \
               top_level_vga_test.v
V_TB_FILES  := test/tb_trigonometric.v \
               test/tb_multiply_by_sin_lut.v \
               test/tb_sprite_rotator.v \
               test/tb_sprite_raster.v \
               test/tb_sprite_gravity.v \
               test/tb_vga_sprites_top.v
V_INCDIRS   := .

# The rotator sweep is ~3900 clocks long; render the first few dozen so
# the two-clock lag between request and result is visible.
ZOOM_RANGE_tb_sprite_rotator   := 0 1200ns
V_ZOOM_RANGE_tb_sprite_rotator := 0 1200ns

# The top-level test runs 4.5 ms to reach its scan line; render just
# that line (vcount 140, 32 us long).
ZOOM_RANGE_tb_vga_sprites_top   := 4480us 4512us
V_ZOOM_RANGE_tb_vga_sprites_top := 4480us 4512us

include ../../mk/common.mk
