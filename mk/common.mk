# ---------------------------------------------------------------------------
# mk/common.mk - Shared build rules for every project in learning_fpga.
#
# Each project's Makefile is expected to define:
#
#   PROJECT_NAME   Identifier used for artifact names and logs.
#   TOP            Top-level entity (used for diagram synthesis).
#   TB_TOPS        Space-separated list of testbench top-levels. Each
#                  produces its own `build/<tb>.fst` and
#                  `build/<tb>.png`. Projects with a single testbench
#                  write `TB_TOPS := tb_foo` (one entry).
#   SRC_FILES      VHDL sources of the design, relative to the Makefile.
#   TB_FILES       VHDL sources of every testbench, relative to the Makefile.
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
#   SKIP_WAVEFORM  If non-empty, `make waveform` is a no-op.
#
# Optional Verilog side-by-side build (set any of these to enable):
#
#   V_TOP          Verilog top-level module name (for diagram synthesis).
#   V_TB_TOPS      Space-separated list of Verilog testbench top modules.
#                  One FST + PNG is produced per entry, suffixed with `_v`.
#   V_SRC_FILES    Verilog sources of the design.
#   V_TB_FILES     Verilog sources of every testbench.
#   V_DEFINES      Extra `-D` macros for iverilog/yosys (e.g. WIDTH=8).
#   V_INCDIRS      Extra `-I` include directories.
#   SKIP_V_DIAGRAM If non-empty, the Verilog `diagram` step is a no-op.
#   SKIP_V_WAVEFORM If non-empty, the Verilog `waveform` step is a no-op.
#
# When V_SRC_FILES is non-empty, `make all` (and `simulate` / `diagram` /
# `waveform`) build BOTH the VHDL and Verilog flows. Artifacts are
# disambiguated with a `_v` suffix so they share build/ without colliding.
#
# Artifact locations (all under build/ for trivial `make clean`):
#
#   build/work/                  GHDL work library
#   build/<tb>.fst               VHDL simulation waveform dump (one per TB_TOPS entry)
#   build/<tb>.svg               VHDL waveform diagram, vector (one per TB_TOPS entry)
#   build/<tb>.png               VHDL waveform diagram, raster (one per TB_TOPS entry)
#   build/<TOP>.json             VHDL synthesised netlist
#   build/<TOP>.svg              VHDL netlist diagram
#   build/<tb>_v.fst             Verilog simulation waveform (one per V_TB_TOPS entry)
#   build/<tb>_v.svg             Verilog waveform diagram, vector (one per V_TB_TOPS entry)
#   build/<tb>_v.png             Verilog waveform diagram, raster (one per V_TB_TOPS entry)
#   build/<V_TOP>_v.json         Verilog synthesised netlist
#   build/<V_TOP>_v.svg          Verilog netlist diagram
#
# Both the GHDL and iverilog flows dump FST natively — GHDL via `--fst=`,
# iverilog via `IVERILOG_DUMPER=fst` at vvp runtime. FST is ~10-100x
# smaller than VCD on long-window TBs and is what waveview reads anyway.
# ---------------------------------------------------------------------------

# ---- Tool discovery (overridable from the environment) --------------------
GHDL          ?= ghdl
# yosys is invoked with `-q` everywhere in the diagram rules below.
# `-q` suppresses yosys's normal info logging — most importantly the
# per-signal "No latch inferred for signal X" notes that PROC_DLATCH
# emits for every combinational signal it checks (one large design
# can produce thousands of these, drowning out actual issues).
# `Warning:` and `Error:` lines are NOT affected; verified on
# random_generator (whose neoTRNG ring oscillators still surface
# their intentional "found logic loop" warnings under -q).
YOSYS         ?= yosys
# Split NETLISTSVG into _BIN + _SKIN + composed default so projects
# that need to override just one piece can do so without losing the
# other. Common cases:
#   * Big designs that need a bigger Node V8 stack just override
#     NETLISTSVG_BIN (see cpu/riscv_singlecycle/Makefile).
#   * Projects that need a custom glyph set can pass --skin via NETLISTSVG.
# No --skin is passed by default — netlistsvg's bundled default skin
# already covers every primitive yosys emits for our designs
# (including $ne and the -bus variants used by hierarchical rendering).
NETLISTSVG_BIN  ?= netlistsvg
NETLISTSVG_CONFIG ?= $(COMMON_MK_DIR)netlistsvg-hierarchy.json
NETLISTSVG      ?= $(NETLISTSVG_BIN) --config $(NETLISTSVG_CONFIG)
WAVEVIEW      ?= waveview
IVERILOG      ?= iverilog
VVP           ?= vvp

