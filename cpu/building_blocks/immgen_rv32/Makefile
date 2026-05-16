PROJECT_NAME := immgen_rv32

TOP     := immgen_rv32
TB_TOPS := tb_immgen_rv32

SRC_FILES := immgen_rv32.vhd
TB_FILES  := test/tb_immgen_rv32.vhd

VHDL_STANDARD := 08

V_TOP       := immgen_rv32
V_TB_TOPS   := tb_immgen_rv32
V_SRC_FILES := immgen_rv32.v
V_TB_FILES  := test/tb_immgen_rv32.v

# Bump Node's V8 stack so netlistsvg can render the 32-bit × 5-way
# concatenated-mux tree this immediate generator synthesises to.
# Default Node stack (~1 MB) blows up with
# `RangeError: Maximum call stack size exceeded` deep inside
# netlistsvg's recursive `gather`; ~8 MB is plenty. The hdltools
# container ships netlistsvg as a node-shebang script at
# /usr/local/bin/netlistsvg — `command -v` resolves it at recipe
# time, evaluated by sh (the `$$` defers expansion past Make).
NETLISTSVG := node --stack-size=8000 $$(command -v netlistsvg)

include ../../../mk/common.mk
