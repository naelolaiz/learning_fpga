# ---------------------------------------------------------------------------
# mk/common.mk - Shared build rules for every project in learning_fpga.
#
# Each project's Makefile is expected to define:
#
#   PROJECT_NAME   Identifier used for artifact names and logs.
#   TOP            Top-level entity (used for diagram synthesis).
#   TB_TOP         Top-level entity of the testbench (simulation).
#   SRC_FILES      VHDL sources of the design, relative to the Makefile.
#   TB_FILES       VHDL sources of the testbench, relative to the Makefile.
#
# Optional VHDL overrides:
#
#   VHDL_STANDARD  VHDL standard for both simulate and synth. Default: 08.
#   SIM_STD        Override standard for simulation only. Default: $(VHDL_STANDARD).
#   SYNTH_STD      Override standard for synthesis only.  Default: $(VHDL_STANDARD).
#   ASSERT_LEVEL   GHDL --assert-level. Default: error.
#   SIM_TIME       GHDL --stop-time. Default: empty (runs until testbench returns).
#   EXTRA_GHDL     Extra flags passed to every ghdl invocation.
#   SKIP_DIAGRAM   If non-empty, `make diagram` is a no-op. Use when TOP is a
#                  package or otherwise can't be synthesised by yosys+ghdl.
#   SKIP_SCREENSHOT If non-empty, `make screenshot` is a no-op.
#
# Optional Verilog side-by-side build (set any of these to enable):
#
#   V_TOP          Verilog top-level module name (for diagram synthesis).
#   V_TB_TOP       Verilog testbench top module name (for simulation).
#   V_SRC_FILES    Verilog sources of the design.
#   V_TB_FILES     Verilog sources of the testbench.
#   V_DEFINES      Extra `-D` macros for iverilog/yosys (e.g. WIDTH=8).
#   V_INCDIRS      Extra `-I` include directories.
#   SKIP_V_DIAGRAM If non-empty, the Verilog `diagram` step is a no-op.
#   SKIP_V_SCREENSHOT If non-empty, the Verilog `screenshot` step is a no-op.
#
# When V_SRC_FILES is non-empty, `make all` (and `simulate` / `diagram` /
# `screenshot`) build BOTH the VHDL and Verilog flows. Artifacts are
# disambiguated with a `_v` suffix so they share build/ without colliding.
#
# Artifact locations (all under build/ for trivial `make clean`):
#
#   build/work/                  GHDL work library
#   build/<TB_TOP>.vcd           VHDL simulation waveform dump
#   build/<TB_TOP>.png           VHDL waveform screenshot
#   build/<TOP>.json             VHDL synthesised netlist
#   build/<TOP>.svg              VHDL netlist diagram
#   build/<V_TB_TOP>_v.vcd       Verilog simulation waveform dump
#   build/<V_TB_TOP>_v.png       Verilog waveform screenshot
#   build/<V_TOP>_v.json         Verilog synthesised netlist
#   build/<V_TOP>_v.svg          Verilog netlist diagram
# ---------------------------------------------------------------------------

# ---- Tool discovery (overridable from the environment) --------------------
GHDL          ?= ghdl
YOSYS         ?= yosys
NETLISTSVG    ?= netlistsvg
PYTHON        ?= python3
IVERILOG      ?= iverilog
VVP           ?= vvp

# ---- Defaults --------------------------------------------------------------
VHDL_STANDARD ?= 08
SIM_STD       ?= $(VHDL_STANDARD)
SYNTH_STD     ?= $(VHDL_STANDARD)
ASSERT_LEVEL  ?= error
SIM_TIME      ?=
EXTRA_GHDL    ?=
SKIP_DIAGRAM  ?=
SKIP_SCREENSHOT ?=

V_SRC_FILES   ?=
V_TB_FILES    ?=
V_TOP         ?=
V_TB_TOP      ?=
V_DEFINES     ?=
V_INCDIRS     ?=
SKIP_V_DIAGRAM ?=
SKIP_V_SCREENSHOT ?=

# ---- Layout ----------------------------------------------------------------
BUILD_DIR     := build
WORK_DIR      := $(BUILD_DIR)/work
VCD_FILE      := $(BUILD_DIR)/$(TB_TOP).vcd
WAVEFORM_PNG  := $(BUILD_DIR)/$(TB_TOP).png
NETLIST_JSON  := $(BUILD_DIR)/$(TOP).json
DIAGRAM_SVG   := $(BUILD_DIR)/$(TOP).svg

