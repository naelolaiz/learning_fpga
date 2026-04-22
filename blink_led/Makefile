PROJECT_NAME := blink_led

TOP     := blink_led
TB_TOP  := tb_blink_led

SRC_FILES := blink_led.vhd
TB_FILES  := test/tb_blink_led.vhd

# Sim used default std (93); synthesis with yosys used --std=08. We
# standardise on 2008 everywhere; if blink_led.vhd needs 93, set
# VHDL_STANDARD := 93 here.
VHDL_STANDARD := 08

include ../mk/common.mk
