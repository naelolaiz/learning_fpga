PROJECT_NAME := general_components

# Current testbench. As more components land, add them as separate
# projects (one Makefile each) rather than stuffing them in here.
TOP     := Serial2Parallel
TB_TOP  := Serial2Parallel_tb

SRC_FILES := Serial2Parallel.vhd
TB_FILES  := Serial2Parallel_tb.vhd

VHDL_STANDARD := 08

# Verilog mirror — Serial2Parallel + Debounce side-by-side. Debounce
# isn't testbench-driven on the VHDL side either; it ships with
# Serial2Parallel just so both translations live next to their VHDL
# counterparts and can be inspected in tandem.
V_TOP       := Serial2Parallel
V_TB_TOP    := Serial2Parallel_tb
V_SRC_FILES := Serial2Parallel.v Debounce.v
V_TB_FILES  := Serial2Parallel_tb.v

include ../mk/common.mk
