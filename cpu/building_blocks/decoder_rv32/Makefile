PROJECT_NAME := decoder_rv32

TOP     := decoder_rv32
TB_TOPS := tb_decoder_rv32

SRC_FILES := decoder_rv32.vhd
TB_FILES  := test/tb_decoder_rv32.vhd

VHDL_STANDARD := 08

V_TOP       := decoder_rv32
V_TB_TOPS   := tb_decoder_rv32
V_SRC_FILES := decoder_rv32.v
V_TB_FILES  := test/tb_decoder_rv32.v

# Same Node-stack bump as immgen_rv32: the synthesised decoder is a
# big shallow combinational tree that trips netlistsvg's recursive
# `gather` on the default ~1 MB JS stack. ~8 MB is plenty.
NETLISTSVG := node --stack-size=8000 $$(command -v netlistsvg)

include ../../../mk/common.mk