# ---- Defaults --------------------------------------------------------------
VHDL_STANDARD ?= 08
SIM_STD       ?= $(VHDL_STANDARD)
SYNTH_STD     ?= $(VHDL_STANDARD)
ASSERT_LEVEL  ?= error
SIM_TIME      ?=
EXTRA_GHDL    ?=
# Extra flags appended to the ghdl invocation that runs *inside* yosys
# during the diagram synth step (NOT the simulation `ghdl -a/-e/-r`
# flow, which uses EXTRA_GHDL). The default is empty: ghdl-yosys-plugin
# treats inferred latches as a hard error, which is what we want
# repo-wide. Projects that *intentionally* infer latches (e.g. the
# logic_styles latch-trap tutorial) set this to `--latches`.
GHDL_SYNTH_EXTRA ?=
SKIP_DIAGRAM  ?=
SKIP_WAVEFORM ?=
# Per-TB opt-out of the `waveform` step. Use when a testbench's
# contribution is its assertions, not its waveform — e.g. a
# long-window TB whose waveform would be sub-pixel-per-clock-edge
# anyway. The TB still simulates and its assertions still guard CI,
# it just doesn't produce a rendered diagram.
NO_WAVEFORM_TBS ?=

V_SRC_FILES   ?=
V_TB_FILES    ?=
V_TOP         ?=
V_TB_TOPS     ?=
V_DEFINES     ?=
V_INCDIRS     ?=
SKIP_V_DIAGRAM ?=
SKIP_V_WAVEFORM ?=
V_NO_WAVEFORM_TBS ?=

# Per-project hooks decorating the rendered netlist diagram.
# Both run after netlistsvg writes its SVG, via mk/svg_add_links.py.
#
# SVG_LINKS turns the named cell into a hyperlink. Format:
#   cell_id=url
# (multiple entries separated by spaces). The script wraps the cell's
# `<g id="cell_<cell_id>" ...>` element with `<a xlink:href="url">`,
# so an SVG viewer can drill from a wrapper's diagram into the
# wrapped module's own diagram. URLs are relative to the SVG itself;
# for the published gallery that means `../<sibling-artifact>/<top>.svg`.
#
# SVG_RELABEL rewrites the displayed text on the named cell. Same
# format (cell_id=label). Useful when a wrapped sub-instance arrives
# with yosys's `$paramod\<sub>\<param>=<val>` (Verilog) or
# `<sub>_B<arch>_<width>` (VHDL via ghdl-yosys-plugin) auto-name
# stamped on the box: post-rewrite the label back to the bare
# submodule name. yosys's own `rename` won't propagate to cell-type
# references, so post-processing the SVG is the practical fix.
SVG_LINKS     ?=
V_SVG_LINKS   ?=
SVG_RELABEL   ?=
V_SVG_RELABEL ?=

# Used to locate svg_add_links.py — common.mk lives next to it.
COMMON_MK_DIR := $(dir $(abspath $(lastword $(MAKEFILE_LIST))))

# ---- Layout ----------------------------------------------------------------
BUILD_DIR     := build
WORK_DIR      := $(BUILD_DIR)/work
# Waveform path for a given testbench. Both flows dump FST.
tb_wave   = $(BUILD_DIR)/$(1).fst
v_tb_wave = $(BUILD_DIR)/$(1)_v.fst

# Per-TB artifact lists. The netlist is still singular (it's the design
# top-level, not a testbench), but simulation/waveform fan out over
# $(TB_TOPS) / $(V_TB_TOPS). TBs in NO_WAVEFORM_TBS contribute to simulate
# (their assertions run) but are excluded from the waveform output.
WAVE_FILES    := $(foreach tb,$(TB_TOPS),$(call tb_wave,$(tb)))
WAVEFORM_PNGS := $(foreach tb,$(filter-out $(NO_WAVEFORM_TBS),$(TB_TOPS)),$(BUILD_DIR)/$(tb).png)
NETLIST_JSON  := $(BUILD_DIR)/$(TOP).json
DIAGRAM_SVG   := $(BUILD_DIR)/$(TOP).svg

