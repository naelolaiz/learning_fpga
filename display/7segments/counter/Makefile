PROJECT_NAME := 7segments_counter

TOP     := counter
# Two testbenches with deliberately different simulation windows:
#   tb_counter        10 ms  — short, shows clock edges + mux rotation
#                              in the gallery PNG (readable per-pixel).
#   tb_counter_long  150 ms  — long, shows `numberToDisplay` ticking
#                              (counter rolls every 62.5 ms) — individual
#                              clock edges are sub-pixel at this zoom but
#                              the long-term behaviour becomes visible.
TB_TOPS := tb_counter tb_counter_long

SRC_FILES := counter.vhd
TB_FILES  := test/tb_counter.vhd test/tb_counter_long.vhd

# tb_counter_long's value is its counter-tick assertion, not its
# waveform: at 150 ms the 20 ns clock period is sub-pixel in any
# raster render. Skip the waveform render; simulate still runs and
# the assertion still guards CI.
NO_WAVEFORM_TBS   := tb_counter_long
V_NO_WAVEFORM_TBS := tb_counter_long

VHDL_STANDARD := 08

# Verilog mirror. Same two-TB split.
V_TOP       := counter
V_TB_TOPS   := tb_counter tb_counter_long
V_SRC_FILES := counter.v
V_TB_FILES  := test/tb_counter.v test/tb_counter_long.v

include ../../../mk/common.mk
