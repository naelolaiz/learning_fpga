PROJECT_NAME := logic_styles

# Diagram TOP: render the logic_styles entity itself so the netlist
# shows the contrast between the combinational good case, the latch
# trap, the three register init styles and the intentional latch.
# Quartus uses TOP_LEVEL_ENTITY=top_logic_styles_board from the qsf
# for the actual board build.
TOP     := logic_styles
TB_TOPS := tb_logic_styles

SRC_FILES := logic_styles.vhd top_logic_styles_board.vhd
TB_FILES  := test/tb_logic_styles.vhd

VHDL_STANDARD := 08

# This project intentionally infers latches (the trap demo plus the
# explicit transparent latch). ghdl-yosys-plugin defaults to erroring
# on latches; tell it to permit them so the diagram can render.
GHDL_SYNTH_EXTRA := --latches

V_TOP       := logic_styles
V_TB_TOPS   := tb_logic_styles
V_SRC_FILES := logic_styles.v top_logic_styles_board.v
V_TB_FILES  := test/tb_logic_styles.v

include ../../mk/common.mk
