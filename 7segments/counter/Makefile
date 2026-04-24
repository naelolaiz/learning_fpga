PROJECT_NAME := 7segments_counter

# NOTE: the top entity is still called `test` because the source file is
# `test.vhd`. The project README flags this as a rename TODO; once
# renamed, update `TOP` and the file names in SRC_FILES below.
TOP     := test
# Two testbenches with deliberately different simulation windows:
#   tb_test        10 ms  — short, shows clock edges + mux rotation
#                           in the gallery PNG (readable per-pixel).
#   tb_test_long  150 ms  — long, shows `numberToDisplay` ticking
#                           (counter rolls every 62.5 ms) — individual
#                           clock edges are sub-pixel at this zoom but
#                           the long-term behaviour becomes visible.
TB_TOPS := tb_test tb_test_long

SRC_FILES := test.vhd
TB_FILES  := test/tb_test.vhd test/tb_test_long.vhd

# A 150 ms sim at GHDL's 1 fs timescale produces a ~650 MB VCD that
# overwhelms the gallery's GTKWave screenshot pipeline. Dumping that
# TB in FST format instead (GTKWave reads FST natively) keeps the
# file small without coarsening any timestamps we care about.
FST_TBS := tb_test_long

# tb_test_long's value is its counter-tick assertion, not its
# waveform: at 150 ms the 20 ns clock period is sub-pixel in any
# PNG, and GTKWave's rendering of the FST under our pipeline is
# unreliable anyway. Skip the PNG; simulate still runs and the
# assertion still guards CI.
NO_PNG_TBS   := tb_test_long
V_NO_PNG_TBS := tb_test_long

VHDL_STANDARD := 08

# Verilog mirror. Same two-TB split, same FST opt-in for the long
# view (post-converted from VCD via vcd2fst since iverilog's
# $dumpfile doesn't natively emit FST).
V_TOP       := test
V_TB_TOPS   := tb_test tb_test_long
V_SRC_FILES := test.v
V_TB_FILES  := test/tb_test.v test/tb_test_long.v
V_FST_TBS   := tb_test_long

include ../../mk/common.mk
