PROJECT_NAME := vga

# TOP for the netlist diagram is the bare VGA timing controller — the
# clearest single artefact this example introduces. The full board top
# (top_level_vga_test.vhd) is left out of SRC_FILES on purpose: it
# pulls in string-typed generics that yosys+ghdl-plugin doesn't handle,
# the same way vga_sprites synths `sprite` rather than its own
# top_level_vga_test.
TOP     := VgaController
TB_TOPS := tb_vga_smoke

SRC_FILES := ../vga_driver/VgaUtils.vhd \
             ../vga_driver/VgaController.vhd \
             text_generator/commonPak.vhd \
             text_generator/Font_Rom.vhd \
             text_generator/Pixel_On_Text.vhd \
             text_generator/Pixel_On_Text2.vhd \
             text_generator/Pixel_On_Text_WithSize.vhd
TB_FILES  := test/tb_vga_smoke.vhd

VHDL_STANDARD := 08

include ../../mk/common.mk
