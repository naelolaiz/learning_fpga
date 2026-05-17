PROJECT_NAME := 7segments_clock

TOP     := top_level_7segments_clock
TB_TOPS := tb_clock_dot_blink

# Each submodule lives in its own canonical home now and gets
# included by relative path. The list reads top-down from the
# primitive blocks up to the project's own top-level.
SRC_FILES := \
    ../../../building_blocks/timer/Timer.vhd \
    ../../../building_blocks/variable_timer/VariableTimer.vhd \
    ../../../building_blocks/counter_timer/CounterTimer.vhd \
    ../../../building_blocks/mod_counter/mod_counter.vhd \
    ../../../building_blocks/mode_blink/mode_blink.vhd \
    ../../../building_blocks/debounce/Debounce.vhd \
    top_level_7segments_clock.vhd

# Each testbench targets exactly one feature so a regression has a name:
#   tb_clock_dot_blink   -- mode_blink frequency-ratio invariant (HHMM vs MMSS)
TB_FILES := \
    test/tb_clock_dot_blink.vhd

VHDL_STANDARD := 08

# Verilog mirror — same composition with the same canonical homes.
V_TOP       := top_level_7segments_clock
V_TB_TOPS   := tb_clock_dot_blink
V_SRC_FILES := \
    ../../../building_blocks/timer/Timer.v \
    ../../../building_blocks/variable_timer/VariableTimer.v \
    ../../../building_blocks/counter_timer/CounterTimer.v \
    ../../../building_blocks/mod_counter/mod_counter.v \
    ../../../building_blocks/mode_blink/mode_blink.v \
    ../../../building_blocks/debounce/Debounce.v \
    top_level_7segments_clock.v
V_TB_FILES  := test/tb_clock_dot_blink.v

include ../../../mk/common.mk
