PROJECT_NAME := 7segments_text

TOP     := text
TB_TOPS := tb_text tb_text_long

SRC_FILES := text.vhd
TB_FILES  := test/tb_text.vhd test/tb_text_long.vhd

# tb_text_long runs for 40 ms with the scroll period compressed to
# 5 ms (SCROLL_MAX generic override). Skip the waveform render for
# the same reason as counter's long TB — the per-pixel clock-edge
# waveform is meaningless at this zoom, and the assertions are what
# guards CI.
NO_WAVEFORM_TBS   := tb_text_long
V_NO_WAVEFORM_TBS := tb_text_long

VHDL_STANDARD := 08

# Verilog mirror.
V_TOP       := text
V_TB_TOPS   := tb_text tb_text_long
V_SRC_FILES := text.v
V_TB_FILES  := test/tb_text.v test/tb_text_long.v

include ../../../mk/common.mk