V_VVP_FILE    := $(BUILD_DIR)/$(V_TB_TOP)_v.vvp
V_VCD_FILE    := $(BUILD_DIR)/$(V_TB_TOP)_v.vcd
V_WAVEFORM_PNG:= $(BUILD_DIR)/$(V_TB_TOP)_v.png
V_NETLIST_JSON:= $(BUILD_DIR)/$(V_TOP)_v.json
V_DIAGRAM_SVG := $(BUILD_DIR)/$(V_TOP)_v.svg

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

# ---- Verilog flags ---------------------------------------------------------
# VCD_OUT is supplied as a `define so testbenches don't hardcode the
# build path: `$dumpfile(`VCD_OUT)` lands in build/<tb>_v.vcd.
IVERILOG_FLAGS  := -g2012 \
                   -DVCD_OUT='"$(notdir $(V_VCD_FILE))"' \
                   $(addprefix -D,$(V_DEFINES)) \
                   $(addprefix -I,$(V_INCDIRS))
YOSYS_V_DEFINES := $(addprefix -D,$(V_DEFINES))
YOSYS_V_INCDIRS := $(addprefix -I,$(V_INCDIRS))

# ---- Phony targets ---------------------------------------------------------
.PHONY: all analyze elaborate simulate diagram screenshot clean help \
        analyze_v simulate_v diagram_v screenshot_v

# `all` runs the VHDL flow plus the Verilog flow when V_SRC_FILES is set.
ALL_TARGETS := simulate diagram screenshot
ifneq ($(strip $(V_SRC_FILES)),)
ALL_TARGETS += simulate_v diagram_v screenshot_v
endif

all: $(ALL_TARGETS)

help:
	@echo "Project: $(PROJECT_NAME)"
	@echo "  TOP=$(TOP)  TB_TOP=$(TB_TOP)  VHDL_STANDARD=$(VHDL_STANDARD)"
ifneq ($(strip $(V_SRC_FILES)),)
	@echo "  V_TOP=$(V_TOP)  V_TB_TOP=$(V_TB_TOP)  (Verilog flow enabled)"
endif
	@echo ""
	@echo "VHDL targets:"
	@echo "  analyze     Parse and type-check the VHDL sources."
	@echo "  elaborate   Elaborate the testbench ($(TB_TOP))."
	@echo "  simulate    Run simulation and emit $(VCD_FILE)."
	@echo "  diagram     Synthesise $(TOP) via yosys+ghdl, render SVG."
	@echo "  screenshot  Render a GTKWave PNG of the simulation waveform."
ifneq ($(strip $(V_SRC_FILES)),)
	@echo ""
	@echo "Verilog targets:"
	@echo "  simulate_v   Run iverilog/vvp simulation, emit $(V_VCD_FILE)."
	@echo "  diagram_v    Synthesise $(V_TOP) via yosys, render SVG."
	@echo "  screenshot_v Render a GTKWave PNG of the Verilog waveform."
endif
	@echo ""
	@echo "  clean       Remove the build/ directory."

$(BUILD_DIR) $(WORK_DIR):
	@mkdir -p $@

# ---- Analyze (VHDL) --------------------------------------------------------
analyze: | $(WORK_DIR)
	$(GHDL) -a $(GHDL_SIM_FLAGS) $(SRC_FILES) $(TB_FILES)

# ---- Elaborate (VHDL) ------------------------------------------------------
# GHDL drops the linked testbench binary (and, with llvm/gcc backends, a
# stray `e~<tb>.o` alongside) into the project root. We don't try to
# redirect it with `-o`: that breaks `ghdl -r`, which hunts for the
# binary under its default lowercased name. The `clean` rule sweeps
# those droppings, and .gitignore keeps them out of the tree.
elaborate: analyze
	$(GHDL) -e $(GHDL_SIM_FLAGS) $(TB_TOP)

# ---- Simulate (VHDL) -------------------------------------------------------
simulate: $(VCD_FILE)

$(VCD_FILE): elaborate | $(BUILD_DIR)
	$(GHDL) -r $(GHDL_SIM_FLAGS) $(TB_TOP) $(SIM_RUN_OPTS)

# ---- Waveform screenshot (VHDL) -------------------------------------------
ifneq ($(strip $(SKIP_SCREENSHOT)),)
screenshot:
	@echo "[$(PROJECT_NAME)] screenshot: skipped (SKIP_SCREENSHOT set)"
else
screenshot: $(WAVEFORM_PNG)

$(WAVEFORM_PNG): $(VCD_FILE)
	$(PYTHON) $(VCD2PNG) --input $< --output $@
endif

