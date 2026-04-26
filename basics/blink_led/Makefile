PROJECT_NAME := blink_led

TOP     := blink_led
TB_TOPS := tb_blink_led

SRC_FILES := blink_led.vhd
TB_FILES  := test/tb_blink_led.vhd

# Sim used default std (93); synthesis with yosys used --std=08. We
# standardise on 2008 everywhere; if blink_led.vhd needs 93, set
# VHDL_STANDARD := 93 here.
VHDL_STANDARD := 08

# Verilog mirror — built side-by-side with the VHDL flow.
V_TOP       := blink_led
V_TB_TOPS   := tb_blink_led
V_SRC_FILES := blink_led.v
V_TB_FILES  := test/tb_blink_led.v

include ../../mk/common.mk
