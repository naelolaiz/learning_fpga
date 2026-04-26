PROJECT_NAME := blink_led

# Diagram TOP for `make diagram` is the precise-period (2-FF) variant.
# The minimal (1-FF) variant is rendered alongside via the extra
# rules at the bottom of this file -- both diagrams end up under
# build/ and the README references both.
TOP     := blink_led
TB_TOPS := tb_blink_led tb_blink_led_minimal

SRC_FILES := blink_led.vhd blink_led_minimal.vhd
TB_FILES  := test/tb_blink_led.vhd test/tb_blink_led_minimal.vhd

VHDL_STANDARD := 08

# Verilog mirror — built side-by-side with the VHDL flow.
V_TOP       := blink_led
V_TB_TOPS   := tb_blink_led tb_blink_led_minimal
V_SRC_FILES := blink_led.v blink_led_minimal.v
V_TB_FILES  := test/tb_blink_led.v test/tb_blink_led_minimal.v

include ../../mk/common.mk

# ---- Extra diagram: blink_led_minimal --------------------------------
# Render the minimal (1-FF) variant alongside the precise-period one
# so the README can show the cell-count contrast directly. Same
# pattern as basics/glossary's logic_styles diagram extension.
diagram: $(BUILD_DIR)/blink_led_minimal.svg

$(BUILD_DIR)/blink_led_minimal.json: $(SRC_FILES) | $(BUILD_DIR)
	$(YOSYS) -m ghdl -p \
	    "ghdl $(GHDL_SYNTH_STD) -fsynopsys $(GHDL_SYNTH_EXTRA) $(SRC_FILES) -e blink_led_minimal; \
	     prep -top blink_led_minimal; \
	     write_json -compat-int $@"

$(BUILD_DIR)/blink_led_minimal.svg: $(BUILD_DIR)/blink_led_minimal.json
	$(NETLISTSVG) $< -o $@

# Verilog blink_led_minimal diagram (mirrors the VHDL one).
diagram_v: $(BUILD_DIR)/blink_led_minimal_v.svg

$(BUILD_DIR)/blink_led_minimal_v.json: $(V_SRC_FILES) | $(BUILD_DIR)
	$(YOSYS) -p \
	    "read_verilog -sv $(V_SRC_FILES); \
	     prep -top blink_led_minimal; \
	     write_json -compat-int $@"

$(BUILD_DIR)/blink_led_minimal_v.svg: $(BUILD_DIR)/blink_led_minimal_v.json
	$(NETLISTSVG) $< -o $@
