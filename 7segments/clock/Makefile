PROJECT_NAME := 7segments_clock

TOP     := top_level_7segments_clock
TB_TOPS := tb_clock_dot_blink tb_clock_alarm

SRC_FILES := \
    Timer.vhd \
    VariableTimer.vhd \
    CounterTimer.vhd \
    Debounce.vhd \
    7segmentsDigit.vhd \
    DotBlinker.vhd \
    AlarmTrigger.vhd \
    top_level_7segments_clock.vhd

# Each testbench targets exactly one feature so a regression has a name:
#   tb_clock_dot_blink   -- DotBlinker frequency-ratio invariant
#   tb_clock_alarm       -- AlarmTrigger match window + intermittence
TB_FILES := \
    test/tb_clock_dot_blink.vhd \
    test/tb_clock_alarm.vhd

VHDL_STANDARD := 08

# Full Verilog mirror — top-level + every leaf entity. Closes the
# "Verilog mirrors for the bigger SoC-style projects: ... 7segments/clock"
# roadmap item. V_TOP matches TOP so the gallery's per-stem table
# (`top_level_7segments_clock | VHDL svg | Verilog svg`) lines up cleanly.
V_TOP       := top_level_7segments_clock
V_TB_TOPS   := tb_clock_dot_blink tb_clock_alarm
V_SRC_FILES := \
    Timer.v \
    VariableTimer.v \
    CounterTimer.v \
    Debounce.v \
    7segmentsDigit.v \
    DotBlinker.v \
    AlarmTrigger.v \
    top_level_7segments_clock.v
V_TB_FILES  := test/tb_clock_dot_blink.v test/tb_clock_alarm.v

include ../../mk/common.mk
