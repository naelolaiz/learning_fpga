PROJECT_NAME := random_generator

TOP     := random_generator
TB_TOPS := tb_random_generator tb_random_generator_long

SRC_FILES := random_generator.vhd neoTRNG.vhd
TB_FILES  := test/tb_random_generator.vhd test/tb_random_generator_long.vhd

# tb_random_generator_long runs for 12 ms; FST keeps the dump small,
# and the per-clock-edge waveform is unreadable at this zoom anyway.
# Assertions still gate CI through GHDL's --assert-level=error.
FST_TBS := tb_random_generator_long

NO_WAVEFORM_TBS   := tb_random_generator_long
V_NO_WAVEFORM_TBS := tb_random_generator_long

VHDL_STANDARD := 08

# Verilog mirror. random_generator.v uses a small Galois LFSR (lfsr.v)
# instead of neoTRNG — see README for the rationale.
V_TOP       := random_generator
V_TB_TOPS   := tb_random_generator tb_random_generator_long
V_SRC_FILES := random_generator.v lfsr.v
V_TB_FILES  := test/tb_random_generator.v test/tb_random_generator_long.v

include ../../mk/common.mk
