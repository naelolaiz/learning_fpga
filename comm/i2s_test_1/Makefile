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

# Strip yosys's auto-stamped paramod / arch-suffix labels off the
# rendered submodule cells in the netlist diagrams. Without this:
#   * VHDL: nco_sine appears as `nco_sine_Brtl` and i2s_master as
#     `i2s_master_Brtl_50000000_24576000_24` (ghdl-yosys-plugin tags
#     `_B<arch>_<generics>`).
#   * Verilog: i2s_master shows up as `$paramod$<sha>\i2s_master`
#     (yosys's parametrised-module mangling).
SVG_RELABEL   := waveform_generator=nco_sine i2s_transmiter=i2s_master
V_SVG_RELABEL := nco=nco_sine i2s=i2s_master

include ../../mk/common.mk
