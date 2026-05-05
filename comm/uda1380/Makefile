PROJECT_NAME := uda1380

# Diagram TOP is the inout-free core wrapper. The simulation
# testbenches go through top_level_uda1380 (inout) which wraps the
# same core and resolves the bidirectional pin against the external
# pull-up — see the README for the rationale.
TOP     := top_level_uda1380_core
TB_TOPS := tb_uda1380_init_fsm tb_top_level_uda1380

# Order: package first, then i2c masters (both flavours), shared
# blocks, FSM, the inout-free core, then the sim wrapper.
SRC_FILES := uda1380_control_definitions.vhd \
             i2c_master.vhd \
             i2c_master_for_diagram.vhd \
             i2s_master.vhd \
             tone_gen.vhd \
             uda1380_init_fsm.vhd \
             top_level_uda1380_core.vhd \
             top_level_uda1380.vhd
TB_FILES  := test/tb_uda1380_init_fsm.vhd \
             test/tb_top_level_uda1380.vhd

VHDL_STANDARD := 08

# Verilog mirror.
V_TOP       := top_level_uda1380_core
V_TB_TOPS   := tb_uda1380_init_fsm tb_top_level_uda1380
V_SRC_FILES := i2c_master.v \
               i2c_master_for_diagram.v \
               i2s_master.v \
               tone_gen.v \
               uda1380_init_fsm.v \
               top_level_uda1380_core.v \
               top_level_uda1380.v
V_TB_FILES  := test/tb_uda1380_init_fsm.v \
               test/tb_top_level_uda1380.v

include ../../mk/common.mk
