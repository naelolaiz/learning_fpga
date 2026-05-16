PROJECT_NAME := rom_lut

# Diagram TOP is the wrapper around method A (inline literal). Methods
# B and C ship for the multi-method equivalence TB but aren't synthesised
# as the diagram top — file-IO / math_real synthesis support varies by
# tool, so the example keeps the synthesis path on the literal-table form.
TOP     := tl_rom_lut
TB_TOPS := tb_rom_lut tb_rom_lut_methods tb_rom_lut_realmath

SRC_FILES := ROM_LUT.vhd ROM_LUT_hex.vhd ROM_LUT_func.vhd tl_rom_lut.vhd
TB_FILES  := test/tb_rom_lut.vhd test/tb_rom_lut_methods.vhd test/tb_rom_lut_realmath.vhd

VHDL_STANDARD := 08

# Verilog mirror — same three storage methods, same wrapper, same TBs.
V_TOP       := tl_rom_lut
V_TB_TOPS   := tb_rom_lut tb_rom_lut_methods tb_rom_lut_realmath
V_SRC_FILES := rom_lut.v rom_lut_hex.v rom_lut_func.v tl_rom_lut.v
V_TB_FILES  := test/tb_rom_lut.v test/tb_rom_lut_methods.v test/tb_rom_lut_realmath.v

# Rewrite the auto-generated submodule labels in the rendered netlists
# back to the bare entity / module names. Without this:
#   * VHDL cell shows `single_clock_rom_Brtl_32_9` (ghdl-yosys-plugin
#     stamps `_B<arch>_<generics>` onto the type name).
#   * Verilog cell shows `$paramod$<sha>\rom_lut` (yosys's parametrised-
#     module mangling).
# Both are unreadable in the rendered SVG. Cell IDs come from the
# instance names in tl_rom_lut: `ROM_INSTANCE` (lowercased by GHDL to
# `rom_instance`) on the VHDL side, `rom_inst` on the Verilog side.
SVG_RELABEL   := rom_instance=single_clock_rom
V_SVG_RELABEL := rom_inst=rom_lut

include ../../mk/common.mk
