PROJECT_NAME := timer

TOP     := Timer
TB_TOPS := tb_timer

SRC_FILES := Timer.vhd
TB_FILES  := test/tb_timer.vhd

VHDL_STANDARD := 08

V_TOP       := Timer
V_TB_TOPS   := tb_timer
V_SRC_FILES := Timer.v
V_TB_FILES  := test/tb_timer.v

include ../../mk/common.mk

# The shared test target includes this cross-language contract check.
.PHONY: equivalence
verify: equivalence
equivalence:
	python3 ../../tools/check_timer_equivalence.py
