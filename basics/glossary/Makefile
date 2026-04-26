PROJECT_NAME := glossary

TOP     := glossary
TB_TOPS := tb_glossary

SRC_FILES := glossary.vhd
TB_FILES  := test/tb_glossary.vhd

VHDL_STANDARD := 08

# Verilog mirror — built side-by-side with the VHDL flow.
V_TOP       := glossary
V_TB_TOPS   := tb_glossary
V_SRC_FILES := glossary.v
V_TB_FILES  := test/tb_glossary.v

# Render the netlist with our local skin: a copy of netlistsvg's default
# with text labels (AND, OR, NOT, XOR, NAND, NOR, XNOR) added inside
# each gate's IEEE distinctive shape so a reader can map shape ↔ name
# at a glance. The skin lives in this directory so make -C glossary
# resolves the relative path.
NETLISTSVG := netlistsvg --skin skin.svg

include ../../mk/common.mk