V_WAVE_FILES    := $(foreach tb,$(V_TB_TOPS),$(call v_tb_wave,$(tb)))
V_WAVEFORM_PNGS := $(foreach tb,$(filter-out $(V_NO_WAVEFORM_TBS),$(V_TB_TOPS)),$(BUILD_DIR)/$(tb)_v.png)
V_NETLIST_JSON  := $(BUILD_DIR)/$(V_TOP)_v.json
V_DIAGRAM_SVG   := $(BUILD_DIR)/$(V_TOP)_v.svg

# ---- GHDL flags ------------------------------------------------------------
GHDL_COMMON     := --workdir=$(WORK_DIR) -fsynopsys $(EXTRA_GHDL)
GHDL_SIM_FLAGS  := --std=$(SIM_STD)   $(GHDL_COMMON)
GHDL_SYNTH_STD  := --std=$(SYNTH_STD)

# Optional --stop-time only emitted when SIM_TIME is set.
SIM_STOPTIME :=
ifneq ($(strip $(SIM_TIME)),)
    SIM_STOPTIME := --stop-time=$(SIM_TIME)
endif

# ---- Phony targets ---------------------------------------------------------
.PHONY: all analyze elaborate simulate diagram waveform clean help \
        analyze_v simulate_v diagram_v waveform_v

# `all` runs the VHDL flow plus the Verilog flow when V_SRC_FILES is set.
ALL_TARGETS := simulate diagram waveform
ifneq ($(strip $(V_SRC_FILES)),)
ALL_TARGETS += simulate_v diagram_v waveform_v
endif

all: $(ALL_TARGETS)

help:
	@echo "Project: $(PROJECT_NAME)"
	@echo "  TOP=$(TOP)  TB_TOPS=$(TB_TOPS)  VHDL_STANDARD=$(VHDL_STANDARD)"
ifneq ($(strip $(V_SRC_FILES)),)
	@echo "  V_TOP=$(V_TOP)  V_TB_TOPS=$(V_TB_TOPS)  (Verilog flow enabled)"
endif
	@echo ""
	@echo "VHDL targets:"
	@echo "  analyze     Parse and type-check the VHDL sources."
	@echo "  elaborate   Elaborate every testbench in TB_TOPS."
	@echo "  simulate    Run every testbench, emit one FST per TB."
	@echo "  diagram     Synthesise $(TOP) via yosys+ghdl, render SVG."
	@echo "  waveform    Render one waveview SVG+PNG per simulation dump."
ifneq ($(strip $(V_SRC_FILES)),)
	@echo ""
	@echo "Verilog targets:"
	@echo "  simulate_v   Run iverilog/vvp for each TB in V_TB_TOPS."
	@echo "  diagram_v    Synthesise $(V_TOP) via yosys, render SVG."
	@echo "  waveform_v   Render one waveview SVG+PNG per Verilog TB."
endif
	@echo ""
	@echo "  clean       Remove the build/ directory."

$(BUILD_DIR) $(WORK_DIR):
	@mkdir -p $@

# ---- Analyze (VHDL) --------------------------------------------------------
# Analyses every source and every testbench together in one invocation -
# this also serves as a compile-time check for TBs that aren't being
# simulated yet.
analyze: | $(WORK_DIR)
	$(GHDL) -a $(GHDL_SIM_FLAGS) $(SRC_FILES) $(TB_FILES)

# ---- Elaborate (VHDL) ------------------------------------------------------
# GHDL drops the linked testbench binary (and, with llvm/gcc backends, a
# stray `e~<tb>.o` alongside) into the project root. We don't try to
# redirect it with `-o`: that breaks `ghdl -r`, which hunts for the
# binary under its default lowercased name. The `clean` rule sweeps
# those droppings, and .gitignore keeps them out of the tree.
#
# With multiple TBs we elaborate each; the binaries don't collide
# because they are named after the TB entity.
define GHDL_ELAB_RULE
.PHONY: elaborate-$(1)
elaborate-$(1): analyze
	$$(GHDL) -e $$(GHDL_SIM_FLAGS) $(1)
endef
$(foreach tb,$(TB_TOPS),$(eval $(call GHDL_ELAB_RULE,$(tb))))

elaborate: $(foreach tb,$(TB_TOPS),elaborate-$(tb))

