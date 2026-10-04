PROJECT_NAME := uda1380

# Diagram TOP is the inout-free core. top_level_uda1380 wraps the same
# core and adds the two open-drain I2C pins for the board; netlistsvg
# cannot render inout ports, so the core is what gets drawn and what
# the testbenches drive.
TOP     := top_level_uda1380_core
TB_TOPS := tb_uda1380_init_fsm tb_top_level_uda1380

# Order: package first, then the shared I2C master, the local blocks,
# the FSM, the core, and finally the board wrapper.
SRC_FILES := uda1380_control_definitions.vhd \
             ../i2c_master/i2c_master.vhd \
             i2s_master.vhd \
             tone_gen.vhd \
             uda1380_init_fsm.vhd \
             top_level_uda1380_core.vhd \
             top_level_uda1380.vhd
# The integration testbench puts i2c_master's behavioural slave on the
# bus in place of the codec.
TB_FILES  := ../i2c_master/test/i2c_slave_model.vhd \
             test/tb_uda1380_init_fsm.vhd \
             test/tb_top_level_uda1380.vhd

VHDL_STANDARD := 08

# Verilog mirror.
V_TOP       := top_level_uda1380_core
V_TB_TOPS   := tb_uda1380_init_fsm tb_top_level_uda1380
V_SRC_FILES := ../i2c_master/i2c_master.v \
               i2s_master.v \
               tone_gen.v \
               uda1380_init_fsm.v \
               top_level_uda1380_core.v \
               top_level_uda1380.v
V_TB_FILES  := ../i2c_master/test/i2c_slave_model.v \
               test/tb_uda1380_init_fsm.v \
               test/tb_top_level_uda1380.v

include ../../mk/common.mk
