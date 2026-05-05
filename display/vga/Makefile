PROJECT_NAME := vga

# TOP for the netlist diagram is the bare VGA timing controller — the
# clearest single artefact this example introduces. top_level_vga_test
# is in SRC_FILES so GHDL syntax-checks it on every CI run, but it is
# NOT used as the diagram TOP: it pulls in string-typed generics that
# yosys+ghdl-plugin doesn't handle, same reason vga_sprites synths
# `sprite` rather than its own top_level_vga_test.
TOP     := VgaController
TB_TOPS := tb_vga_smoke tb_vga_top

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
TB_FILES  := test/tb_vga_smoke.vhd test/tb_vga_top.vhd

VHDL_STANDARD := 08

# Verilog mirror. The diagram TOP is `VgaController` (PascalCase to
# match the VHDL entity, so the gallery's stem-based pairing puts both
# netlist diagrams on the same row). vga_controller.v is a 1:1 port of
# VgaController.vhd; control_panel.v mirrors the new building block;
# font_rom.v stays here because tb_vga_smoke.v instantiates it. The
# smoke TB exercises the same two contracts as its VHDL twin: the
# strict-less-than box test (inlined as an `assign`, since Verilog has
# no concurrent equivalent of VHDL's Square procedure) and the
# Font_Rom NUL + 'A' row 7 reads.
V_TOP       := VgaController
V_TB_TOPS   := tb_vga_smoke tb_vga_top
V_SRC_FILES := ../vga_driver/vga_controller.v \
               ../../building_blocks/debounce/Debounce.v \
               control_panel.v \
               text_generator/font_rom.v
V_TB_FILES  := test/tb_vga_smoke.v test/tb_vga_top.v

include ../../mk/common.mk
