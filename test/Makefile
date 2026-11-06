
SIM ?= icarus
FST ?= -fst
TOPLEVEL_LANG ?= verilog

SRC_DIR = $(PWD)/../src
PROJECT_SOURCES = project.v tiny8_top.v gf180mcu_ocd_ip_sram__sram256x8m8wm1__blackbox.v

COMPILE_ARGS += -I$(SRC_DIR)

ifeq ($(GATES),yes)

# Gate-level simulation
SIM_BUILD = sim_build/gl

COMPILE_ARGS += -DGL_TEST
COMPILE_ARGS += -DFUNCTIONAL
COMPILE_ARGS += -DUSE_POWER_PINS
COMPILE_ARGS += -DSIM
COMPILE_ARGS += -DUNIT_DELAY=\#1

VERILOG_SOURCES += $(PDK_ROOT)/gf180mcuD/libs.ref/gf180mcu_fd_sc_mcu7t5v0/verilog/primitives.v
VERILOG_SOURCES += $(PDK_ROOT)/gf180mcuD/libs.ref/gf180mcu_fd_sc_mcu7t5v0/verilog/gf180mcu_fd_sc_mcu7t5v0.v
VERILOG_SOURCES += $(PWD)/gate_level_netlist.v

TOPLEVEL = tt_um_godofstrategy_tiny8
COCOTB_TEST_MODULES = test_gl

else

# RTL simulation
SIM_BUILD = sim_build/rtl

VERILOG_SOURCES += $(addprefix $(SRC_DIR)/,$(PROJECT_SOURCES))
VERILOG_SOURCES += $(PWD)/gf180_sram_sim.v
VERILOG_SOURCES += $(PWD)/tb.v

COMPILE_ARGS += -DSIMULATION

TOPLEVEL = tb
COCOTB_TEST_MODULES = test

endif

include $(shell cocotb-config --makefiles)/Makefile.sim
