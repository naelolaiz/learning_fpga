PROJECT_NAME := vga

# TOP for the netlist diagram is the bare VGA timing controller — the
# clearest single artefact this example introduces. top_level_vga_test
# is in SRC_FILES so GHDL syntax-checks it on every CI run, but it is
# NOT used as the diagram TOP: it pulls in string-typed generics that
# yosys+ghdl-plugin doesn't handle, same reason vga_sprites synths
# `sprite` rather than its own top_level_vga_test.
TOP     := VgaController
TB_TOPS := tb_vga_smoke

SRC_FILES := ../vga_driver/VgaUtils.vhd \
             ../vga_driver/VgaController.vhd \
             ../../building_blocks/debounce/Debounce.vhd \
             control_panel.vhd \
             text_generator/commonPak.vhd \
             text_generator/Font_Rom.vhd \
             text_generator/Pixel_On_Text.vhd \
             text_generator/Pixel_On_Text2.vhd \
             text_generator/Pixel_On_Text_WithSize.vhd \
             top_level_vga_test.vhd
TB_FILES  := test/tb_vga_smoke.vhd

VHDL_STANDARD := 08

include ../../mk/common.mk
