PROJECT_NAME := i2s_test_1

# Diagram TOP is the mono oscillator wrapper. The stereo top sits in
# SRC_FILES so it's elaboration-checked, but only the mono path is
# routed through `prep` for synthesis (yosys+ghdl-plugin can only have
# one top per run, and the mono variant exercises the more interesting
# nco_sine + sincos_lut + i2s_master chain).
TOP     := top_level_i2s_oscillator
TB_TOPS := tb_top_level_i2s_oscillator

SRC_FILES := sincos_lut.vhd nco_sine.vhd i2s_master.vhd \
             top_level_i2s_oscillator.vhd top_level_i2s_stereo.vhd
TB_FILES  := test/tb_top_level_i2s_oscillator.vhd

VHDL_STANDARD := 08

# Verilog mirror — same modules, same testbench, $readmemh-loaded LUT.
V_TOP       := top_level_i2s_oscillator
V_TB_TOPS   := tb_top_level_i2s_oscillator
V_SRC_FILES := sincos_lut.v nco_sine.v i2s_master.v \
               top_level_i2s_oscillator.v top_level_i2s_stereo.v
V_TB_FILES  := test/tb_top_level_i2s_oscillator.v

include ../../mk/common.mk
