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

# Diagram annotations: relabel the submodule instances back to clean
# entity names (yosys's ghdl plugin downcases identifiers, so the
# cell IDs in the rendered SVG are all-lowercase) and link each one
# to its standalone diagram in the gallery so the reader can drill
# from the top-level into the wrapped block.
SVG_RELABEL := \
    timer1sec=Timer \
    timer00015sec=Timer \
    square400hz=Timer \
    variabletimerfortimeset=VariableTimer \
    counterformux=CounterTimer \
    dotblinker=mode_blink \
    debounce_clock_mode_switch=Debounce \
    debounce_view_alarm=Debounce \
    debounce_increase_time_button=Debounce \
    debounce_decrease_time_button=Debounce

# Verilog cell IDs preserve case — no downcasing in the iverilog flow.
V_SVG_RELABEL := \
    timer1Sec=Timer \
    timer00015Sec=Timer \
    square400Hz=Timer \
    variableTimerForTimeSet=VariableTimer \
    counterForMux=CounterTimer \
    dotBlinker=mode_blink \
    debounce_clock_mode_switch=Debounce \
    debounce_view_alarm=Debounce \
    debounce_increase_time_button=Debounce \
    debounce_decrease_time_button=Debounce

SVG_LINKS := \
    timer1sec=../building_blocks-timer/Timer.svg \
    timer00015sec=../building_blocks-timer/Timer.svg \
    square400hz=../building_blocks-timer/Timer.svg \
    variabletimerfortimeset=../building_blocks-variable_timer/VariableTimer.svg \
    counterformux=../building_blocks-counter_timer/CounterTimer.svg \
    dotblinker=../building_blocks-mode_blink/mode_blink.svg \
    debounce_clock_mode_switch=../building_blocks-debounce/Debounce.svg \
    debounce_view_alarm=../building_blocks-debounce/Debounce.svg \
    debounce_increase_time_button=../building_blocks-debounce/Debounce.svg \
    debounce_decrease_time_button=../building_blocks-debounce/Debounce.svg

V_SVG_LINKS := \
    timer1Sec=../building_blocks-timer/Timer_v.svg \
    timer00015Sec=../building_blocks-timer/Timer_v.svg \
    square400Hz=../building_blocks-timer/Timer_v.svg \
    variableTimerForTimeSet=../building_blocks-variable_timer/VariableTimer_v.svg \
    counterForMux=../building_blocks-counter_timer/CounterTimer_v.svg \
    dotBlinker=../building_blocks-mode_blink/mode_blink_v.svg \
    debounce_clock_mode_switch=../building_blocks-debounce/Debounce_v.svg \
    debounce_view_alarm=../building_blocks-debounce/Debounce_v.svg \
    debounce_increase_time_button=../building_blocks-debounce/Debounce_v.svg \
    debounce_decrease_time_button=../building_blocks-debounce/Debounce_v.svg

include ../../../mk/common.mk
