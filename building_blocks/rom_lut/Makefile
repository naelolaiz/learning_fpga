PROJECT_NAME := rom_lut

# Diagram TOP is the wrapper around method A (inline literal). Methods
# B and C ship for the multi-method equivalence TB but aren't synthesised
# as the diagram top — file-IO / math_real synthesis support varies by
# tool, so the example keeps the synthesis path on the literal-table form.
TOP     := tl_rom_lut
TB_TOPS := tb_rom_lut tb_rom_lut_methods

SRC_FILES := ROM_LUT.vhd ROM_LUT_hex.vhd ROM_LUT_func.vhd tl_rom_lut.vhd
TB_FILES  := test/tb_rom_lut.vhd test/tb_rom_lut_methods.vhd

VHDL_STANDARD := 08

# Verilog mirror — same three storage methods, same wrapper, same TBs.
V_TOP       := tl_rom_lut
V_TB_TOPS   := tb_rom_lut tb_rom_lut_methods
V_SRC_FILES := rom_lut.v rom_lut_hex.v rom_lut_func.v tl_rom_lut.v
V_TB_FILES  := test/tb_rom_lut.v test/tb_rom_lut_methods.v

include ../../mk/common.mk
