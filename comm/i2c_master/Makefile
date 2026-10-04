PROJECT_NAME := i2c_master

TOP     := i2c_master
TB_TOPS := tb_i2c_master

SRC_FILES := i2c_master.vhd
# The slave model is a simulation-only helper, so it lives with the
# testbench and stays out of the synthesised diagram.
TB_FILES  := test/i2c_slave_model.vhd \
             test/tb_i2c_master.vhd

VHDL_STANDARD := 08

V_TOP       := i2c_master
V_TB_TOPS   := tb_i2c_master
V_SRC_FILES := i2c_master.v
V_TB_FILES  := test/i2c_slave_model.v \
               test/tb_i2c_master.v

# Render the first transfer (a four-byte write) so single bits stay
# readable; the whole run is in the FST.
ZOOM_RANGE_tb_i2c_master   := 0 14500ns
V_ZOOM_RANGE_tb_i2c_master := 0 14500ns

include ../../mk/common.mk
