PROJECT_NAME := 7segments_text

# The top entity is `test` (matches test.vhd / test.v) so the existing
# .qsf TOP_LEVEL_ENTITY assignment keeps working unchanged.
TOP     := test
TB_TOPS := tb_text tb_text_long

SRC_FILES := test.vhd
TB_FILES  := test/tb_text.vhd test/tb_text_long.vhd

# tb_text_long runs for 40 ms with the scroll period compressed to
# 5 ms (SCROLL_MAX generic override). The VCD would still be large
# at 1 fs GHDL timescale; FST keeps it small. Skip the waveform
# render for the same reason as counter's long TB — the per-pixel
# clock-edge waveform is meaningless at this zoom, and the
# assertions are what guards CI.
FST_TBS := tb_text_long

NO_WAVEFORM_TBS   := tb_text_long
V_NO_WAVEFORM_TBS := tb_text_long

VHDL_STANDARD := 08

# Verilog mirror.
V_TOP       := test
V_TB_TOPS   := tb_text tb_text_long
V_SRC_FILES := test.v
V_TB_FILES  := test/tb_text.v test/tb_text_long.v

include ../../mk/common.mk