# ---- Simulate (VHDL) -------------------------------------------------------
# One FST waveform file per TB.
define GHDL_SIM_RULE
$$(call tb_wave,$(1)): elaborate-$(1) | $$(BUILD_DIR)
	$$(GHDL) -r $$(GHDL_SIM_FLAGS) $(1) --assert-level=$$(ASSERT_LEVEL) \
	    --ieee-asserts=disable-at-0 \
	    --fst=$$@ $$(SIM_STOPTIME)
endef
# `--ieee-asserts=disable-at-0` suppresses the harmless metavalue
# warnings IEEE numeric_std emits at t=0 (before signals propagate
# through the first delta cycle). Real X-propagation bugs that
# surface AFTER t=0 still print, so the noise floor drops without
# masking actual failures.
$(foreach tb,$(TB_TOPS),$(eval $(call GHDL_SIM_RULE,$(tb))))

simulate: $(WAVE_FILES)

# ---- Waveform render (VHDL) -----------------------------------------------
# waveview reads FST natively. waveview always emits an SVG; --png adds
# the PNG alongside at the same stem. We route the SVG to
# build/<tb>.svg (a free vector-quality artifact picked up by the CI
# gallery) and rely on --png to land build/<tb>.png.
ifneq ($(strip $(SKIP_WAVEFORM)),)
waveform:
	@echo "[$(PROJECT_NAME)] waveform: skipped (SKIP_WAVEFORM set)"
else
# Optional per-TB zoom override: a project Makefile may set
#   ZOOM_RANGE_<tb_name> := FROM TO
# (integers in the dump's native time units, or SI literals like
# 200ns / 5us) to force an explicit zoom when the default full-range
# render is unreadable — e.g. for an FST dump whose interesting
# window is a sliver of the full timeline.
define GHDL_PNG_RULE
$$(BUILD_DIR)/$(1).png: $$(call tb_wave,$(1))
	$$(WAVEVIEW) --input $$< --output $$(@:.png=.svg) --png \
	    $$(if $$(ZOOM_RANGE_$(1)),--zoom-range $$(ZOOM_RANGE_$(1)))
endef
$(foreach tb,$(TB_TOPS),$(eval $(call GHDL_PNG_RULE,$(tb))))

waveform: $(WAVEFORM_PNGS)
endif

# ---- Netlist diagram (VHDL) -----------------------------------------------
ifneq ($(strip $(SKIP_DIAGRAM)),)
diagram:
	@echo "[$(PROJECT_NAME)] diagram: skipped (SKIP_DIAGRAM set)"
else
diagram: $(DIAGRAM_SVG)

$(NETLIST_JSON): $(SRC_FILES) | $(BUILD_DIR)
	$(YOSYS) -q -m ghdl -p \
	    "ghdl $(GHDL_SYNTH_STD) -fsynopsys $(GHDL_SYNTH_EXTRA) $(SRC_FILES) -e $(TOP); \
	     prep -top $(TOP); \
	     write_json -compat-int $@"

$(DIAGRAM_SVG): $(NETLIST_JSON)
	$(NETLISTSVG) $< -o $@
	python3 $(COMMON_MK_DIR)svg_add_links.py $@ --beautify-primitives \
	    $(addprefix --link ,$(SVG_LINKS)) \
	    $(addprefix --relabel ,$(SVG_RELABEL))
endif

# ---- Verilog flow ---------------------------------------------------------
# Only wired up when V_SRC_FILES is set. Each target is a no-op otherwise
# so projects without Verilog sources see no change in behaviour.
ifneq ($(strip $(V_SRC_FILES)),)

# ---- Simulate (Verilog) ---------------------------------------------------
# One VVP binary, one FST per testbench. The iverilog invocation per TB
# supplies its own -DFST_OUT so each `$dumpfile(`FST_OUT)` lands in its
# own build/<tb>_v.fst file. iverilog 13 switches its dump format from
# VCD to FST when IVERILOG_DUMPER=fst is set in vvp's environment.
define IVERILOG_RULE
$$(BUILD_DIR)/$(1)_v.vvp: $$(V_SRC_FILES) $$(V_TB_FILES) | $$(BUILD_DIR)
	$$(IVERILOG) -g2012 \
	    -DFST_OUT='"$(1)_v.fst"' \
	    $$(addprefix -D,$$(V_DEFINES)) \
	    $$(addprefix -I,$$(V_INCDIRS)) \
	    -s $(1) -o $$@ \
	    $$(V_SRC_FILES) $$(V_TB_FILES)

