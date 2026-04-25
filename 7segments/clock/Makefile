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

# Verilog mirrors of the two new leaf entities + their TBs. Per the
# project roadmap ("leaf modules first, top-levels after") the full
# top_level_7segments_clock is not mirrored here yet — only the bits
# this PR adds.
V_TOP       := DotBlinker
V_TB_TOPS   := tb_clock_dot_blink tb_clock_alarm
V_SRC_FILES := DotBlinker.v AlarmTrigger.v
V_TB_FILES  := test/tb_clock_dot_blink.v test/tb_clock_alarm.v

include ../../mk/common.mk
