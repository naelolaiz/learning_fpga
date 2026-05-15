PROJECT_NAME := glossary

# Diagram TOP for the educational netlist (one cell per primitive).
# Quartus uses TOP_LEVEL_ENTITY=top_glossary_board from glossary.qsf
# for the actual board build; the diagram step here is purely about
# rendering the bare primitives into build/glossary.svg.
TOP     := glossary
TB_TOPS := tb_glossary

SRC_FILES := glossary.vhd top_glossary_board.vhd
TB_FILES  := test/tb_glossary.vhd

VHDL_STANDARD := 08

# Verilog mirror — identical structure on the Verilog side.
V_TOP       := glossary
V_TB_TOPS   := tb_glossary
V_SRC_FILES := glossary.v top_glossary_board.v
V_TB_FILES  := test/tb_glossary.v

# Render the glossary netlist with our local skin: a copy of
# netlistsvg's default with text labels (AND, OR, NOT, XOR, NAND,
# NOR, XNOR) added inside each gate's IEEE distinctive shape so a
# reader can map shape <-> name at a glance. The skin lives in this
# directory so make -C glossary resolves the relative path.
#
# Bumped Node V8 stack — the expanded glossary instances every cell
# type at once, so the synthesised mux+wire tree is wider than what
# netlistsvg's recursive `gather` handles on the default stack.
NETLISTSVG := node --stack-size=8000 $$(command -v netlistsvg) --skin skin.svg

# Glossary intentionally infers a level-sensitive D-latch (the
# `o_dlatch` output). ghdl-yosys-plugin defaults to erroring on
# inferred latches; tell it to permit them so the diagram can render.
GHDL_SYNTH_EXTRA := --latches

include ../../mk/common.mk
