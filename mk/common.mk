# ---------------------------------------------------------------------------
# mk/common.mk - Shared build rules for every VHDL project in learning_fpga.
#
# Each project's Makefile is expected to define:
#
#   PROJECT_NAME   Identifier used for artifact names and logs.
#   TOP            Top-level entity (used for diagram synthesis).
#   TB_TOP         Top-level entity of the testbench (simulation).
#   SRC_FILES      VHDL sources of the design, relative to the Makefile.
#   TB_FILES       VHDL sources of the testbench, relative to the Makefile.
#
# Optional overrides:
#
#   VHDL_STANDARD  VHDL standard for both simulate and synth. Default: 08.
#   SIM_STD        Override standard for simulation only. Default: $(VHDL_STANDARD).
#   SYNTH_STD      Override standard for synthesis only.  Default: $(VHDL_STANDARD).
#   ASSERT_LEVEL   GHDL --assert-level. Default: error.
#   SIM_TIME       GHDL --stop-time. Default: empty (runs until testbench returns).
#   EXTRA_GHDL     Extra flags passed to every ghdl invocation.
#
# Artifact locations (all under build/ for trivial `make clean`):
#
#   build/work/                 GHDL work library
#   build/<TB_TOP>.vcd          Simulation waveform dump
#   build/<TB_TOP>.png          Rendered waveform screenshot (GTKWave + Xvfb)
#   build/<TOP>.json            Synthesised netlist (yosys + ghdl plugin)
#   build/<TOP>.svg             Rendered netlist diagram (netlistsvg)
# ---------------------------------------------------------------------------

# ---- Tool discovery (overridable from the environment) --------------------
GHDL          ?= ghdl
YOSYS         ?= yosys
NETLISTSVG    ?= netlistsvg
PYTHON        ?= python3

# ---- Defaults --------------------------------------------------------------
VHDL_STANDARD ?= 08
SIM_STD       ?= $(VHDL_STANDARD)
SYNTH_STD     ?= $(VHDL_STANDARD)
ASSERT_LEVEL  ?= error
SIM_TIME      ?=
EXTRA_GHDL    ?=

# ---- Layout ----------------------------------------------------------------
BUILD_DIR     := build
WORK_DIR      := $(BUILD_DIR)/work
VCD_FILE      := $(BUILD_DIR)/$(TB_TOP).vcd
WAVEFORM_PNG  := $(BUILD_DIR)/$(TB_TOP).png
NETLIST_JSON  := $(BUILD_DIR)/$(TOP).json
DIAGRAM_SVG   := $(BUILD_DIR)/$(TOP).svg

# ---- Derived paths ---------------------------------------------------------
# Resolve the repo root via this file's own location so the Makefile can
# be invoked from anywhere (including inside the hdltools Docker image,
# where the repo is typically mounted at an arbitrary path).
REPO_ROOT   := $(abspath $(dir $(lastword $(MAKEFILE_LIST)))/..)
SCRIPTS_DIR := $(REPO_ROOT)/scripts
VCD2PNG     := $(SCRIPTS_DIR)/vcd2png.py

# ---- GHDL flags ------------------------------------------------------------
GHDL_COMMON     := --workdir=$(WORK_DIR) -fsynopsys $(EXTRA_GHDL)
GHDL_SIM_FLAGS  := --std=$(SIM_STD)   $(GHDL_COMMON)
GHDL_SYNTH_STD  := --std=$(SYNTH_STD)

# Optional --stop-time only emitted when SIM_TIME is set.
SIM_RUN_OPTS := --assert-level=$(ASSERT_LEVEL) --vcd=$(VCD_FILE)
ifneq ($(strip $(SIM_TIME)),)
    SIM_RUN_OPTS += --stop-time=$(SIM_TIME)
endif

# ---- Phony targets ---------------------------------------------------------
.PHONY: all analyze elaborate simulate diagram screenshot clean help

all: simulate diagram screenshot

help:
	@echo "Project: $(PROJECT_NAME)"
	@echo "  TOP=$(TOP)  TB_TOP=$(TB_TOP)  VHDL_STANDARD=$(VHDL_STANDARD)"
	@echo ""
	@echo "Targets:"
	@echo "  analyze     Parse and type-check the VHDL sources."
	@echo "  elaborate   Elaborate the testbench ($(TB_TOP))."
	@echo "  simulate    Run simulation and emit $(VCD_FILE)."
	@echo "  diagram     Synthesise $(TOP) via yosys+ghdl, render SVG."
	@echo "  screenshot  Render a GTKWave PNG of the simulation waveform."
	@echo "  clean       Remove the build/ directory."

$(BUILD_DIR) $(WORK_DIR):
	@mkdir -p $@

# ---- Analyze ---------------------------------------------------------------
analyze: | $(WORK_DIR)
	$(GHDL) -a $(GHDL_SIM_FLAGS) $(SRC_FILES) $(TB_FILES)

# ---- Elaborate -------------------------------------------------------------
elaborate: analyze
	$(GHDL) -e $(GHDL_SIM_FLAGS) $(TB_TOP)

# ---- Simulate --------------------------------------------------------------
simulate: $(VCD_FILE)

$(VCD_FILE): elaborate | $(BUILD_DIR)
	$(GHDL) -r $(GHDL_SIM_FLAGS) $(TB_TOP) $(SIM_RUN_OPTS)

# ---- Waveform screenshot ---------------------------------------------------
# Drives a headless GTKWave via the Python helper. The helper is part of
# this repo so no container assumption is baked in.
screenshot: $(WAVEFORM_PNG)

$(WAVEFORM_PNG): $(VCD_FILE)
	$(PYTHON) $(VCD2PNG) --input $< --output $@

# ---- Netlist diagram -------------------------------------------------------
# yosys+ghdl-yosys-plugin synthesises TOP into a generic netlist; netlistsvg
# renders it. Synthesis has its own std flag because a few of the projects
# rely on VHDL-93 for sim but synthesise cleanly only under 2008 (or vice
# versa); SYNTH_STD lets each project say what it needs.
diagram: $(DIAGRAM_SVG)

$(NETLIST_JSON): $(SRC_FILES) | $(BUILD_DIR)
	$(YOSYS) -m ghdl -p \
	    "ghdl $(GHDL_SYNTH_STD) -fsynopsys $(SRC_FILES) -e $(TOP); \
	     prep -top $(TOP); \
	     write_json -compat-int $@"

$(DIAGRAM_SVG): $(NETLIST_JSON)
	$(NETLISTSVG) $< -o $@

# ---- Housekeeping ----------------------------------------------------------
clean:
	@rm -rf $(BUILD_DIR)
	@rm -f *.cf *.o $(TB_TOP) $(TOP) work-obj*.cf
