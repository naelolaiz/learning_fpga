PROJECT_NAME := serial_to_parallel

TOP     := Serial2Parallel
TB_TOPS := tb_serial_to_parallel_basic tb_serial_to_parallel_print_gating

# Cross-project source: this project wraps the shift_register entity
# from building_blocks/shift_register/ rather than reimplementing the
# shift loop. GHDL/iverilog/yosys all accept relative paths in their
# source list, so the include is a path, not a build-system import.
# shift_register comes first so GHDL analyses it before Serial2Parallel
# reaches `entity work.shift_register`.
SRC_FILES := ../shift_register/shift_register.vhd Serial2Parallel.vhd
TB_FILES  := test/tb_serial_to_parallel_basic.vhd \
             test/tb_serial_to_parallel_print_gating.vhd

VHDL_STANDARD := 08

V_TOP       := Serial2Parallel
V_TB_TOPS   := tb_serial_to_parallel_basic tb_serial_to_parallel_print_gating
V_SRC_FILES := ../shift_register/shift_register.v Serial2Parallel.v
V_TB_FILES  := test/tb_serial_to_parallel_basic.v \
               test/tb_serial_to_parallel_print_gating.v

include ../../mk/common.mk