# ---- Netlist diagram (VHDL) -----------------------------------------------
ifneq ($(strip $(SKIP_DIAGRAM)),)
diagram:
	@echo "[$(PROJECT_NAME)] diagram: skipped (SKIP_DIAGRAM set)"
else
diagram: $(DIAGRAM_SVG)

$(NETLIST_JSON): $(SRC_FILES) | $(BUILD_DIR)
	$(YOSYS) -m ghdl -p \
	    "ghdl $(GHDL_SYNTH_STD) -fsynopsys $(SRC_FILES) -e $(TOP); \
	     prep -top $(TOP); \
	     write_json -compat-int $@"

$(DIAGRAM_SVG): $(NETLIST_JSON)
	$(NETLISTSVG) $< -o $@
endif

# ---- Verilog flow ---------------------------------------------------------
# Only wired up when V_SRC_FILES is set. Each target is a no-op otherwise
# so projects without Verilog sources see no change in behaviour.
ifneq ($(strip $(V_SRC_FILES)),)

# ---- Simulate (Verilog) ---------------------------------------------------
simulate_v: $(V_VCD_FILE)

$(V_VVP_FILE): $(V_SRC_FILES) $(V_TB_FILES) | $(BUILD_DIR)
	$(IVERILOG) $(IVERILOG_FLAGS) -s $(V_TB_TOP) -o $@ \
	    $(V_SRC_FILES) $(V_TB_FILES)

# Run vvp from build/ so the VCD path supplied via the VCD_OUT define
# (see IVERILOG_FLAGS above) lands inside build/. Testbenches do
# `$dumpfile(`VCD_OUT)`, which expands to "<tb>_v.vcd".
$(V_VCD_FILE): $(V_VVP_FILE)
	cd $(BUILD_DIR) && $(VVP) -n $(notdir $<)
	@if [ ! -f $@ ]; then \
	    echo "ERROR: $(V_TB_TOP) did not produce $@" >&2; \
	    echo "       (testbench should call \$$dumpfile(\`VCD_OUT))" >&2; \
	    exit 1; \
	fi

# ---- Waveform screenshot (Verilog) ----------------------------------------
ifneq ($(strip $(SKIP_V_SCREENSHOT)),)
screenshot_v:
	@echo "[$(PROJECT_NAME)] screenshot_v: skipped (SKIP_V_SCREENSHOT set)"
else
screenshot_v: $(V_WAVEFORM_PNG)

$(V_WAVEFORM_PNG): $(V_VCD_FILE)
	$(PYTHON) $(VCD2PNG) --input $< --output $@
endif

# ---- Netlist diagram (Verilog) --------------------------------------------
ifneq ($(strip $(SKIP_V_DIAGRAM)),)
diagram_v:
	@echo "[$(PROJECT_NAME)] diagram_v: skipped (SKIP_V_DIAGRAM set)"
else
diagram_v: $(V_DIAGRAM_SVG)

$(V_NETLIST_JSON): $(V_SRC_FILES) | $(BUILD_DIR)
	$(YOSYS) -p \
	    "read_verilog -sv $(YOSYS_V_DEFINES) $(YOSYS_V_INCDIRS) $(V_SRC_FILES); \
	     prep -top $(V_TOP); \
	     write_json -compat-int $@"

$(V_DIAGRAM_SVG): $(V_NETLIST_JSON)
	$(NETLISTSVG) $< -o $@
endif

else
# Verilog flow disabled: provide visible no-op targets so users who type
# them get an explanation instead of "no rule to make target".
simulate_v diagram_v screenshot_v:
	@echo "[$(PROJECT_NAME)] $@: no Verilog sources (set V_SRC_FILES to enable)"
endif

# ---- Housekeeping ----------------------------------------------------------
# GHDL's llvm/gcc backends leave droppings next to the sources: work-obj*.cf
# (library index), e~<tb>.o (elab object) and the linked <tb> binary
# itself. `--workdir` doesn't reroute the binary, only the intermediates.
# We use `-f` guards around the named files so the rule is safe even
# when $(TOP)/$(TB_TOP) collide with directory names (e.g. `test/`).
clean:
	@rm -rf $(BUILD_DIR)
	@find . -maxdepth 1 -type f \( \
	    -name '*.cf' -o \
	    -name '*.o'  -o \
	    -name 'e~*'  -o \
	    -name 'work-obj*.cf' \
	  \) -delete
	@find . -maxdepth 1 -type f \( \
	    -iname '$(TB_TOP)' -o \
	    -iname '$(TOP)' \
	  \) -delete 2>/dev/null || true
