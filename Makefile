# ---------------------------------------------------------------------------
# Top-level Makefile.
#
# Auto-discovers every subdirectory (at any depth) that contains a
# Makefile including mk/common.mk, and forwards the standard targets to
# each of them. Running `make` at the repo root therefore exercises every
# project the same way CI does.
#
# A project is anywhere `make -C <dir>` would work. To register a new one,
# drop a Makefile that `include`s ../(../..)?/mk/common.mk — that's it.
# ---------------------------------------------------------------------------

.DEFAULT_GOAL := all

# Find every Makefile under the tree that uses our shared rules. Marker:
# a literal `mk/common.mk` include. grep -l prints filenames only.
PROJECT_MAKEFILES := $(shell grep -rl --include=Makefile 'mk/common\.mk' . 2>/dev/null | \
                            grep -v '^\./Makefile$$' | sort)
PROJECTS := $(patsubst %/Makefile,%,$(PROJECT_MAKEFILES))

# Targets we forward to each project. Keep in sync with mk/common.mk.
FORWARDED_TARGETS := all analyze elaborate simulate diagram waveform clean \
                     simulate_v diagram_v waveform_v verify

.PHONY: help list test test-tools clean-tools $(FORWARDED_TARGETS)

help:
	@echo "learning_fpga - top-level orchestration"
	@echo ""
	@echo "Discovered projects:"
	@for p in $(PROJECTS); do echo "  - $$p"; done
	@echo ""
	@echo "Targets (run against every project):"
	@echo "  all         simulate + diagram + waveform"
	@echo "  test        assertions in both HDLs + language comparisons + Python tests"
	@echo "  analyze     ghdl -a"
	@echo "  elaborate   ghdl -e"
	@echo "  simulate    ghdl -r (emits an FST)"
	@echo "  diagram     yosys + netlistsvg (emits an SVG)"
	@echo "  waveform    waveview render (emits an SVG + PNG)"
	@echo "  *_v         the corresponding Verilog stage"
	@echo "  clean       remove every build/ directory"
	@echo ""
	@echo "Targeting a single project: make -C <project-dir> [target]"

list:
	@for p in $(PROJECTS); do echo $$p; done

all test: test-tools

test-tools:
	$(MAKE) -C tools/rv32_asm test

test:
	@set -e; for dir in $(PROJECTS); do \
	    echo "==> $$dir: make test"; \
	    $(MAKE) -C $$dir test; \
	done

clean: clean-tools

clean-tools:
	$(MAKE) -C tools/rv32_asm clean

$(FORWARDED_TARGETS):
	@set -e; for dir in $(PROJECTS); do \
	    echo "==> $$dir: make $@"; \
	    $(MAKE) -C $$dir $@; \
	done