# Run vvp from build/ so the FST path supplied via the FST_OUT define
# lands inside build/. Testbenches do `$dumpfile(`FST_OUT)`, which
# expands to "<tb>_v.fst".
$$(BUILD_DIR)/$(1)_v.fst: $$(BUILD_DIR)/$(1)_v.vvp
	cd $$(BUILD_DIR) && IVERILOG_DUMPER=fst $$(VVP) -n $$(notdir $$<)
	@if [ ! -f $$@ ]; then \
	    echo "ERROR: $(1) did not produce $$@" >&2; \
	    echo "       (testbench should call \$$$$dumpfile(\`FST_OUT))" >&2; \
	    exit 1; \
	fi
endef
$(foreach tb,$(V_TB_TOPS),$(eval $(call IVERILOG_RULE,$(tb))))

simulate_v: $(V_WAVE_FILES)

# ---- Waveform render (Verilog) --------------------------------------------
ifneq ($(strip $(SKIP_V_WAVEFORM)),)
waveform_v:
	@echo "[$(PROJECT_NAME)] waveform_v: skipped (SKIP_V_WAVEFORM set)"
else
# Optional per-TB zoom override, Verilog side: V_ZOOM_RANGE_<tb>.
define VERILOG_PNG_RULE
$$(BUILD_DIR)/$(1)_v.png: $$(call v_tb_wave,$(1))
	$$(WAVEVIEW) --input $$< --output $$(@:.png=.svg) --png \
	    $$(if $$(V_ZOOM_RANGE_$(1)),--zoom-range $$(V_ZOOM_RANGE_$(1)))
endef
$(foreach tb,$(V_TB_TOPS),$(eval $(call VERILOG_PNG_RULE,$(tb))))

waveform_v: $(V_WAVEFORM_PNGS)
endif

# ---- Netlist diagram (Verilog) --------------------------------------------
ifneq ($(strip $(SKIP_V_DIAGRAM)),)
diagram_v:
	@echo "[$(PROJECT_NAME)] diagram_v: skipped (SKIP_V_DIAGRAM set)"
else
diagram_v: $(V_DIAGRAM_SVG)

$(V_NETLIST_JSON): $(V_SRC_FILES) | $(BUILD_DIR)
	$(YOSYS) -q -p \
	    "read_verilog -sv $(addprefix -D,$(V_DEFINES)) $(addprefix -I,$(V_INCDIRS)) $(V_SRC_FILES); \
	     prep -top $(V_TOP); \
	     write_json -compat-int $@"

$(V_DIAGRAM_SVG): $(V_NETLIST_JSON)
	$(NETLISTSVG) $< -o $@
	python3 $(COMMON_MK_DIR)svg_add_links.py $@ --beautify-primitives \
	    $(addprefix --link ,$(V_SVG_LINKS)) \
	    $(addprefix --relabel ,$(V_SVG_RELABEL))
endif

else
# Verilog flow disabled: provide visible no-op targets so users who type
# them get an explanation instead of "no rule to make target".
simulate_v diagram_v waveform_v:
	@echo "[$(PROJECT_NAME)] $@: no Verilog sources (set V_SRC_FILES to enable)"
endif

# ---- Housekeeping ----------------------------------------------------------
# GHDL's llvm/gcc backends leave droppings next to the sources: work-obj*.cf
# (library index), e~<tb>.o (elab object) and the linked <tb> binary
# itself. `--workdir` doesn't reroute the binary, only the intermediates.
# We use `-f` guards around the named files so the rule is safe even
# when $(TOP)/$(TB_TOPS) collide with directory names (e.g. `test/`).
clean:
	@rm -rf $(BUILD_DIR)
	@find . -maxdepth 1 -type f \( \
	    -name '*.cf' -o \
	    -name '*.o'  -o \
	    -name 'e~*'  -o \
	    -name 'work-obj*.cf' \
	  \) -delete
	@find . -maxdepth 1 -type f \( \
	    $(foreach tb,$(TB_TOPS),-iname '$(tb)' -o) \
	    -iname '$(TOP)' \
	  \) -delete 2>/dev/null || true
